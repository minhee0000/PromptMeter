import Foundation

struct LocalTokenUsageFile: Sendable {
    let url: URL
    let modifiedAtMilliseconds: Int64
    let byteCount: Int64

    var signature: LocalTokenUsageFileSignature {
        LocalTokenUsageFileSignature(
            modifiedAtMilliseconds: modifiedAtMilliseconds,
            byteCount: byteCount
        )
    }
}

struct LocalTokenUsageCacheIdentity: Hashable, Sendable {
    let providerID: String
    let path: String
    let dayStartMilliseconds: Int64
}

struct LocalTokenUsageFileSignature: Equatable, Sendable {
    let modifiedAtMilliseconds: Int64
    let byteCount: Int64
}

struct LocalTokenUsageCodexParserState: Sendable {
    var previousTotals: LocalTokenUsageSnapshot?
    var currentModelName: String?
    var currentReasoningEffort: String?

    static let empty = LocalTokenUsageCodexParserState(
        previousTotals: nil,
        currentModelName: nil,
        currentReasoningEffort: nil
    )
}

struct LocalTokenUsageClaudeParserState: Sendable {
    var keyedRows: [String: LocalTokenUsageSnapshot]
    var unkeyedTotal: LocalTokenUsageSnapshot

    static let empty = LocalTokenUsageClaudeParserState(
        keyedRows: [:],
        unkeyedTotal: .empty(provider: .claude)
    )

    var total: LocalTokenUsageSnapshot {
        keyedRows.values.reduce(unkeyedTotal, +)
    }
}

enum LocalTokenUsageParserState: Sendable {
    case codex(LocalTokenUsageCodexParserState)
    case claude(LocalTokenUsageClaudeParserState)
}

struct LocalTokenUsageFileCacheEntry: Sendable {
    let signature: LocalTokenUsageFileSignature
    let processedByteCount: Int64
    let snapshot: LocalTokenUsageSnapshot
    let parserState: LocalTokenUsageParserState?
    let scannedAt: Date
}

final class LocalTokenUsageFileCache: @unchecked Sendable {
    private static let cacheVersion = 1

    private let lock = NSLock()
    private let cacheFileURL: URL
    private var activeDayStartMilliseconds: Int64?
    private var entries: [LocalTokenUsageCacheIdentity: LocalTokenUsageFileCacheEntry] = [:]

    init(cacheFileURL: URL = LocalTokenUsageFileCache.defaultCacheFileURL()) {
        self.cacheFileURL = cacheFileURL
        loadFromDisk()
    }

    func snapshot(identity: LocalTokenUsageCacheIdentity, signature: LocalTokenUsageFileSignature) -> LocalTokenUsageSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        pruneIfNeeded(dayStartMilliseconds: identity.dayStartMilliseconds)

        guard let entry = entries[identity] else {
            return nil
        }

        if entry.signature == signature {
            return entry.snapshot
        }

        return nil
    }

    func incrementalEntry(
        identity: LocalTokenUsageCacheIdentity,
        signature: LocalTokenUsageFileSignature
    ) -> LocalTokenUsageFileCacheEntry? {
        lock.lock()
        defer { lock.unlock() }

        pruneIfNeeded(dayStartMilliseconds: identity.dayStartMilliseconds)

        guard let entry = entries[identity],
              signature.byteCount > entry.processedByteCount,
              signature.byteCount >= entry.signature.byteCount else {
            return nil
        }

        return entry
    }

    func store(
        _ snapshot: LocalTokenUsageSnapshot,
        identity: LocalTokenUsageCacheIdentity,
        signature: LocalTokenUsageFileSignature,
        processedByteCount: Int64,
        parserState: LocalTokenUsageParserState?,
        scannedAt: Date
    ) {
        lock.lock()
        defer { lock.unlock() }

        pruneIfNeeded(dayStartMilliseconds: identity.dayStartMilliseconds)
        entries[identity] = LocalTokenUsageFileCacheEntry(
            signature: signature,
            processedByteCount: processedByteCount,
            snapshot: snapshot,
            parserState: parserState,
            scannedAt: scannedAt
        )
        saveToDiskLocked()
    }

    private func pruneIfNeeded(dayStartMilliseconds: Int64) {
        guard activeDayStartMilliseconds != dayStartMilliseconds else { return }

        entries.removeAll(keepingCapacity: false)
        activeDayStartMilliseconds = dayStartMilliseconds
        saveToDiskLocked()
    }
}

