import Foundation
import Darwin

enum LocalTokenUsageScanner {
    private static let readChunkSize = 64 * 1024
    private static let maxBufferedLineBytes = 1024 * 1024
    private static let codexTurnContextMarker = Data(#""type":"turn_context""#.utf8)
    private static let codexEventMarker = Data(#""type":"event_msg""#.utf8)
    private static let codexTokenCountMarker = Data(#""token_count""#.utf8)
    private static let claudeAssistantMarker = Data(#""type":"assistant""#.utf8)
    private static let usageMarker = Data(#""usage""#.utf8)
    private static let timestampKey = Data(#""timestamp":""#.utf8)
    private static let messageKey = Data(#""message":"#.utf8)
    private static let requestIDKey = Data(#""requestId":""#.utf8)
    private static let idKey = Data(#""id":""#.utf8)
    private static let modelKey = Data(#""model":""#.utf8)
    private static let modelNameKey = Data(#""model_name":""#.utf8)
    private static let effortKey = Data(#""effort":""#.utf8)
    private static let reasoningEffortKey = Data(#""reasoning_effort":""#.utf8)
    private static let totalTokenUsageKey = Data(#""total_token_usage":"#.utf8)
    private static let lastTokenUsageKey = Data(#""last_token_usage":"#.utf8)
    private static let usageKey = Data(#""usage":"#.utf8)
    private static let inputTokenKeys = [
        Data(#""input_tokens":"#.utf8),
        Data(#""inputTokens":"#.utf8),
        Data(#""prompt_tokens":"#.utf8),
        Data(#""promptTokens":"#.utf8),
        Data(#""input":"#.utf8)
    ]
    private static let cacheReadTokenKeys = [
        Data(#""cached_input_tokens":"#.utf8),
        Data(#""cache_read_input_tokens":"#.utf8),
        Data(#""cacheReadInputTokens":"#.utf8),
        Data(#""cache_read_tokens":"#.utf8),
        Data(#""cacheReadTokens":"#.utf8)
    ]
    private static let cacheCreationTokenKeys = [
        Data(#""cache_creation_input_tokens":"#.utf8),
        Data(#""cacheCreationInputTokens":"#.utf8),
        Data(#""cache_creation_tokens":"#.utf8),
        Data(#""cacheCreationTokens":"#.utf8)
    ]
    private static let outputTokenKeys = [
        Data(#""output_tokens":"#.utf8),
        Data(#""outputTokens":"#.utf8),
        Data(#""completion_tokens":"#.utf8),
        Data(#""completionTokens":"#.utf8),
        Data(#""output":"#.utf8)
    ]
    private static let totalTokenKeys = [
        Data(#""total_tokens":"#.utf8),
        Data(#""totalTokens":"#.utf8),
        Data(#""token_count":"#.utf8),
        Data(#""tokenCount":"#.utf8),
        Data(#""tokens":"#.utf8)
    ]
    private static let reasoningOutputTokenKeys = [
        Data(#""reasoning_output_tokens":"#.utf8),
        Data(#""reasoningOutputTokens":"#.utf8),
        Data(#""reasoning_tokens":"#.utf8),
        Data(#""reasoningTokens":"#.utf8)
    ]
    private static let fileCache = LocalTokenUsageFileCache()

    private struct CodexScanResult {
        let snapshot: LocalTokenUsageSnapshot
        let state: LocalTokenUsageCodexParserState
        let processedByteCount: Int64
    }

    private struct ClaudeScanResult {
        let snapshot: LocalTokenUsageSnapshot
        let state: LocalTokenUsageClaudeParserState
        let processedByteCount: Int64
    }

    static func todayUsage(
        includeCodex: Bool = true,
        includeClaude: Bool = true,
        now: Date = Date(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [ProviderIconKind: LocalTokenUsageSnapshot] {
        defer {
            malloc_zone_pressure_relief(nil, 0)
        }

        let snapshots = [
            includeCodex ? codexUsage(now: now, environment: environment) : nil,
            includeClaude ? claudeUsage(now: now, environment: environment) : nil
        ].compactMap { $0 }

        return snapshots.reduce(into: [:]) { partial, snapshot in
            guard !snapshot.isEmpty else { return }
            partial[snapshot.provider] = snapshot
        }
    }

    private static func codexUsage(
        now: Date,
        environment: [String: String]
    ) -> LocalTokenUsageSnapshot {
        var total = LocalTokenUsageSnapshot.empty(provider: .codex)
        for root in codexSessionRoots(environment: environment) {
            for file in jsonlFiles(root: root, now: now) {
                total = total + cachedCodexUsage(file: file, now: now)
            }
        }
        return total
    }

    private static func codexUsage(
        fileURL: URL,
        now: Date,
        startOffset: UInt64 = 0,
        initialState: LocalTokenUsageCodexParserState = .empty,
        processTrailingLine: Bool = true
    ) -> CodexScanResult {
        var total = LocalTokenUsageSnapshot.empty(provider: .codex)
        var state = initialState

        let processedByteCount = scanLines(
            fileURL: fileURL,
            startOffset: startOffset,
            processTrailingLine: processTrailingLine,
            anyMarkers: [codexTurnContextMarker, codexTokenCountMarker]
        ) { line in
            if line.range(of: codexTurnContextMarker) != nil {
                state.currentModelName = modelName(in: line) ?? state.currentModelName
                state.currentReasoningEffort = reasoningEffort(in: line) ?? state.currentReasoningEffort
                return
            }
            guard line.range(of: codexEventMarker) != nil,
                  line.range(of: codexTokenCountMarker) != nil else {
                return
            }

            let modelName = modelName(in: line) ?? state.currentModelName
            let isToday = timestampDate(in: line).map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
            let totalUsage = usageSnapshot(
                provider: .codex,
                modelName: modelName,
                reasoningEffort: state.currentReasoningEffort,
                objectKey: totalTokenUsageKey,
                in: line
            )

            if let lastUsage = usageSnapshot(
                provider: .codex,
                modelName: modelName,
                reasoningEffort: state.currentReasoningEffort,
                objectKey: lastTokenUsageKey,
                in: line
            ) {
                if isToday {
                    total = total + lastUsage
                }
                state.previousTotals = totalUsage ?? ((state.previousTotals ?? .empty(provider: .codex)) + lastUsage)
                return
            }

            if let totalUsage {
                let delta = totalUsage - (state.previousTotals ?? .empty(provider: .codex))
                if isToday {
                    total = total + delta
                }
                state.previousTotals = totalUsage
            }
        }

        return CodexScanResult(
            snapshot: total,
            state: state,
            processedByteCount: int64ByteCount(processedByteCount)
        )
    }

    private static func claudeUsage(
        now: Date,
        environment: [String: String]
    ) -> LocalTokenUsageSnapshot {
        var total = LocalTokenUsageSnapshot.empty(provider: .claude)

        for root in claudeProjectRoots(environment: environment) {
            for file in jsonlFiles(root: root, now: now) {
                total = total + cachedClaudeUsage(file: file, now: now)
            }
        }

        return total
    }

    private static func claudeUsage(
        fileURL: URL,
        now: Date,
        startOffset: UInt64 = 0,
        initialState: LocalTokenUsageClaudeParserState = .empty,
        processTrailingLine: Bool = true
    ) -> ClaudeScanResult {
        var state = initialState

        let processedByteCount = scanLines(
            fileURL: fileURL,
            startOffset: startOffset,
            processTrailingLine: processTrailingLine,
            requiredMarkers: [claudeAssistantMarker, usageMarker]
        ) { line in
            guard let date = timestampDate(in: line),
                  Calendar.current.isDate(date, inSameDayAs: now),
                  let tokens = usageSnapshot(
                    provider: .claude,
                    modelName: modelName(in: line),
                    reasoningEffort: nil,
                    objectKey: usageKey,
                    in: line
                  ),
                  !tokens.isEmpty else {
                return
            }

            let messageID = objectRange(after: messageKey, in: line).flatMap {
                stringValue(after: idKey, in: line, searchRange: $0)
            }
            let requestID = stringValue(after: requestIDKey, in: line)
            if let messageID, let requestID {
                state.keyedRows["\(messageID):\(requestID)"] = tokens
            } else {
                state.unkeyedTotal = state.unkeyedTotal + tokens
            }
        }

        return ClaudeScanResult(
            snapshot: state.total,
            state: state,
            processedByteCount: int64ByteCount(processedByteCount)
        )
    }

    private static func codexSessionRoots(environment: [String: String]) -> [URL] {
        let rawCodexHome = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: URL
        if let rawCodexHome, !rawCodexHome.isEmpty {
            base = URL(fileURLWithPath: rawCodexHome, isDirectory: true)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        }
        let sessions = base.appendingPathComponent("sessions", isDirectory: true)
        let archived = base.appendingPathComponent("archived_sessions", isDirectory: true)
        return [sessions, archived]
    }

    private static func claudeProjectRoots(environment: [String: String]) -> [URL] {
        if let raw = environment["CLAUDE_CONFIG_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            return raw.split(separator: ",").map { part in
                let url = URL(fileURLWithPath: String(part).trimmingCharacters(in: .whitespacesAndNewlines))
                return url.lastPathComponent == "projects" ? url : url.appendingPathComponent("projects", isDirectory: true)
            }
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".config/claude/projects", isDirectory: true),
            home.appendingPathComponent(".claude/projects", isDirectory: true)
        ]
    }

    private static func jsonlFiles(root: URL, now: Date) -> [LocalTokenUsageFile] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let cutoff = Calendar.current.startOfDay(for: now)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var output: [LocalTokenUsageFile] = []
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "jsonl" else { continue }
            let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
            )
            guard values?.isRegularFile == true else { continue }
            if let modifiedAt = values?.contentModificationDate, modifiedAt < cutoff {
                continue
            }
            output.append(
                LocalTokenUsageFile(
                    url: fileURL,
                    modifiedAtMilliseconds: milliseconds(since1970: values?.contentModificationDate),
                    byteCount: Int64(values?.fileSize ?? 0)
                )
            )
        }
        return output
    }

    private static func cachedCodexUsage(file: LocalTokenUsageFile, now: Date) -> LocalTokenUsageSnapshot {
        let identity = cacheIdentity(provider: .codex, file: file, now: now)
        let signature = file.signature

        if let cached = fileCache.snapshot(identity: identity, signature: signature) {
            return cached
        }

        if let entry = fileCache.incrementalEntry(identity: identity, signature: signature),
           case .codex(let state) = entry.parserState {
            let result = codexUsage(
                fileURL: file.url,
                now: now,
                startOffset: uint64ByteCount(entry.processedByteCount),
                initialState: state,
                processTrailingLine: false
            )
            let snapshot = entry.snapshot + result.snapshot
            fileCache.store(
                snapshot,
                identity: identity,
                signature: signature,
                processedByteCount: result.processedByteCount,
                parserState: .codex(result.state),
                scannedAt: now
            )
            return snapshot
        }

        let result = autoreleasepool {
            codexUsage(fileURL: file.url, now: now)
        }
        fileCache.store(
            result.snapshot,
            identity: identity,
            signature: signature,
            processedByteCount: result.processedByteCount,
            parserState: .codex(result.state),
            scannedAt: now
        )
        return result.snapshot
    }

    private static func cachedClaudeUsage(file: LocalTokenUsageFile, now: Date) -> LocalTokenUsageSnapshot {
        let identity = cacheIdentity(provider: .claude, file: file, now: now)
        let signature = file.signature

        if let cached = fileCache.snapshot(identity: identity, signature: signature) {
            return cached
        }

        if let entry = fileCache.incrementalEntry(identity: identity, signature: signature),
           case .claude(let state) = entry.parserState {
            let result = claudeUsage(
                fileURL: file.url,
                now: now,
                startOffset: uint64ByteCount(entry.processedByteCount),
                initialState: state,
                processTrailingLine: false
            )
            fileCache.store(
                result.snapshot,
                identity: identity,
                signature: signature,
                processedByteCount: result.processedByteCount,
                parserState: .claude(result.state),
                scannedAt: now
            )
            return result.snapshot
        }

        let result = autoreleasepool {
            claudeUsage(fileURL: file.url, now: now)
        }
        fileCache.store(
            result.snapshot,
            identity: identity,
            signature: signature,
            processedByteCount: result.processedByteCount,
            parserState: .claude(result.state),
            scannedAt: now
        )
        return result.snapshot
    }

    private static func cacheIdentity(
        provider: ProviderIconKind,
        file: LocalTokenUsageFile,
        now: Date
    ) -> LocalTokenUsageCacheIdentity {
        let identity = LocalTokenUsageCacheIdentity(
            providerID: provider.providerID,
            path: file.url.path,
            dayStartMilliseconds: milliseconds(since1970: Calendar.current.startOfDay(for: now))
        )
        return identity
    }

    private static func uint64ByteCount(_ value: Int64) -> UInt64 {
        UInt64(max(0, value))
    }

    private static func int64ByteCount(_ value: UInt64) -> Int64 {
        Int64(min(value, UInt64(Int64.max)))
    }

    @discardableResult
    private static func scanLines(
        fileURL: URL,
        startOffset: UInt64 = 0,
        processTrailingLine: Bool = true,
        requiredMarkers: [Data] = [],
        anyMarkers: [Data] = [],
        onLine: (Data) -> Void
    ) -> UInt64 {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return startOffset }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: startOffset)
        } catch {
            return startOffset
        }

        let newline = Data([0x0A])
        var buffer = Data()
        var bufferStartOffset = startOffset
        var readOffset = startOffset
        var isSkippingUnmatchedLongLine = false

        while true {
            var chunk: Data?
            do {
                chunk = try handle.read(upToCount: readChunkSize)
            } catch {
                break
            }

            guard var chunk, !chunk.isEmpty else {
                break
            }
            let chunkStartOffset = readOffset
            readOffset += UInt64(chunk.count)

            if isSkippingUnmatchedLongLine {
                guard let newlineRange = chunk.range(of: newline) else {
                    continue
                }
                let remainderStart = newlineRange.upperBound
                bufferStartOffset = chunkStartOffset + UInt64(remainderStart)
                if remainderStart < chunk.endIndex {
                    chunk = chunk.subdata(in: remainderStart..<chunk.endIndex)
                } else {
                    continue
                }
                isSkippingUnmatchedLongLine = false
            }

            buffer.append(chunk)
            if buffer.count > maxBufferedLineBytes,
               buffer.range(of: newline) == nil,
               !lineMatches(buffer, in: 0..<buffer.endIndex, requiredMarkers: requiredMarkers, anyMarkers: anyMarkers) {
                buffer.removeAll(keepingCapacity: false)
                isSkippingUnmatchedLongLine = true
                bufferStartOffset = readOffset
                continue
            }

            while let range = buffer.range(of: newline) {
                let lineRange = 0..<range.lowerBound
                if lineMatches(buffer, in: lineRange, requiredMarkers: requiredMarkers, anyMarkers: anyMarkers) {
                    let line = buffer.subdata(in: lineRange)
                    onLine(line)
                }
                bufferStartOffset += UInt64(range.upperBound)
                buffer.removeSubrange(0..<range.upperBound)
                if buffer.isEmpty {
                    buffer.removeAll(keepingCapacity: false)
                }
            }
        }

        if processTrailingLine,
           lineMatches(buffer, in: 0..<buffer.endIndex, requiredMarkers: requiredMarkers, anyMarkers: anyMarkers) {
            onLine(buffer)
            return readOffset
        }

        return buffer.isEmpty ? readOffset : bufferStartOffset
    }

    private static func lineMatches(
        _ buffer: Data,
        in range: Range<Data.Index>,
        requiredMarkers: [Data],
        anyMarkers: [Data]
    ) -> Bool {
        guard !range.isEmpty else { return false }
        guard requiredMarkers.allSatisfy({ marker in
            buffer.range(of: marker, options: [], in: range) != nil
        }) else { return false }

        guard !anyMarkers.isEmpty else { return true }
        return anyMarkers.contains { marker in
            buffer.range(of: marker, options: [], in: range) != nil
        }
    }

    private static func timestampDate(in line: Data) -> Date? {
        stringValue(after: timestampKey, in: line).flatMap(parseDate)
    }

    private static func modelName(in line: Data) -> String? {
        stringValue(after: modelKey, in: line)
            ?? stringValue(after: modelNameKey, in: line)
    }

    private static func reasoningEffort(in line: Data) -> String? {
        stringValue(after: effortKey, in: line)
            ?? stringValue(after: reasoningEffortKey, in: line)
    }

    private static func usageSnapshot(
        provider: ProviderIconKind,
        modelName: String?,
        reasoningEffort: String?,
        objectKey: Data,
        in line: Data
    ) -> LocalTokenUsageSnapshot? {
        guard let range = objectRange(after: objectKey, in: line) else { return nil }
        return tokenCounts(
            provider: provider,
            modelName: modelName,
            reasoningEffort: reasoningEffort,
            in: line,
            range: range
        )
    }

    private static func tokenCounts(
        provider: ProviderIconKind,
        modelName: String?,
        reasoningEffort: String?,
        in line: Data,
        range: Range<Data.Index>
    ) -> LocalTokenUsageSnapshot? {
        let input = intValue(for: inputTokenKeys, in: line, range: range)
        let cacheRead = intValue(for: cacheReadTokenKeys, in: line, range: range)
        let cacheCreation = intValue(for: cacheCreationTokenKeys, in: line, range: range)
        let output = intValue(for: outputTokenKeys, in: line, range: range)
        let directTotal = intValue(for: totalTokenKeys, in: line, range: range)
        let reasoningOutput = intValue(for: reasoningOutputTokenKeys, in: line, range: range)
        let estimatedCost = LocalTokenUsagePricing.estimatedCost(
            provider: provider,
            modelName: modelName,
            inputTokens: input,
            cacheReadTokens: cacheRead,
            cacheCreationTokens: cacheCreation,
            outputTokens: output
        )

        let explicit = LocalTokenUsageSnapshot(
            provider: provider,
            inputTokens: input,
            cacheReadTokens: cacheRead,
            cacheCreationTokens: cacheCreation,
            outputTokens: output,
            reasoningOutputTokens: reasoningOutput,
            reasoningEffort: reasoningEffort,
            reportedTotalTokens: directTotal > 0 ? directTotal : nil,
            estimatedCostAmount: estimatedCost?.amount,
            estimatedCostUnit: estimatedCost?.unit
        )
        guard directTotal > 0 || !explicit.isEmpty else { return nil }
        return explicit
    }

    private static func objectRange(after marker: Data, in line: Data) -> Range<Data.Index>? {
        guard let markerRange = line.range(of: marker) else { return nil }
        var index = markerRange.upperBound
        while index < line.endIndex, isWhitespace(line[index]) {
            index += 1
        }
        guard index < line.endIndex, line[index] == 123 else { return nil }
        return balancedObjectRange(startingAt: index, in: line)
    }

    private static func balancedObjectRange(startingAt start: Data.Index, in line: Data) -> Range<Data.Index>? {
        var index = start
        var depth = 0
        var isInString = false
        var isEscaped = false

        while index < line.endIndex {
            let byte = line[index]
            if isInString {
                if isEscaped {
                    isEscaped = false
                } else if byte == 92 {
                    isEscaped = true
                } else if byte == 34 {
                    isInString = false
                }
            } else if byte == 34 {
                isInString = true
            } else if byte == 123 {
                depth += 1
            } else if byte == 125 {
                depth -= 1
                if depth == 0 {
                    return start..<(index + 1)
                }
            }
            index += 1
        }

        return nil
    }

    private static func stringValue(
        after marker: Data,
        in line: Data,
        searchRange: Range<Data.Index>? = nil
    ) -> String? {
        let range = searchRange ?? line.startIndex..<line.endIndex
        guard let markerRange = line.range(of: marker, options: [], in: range) else { return nil }
        var index = markerRange.upperBound
        var isEscaped = false

        while index < range.upperBound {
            let byte = line[index]
            if isEscaped {
                isEscaped = false
            } else if byte == 92 {
                isEscaped = true
            } else if byte == 34 {
                guard index > markerRange.upperBound else { return "" }
                return String(decoding: line[markerRange.upperBound..<index], as: UTF8.self)
            }
            index += 1
        }

        return nil
    }

    private static func intValue(for markers: [Data], in line: Data, range: Range<Data.Index>) -> Int {
        for marker in markers {
            if let value = intValue(after: marker, in: line, range: range) {
                return value
            }
        }
        return 0
    }

    private static func intValue(after marker: Data, in line: Data, range: Range<Data.Index>) -> Int? {
        guard let markerRange = line.range(of: marker, options: [], in: range) else { return nil }
        var index = markerRange.upperBound
        while index < range.upperBound, isWhitespace(line[index]) {
            index += 1
        }

        if index < range.upperBound, line[index] == 34 {
            index += 1
        }

        var value = 0
        var hasDigit = false
        while index < range.upperBound {
            let byte = line[index]
            guard byte >= 48, byte <= 57 else { break }
            hasDigit = true
            value = (value * 10) + Int(byte - 48)
            index += 1
        }

        return hasDigit ? value : nil
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 32 || byte == 9 || byte == 10 || byte == 13
    }

    private static func milliseconds(since1970 date: Date?) -> Int64 {
        guard let date else { return 0 }
        return Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    private static func parseDate(_ value: String) -> Date? {
        if let numeric = Double(value), numeric.isFinite {
            return Date(timeIntervalSince1970: numeric > 1_000_000_000_000 ? numeric / 1000 : numeric)
        }

        if let date = isoFormatter.date(from: value) {
            return date
        }
        return fallbackISOFormatter.date(from: value)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