private extension LocalTokenUsageFileCache {
    static func defaultCacheFileURL() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches", isDirectory: true)
        return base
            .appendingPathComponent("PromptMeter", isDirectory: true)
            .appendingPathComponent("local-token-usage-cache.json")
    }

    func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let payload = try? JSONDecoder().decode(DiskCachePayload.self, from: data),
              payload.version == Self.cacheVersion else {
            return
        }

        activeDayStartMilliseconds = payload.dayStartMilliseconds
        entries = payload.entries.reduce(into: [:]) { partial, entry in
            guard let identity = entry.identity,
                  let cacheEntry = entry.cacheEntry else {
                return
            }
            partial[identity] = cacheEntry
        }
    }

    func saveToDiskLocked() {
        let payload = DiskCachePayload(
            version: Self.cacheVersion,
            dayStartMilliseconds: activeDayStartMilliseconds,
            entries: entries.compactMap { identity, entry in
                DiskCacheEntry(identity: identity, cacheEntry: entry)
            }
        )

        do {
            let directoryURL = cacheFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            // Cache writes are best-effort; usage can always be rebuilt from local logs.
        }
    }
}

private struct DiskCachePayload: Codable {
    let version: Int
    let dayStartMilliseconds: Int64?
    let entries: [DiskCacheEntry]
}

private struct DiskCacheEntry: Codable {
    let providerID: String
    let path: String
    let dayStartMilliseconds: Int64
    let modifiedAtMilliseconds: Int64
    let byteCount: Int64
    let processedByteCount: Int64
    let snapshot: DiskSnapshot
    let parserState: DiskParserState?
    let scannedAtMilliseconds: Int64

    var identity: LocalTokenUsageCacheIdentity? {
        LocalTokenUsageCacheIdentity(
            providerID: providerID,
            path: path,
            dayStartMilliseconds: dayStartMilliseconds
        )
    }

    var cacheEntry: LocalTokenUsageFileCacheEntry? {
        guard let snapshot = snapshot.snapshot else { return nil }
        return LocalTokenUsageFileCacheEntry(
            signature: LocalTokenUsageFileSignature(
                modifiedAtMilliseconds: modifiedAtMilliseconds,
                byteCount: byteCount
            ),
            processedByteCount: processedByteCount,
            snapshot: snapshot,
            parserState: parserState?.parserState,
            scannedAt: Date(timeIntervalSince1970: Double(scannedAtMilliseconds) / 1000)
        )
    }

    init?(identity: LocalTokenUsageCacheIdentity, cacheEntry: LocalTokenUsageFileCacheEntry) {
        self.providerID = identity.providerID
        self.path = identity.path
        self.dayStartMilliseconds = identity.dayStartMilliseconds
        self.modifiedAtMilliseconds = cacheEntry.signature.modifiedAtMilliseconds
        self.byteCount = cacheEntry.signature.byteCount
        self.processedByteCount = cacheEntry.processedByteCount
        self.snapshot = DiskSnapshot(cacheEntry.snapshot)
        self.parserState = cacheEntry.parserState.map(DiskParserState.init)
        self.scannedAtMilliseconds = Int64((cacheEntry.scannedAt.timeIntervalSince1970 * 1000).rounded())
    }
}

private struct DiskSnapshot: Codable {
    let providerID: String
    let inputTokens: Int
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    let outputTokens: Int
    let reasoningOutputTokens: Int
    let reasoningEffort: String?
    let reportedTotalTokens: Int?
    let estimatedCostAmount: Double?
    let estimatedCostUnit: String?

    var snapshot: LocalTokenUsageSnapshot? {
        guard let provider = ProviderIconKind(providerID: providerID) else { return nil }
        return LocalTokenUsageSnapshot(
            provider: provider,
            inputTokens: inputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens,
            outputTokens: outputTokens,
            reasoningOutputTokens: reasoningOutputTokens,
            reasoningEffort: reasoningEffort,
            reportedTotalTokens: reportedTotalTokens,
            estimatedCostAmount: estimatedCostAmount,
            estimatedCostUnit: estimatedCostUnit.flatMap(LocalTokenUsageCostUnit.init(rawValue:))
        )
    }

    init(_ snapshot: LocalTokenUsageSnapshot) {
        self.providerID = snapshot.provider.providerID
        self.inputTokens = snapshot.inputTokens
        self.cacheReadTokens = snapshot.cacheReadTokens
        self.cacheCreationTokens = snapshot.cacheCreationTokens
        self.outputTokens = snapshot.outputTokens
        self.reasoningOutputTokens = snapshot.reasoningOutputTokens
        self.reasoningEffort = snapshot.reasoningEffort
        self.reportedTotalTokens = snapshot.reportedTotalTokens
        self.estimatedCostAmount = snapshot.estimatedCostAmount
        self.estimatedCostUnit = snapshot.estimatedCostUnit?.rawValue
    }
}

private struct DiskParserState: Codable {
    let kind: String
    let codex: DiskCodexParserState?
    let claude: DiskClaudeParserState?

    var parserState: LocalTokenUsageParserState? {
        switch kind {
        case "codex":
            guard let codex, let state = codex.state else { return nil }
            return .codex(state)
        case "claude":
            guard let claude, let state = claude.state else { return nil }
            return .claude(state)
        default:
            return nil
        }
    }

    init(_ state: LocalTokenUsageParserState) {
        switch state {
        case .codex(let codex):
            self.kind = "codex"
            self.codex = DiskCodexParserState(codex)
            self.claude = nil
        case .claude(let claude):
            self.kind = "claude"
            self.codex = nil
            self.claude = DiskClaudeParserState(claude)
        }
    }
}

private struct DiskCodexParserState: Codable {
    let previousTotals: DiskSnapshot?
    let currentModelName: String?
    let currentReasoningEffort: String?

    var state: LocalTokenUsageCodexParserState? {
        LocalTokenUsageCodexParserState(
            previousTotals: previousTotals?.snapshot,
            currentModelName: currentModelName,
            currentReasoningEffort: currentReasoningEffort
        )
    }

    init(_ state: LocalTokenUsageCodexParserState) {
        self.previousTotals = state.previousTotals.map(DiskSnapshot.init)
        self.currentModelName = state.currentModelName
        self.currentReasoningEffort = state.currentReasoningEffort
    }
}

private struct DiskClaudeParserState: Codable {
    let keyedRows: [String: DiskSnapshot]
    let unkeyedTotal: DiskSnapshot

    var state: LocalTokenUsageClaudeParserState? {
        var keyedRows: [String: LocalTokenUsageSnapshot] = [:]
        for (key, value) in self.keyedRows {
            guard let snapshot = value.snapshot else { return nil }
            keyedRows[key] = snapshot
        }
        guard let unkeyedTotal = unkeyedTotal.snapshot else { return nil }
        return LocalTokenUsageClaudeParserState(
            keyedRows: keyedRows,
            unkeyedTotal: unkeyedTotal
        )
    }

    init(_ state: LocalTokenUsageClaudeParserState) {
        self.keyedRows = state.keyedRows.mapValues(DiskSnapshot.init)
        self.unkeyedTotal = DiskSnapshot(state.unkeyedTotal)
    }
}

private extension ProviderIconKind {
    init?(providerID: String) {
        switch providerID {
        case ProviderIconKind.codex.providerID:
            self = .codex
        case ProviderIconKind.claude.providerID:
            self = .claude
        case ProviderIconKind.gemini.providerID:
            self = .gemini
        default:
            return nil
        }
    }
}
