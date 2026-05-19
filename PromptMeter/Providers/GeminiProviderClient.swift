import Darwin
import Foundation

struct GeminiRateLimitWindow: Equatable, Sendable {
    let usedPercent: Double
    let remainingPercent: Double
    let resetsAt: Date?
}

struct GeminiNamedRateLimitWindow: Equatable, Sendable {
    let id: String
    let title: String
    let window: GeminiRateLimitWindow
}

struct GeminiProviderSnapshot: Equatable, Sendable {
    let planName: String
    let rawPlanName: String?
    let cliPath: String
    let version: String?
    let usageSource: String
    let primaryTitle: String
    let primary: GeminiRateLimitWindow?
    let secondaryTitle: String
    let secondary: GeminiRateLimitWindow?
    let extraWindows: [GeminiNamedRateLimitWindow]

    var hasRateLimits: Bool {
        primary != nil || secondary != nil || !extraWindows.isEmpty
    }
}

enum GeminiProviderState: Equatable, Sendable {
    case checking
    case connected(GeminiProviderSnapshot)
    case missingCLI
    case needsLogin
    case unavailable(String)
}

enum GeminiProviderClientError: Error, Equatable, Sendable {
    case missingCLI
    case launchFailed(String)
    case timedOut(String)
    case needsLogin(String)
    case invalidResponse(String)
}

struct GeminiProviderClient: Sendable {
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 8) {
        self.timeout = timeout
    }

    nonisolated func fetchState() -> GeminiProviderState {
        do {
            return .connected(try fetchSnapshot())
        } catch GeminiProviderClientError.missingCLI {
            return .missingCLI
        } catch GeminiProviderClientError.needsLogin {
            return .needsLogin
        } catch GeminiProviderClientError.timedOut(let message) {
            return .unavailable(message.isEmpty ? "Gemini CLI did not respond." : message)
        } catch GeminiProviderClientError.launchFailed(let message),
                GeminiProviderClientError.invalidResponse(let message) {
            return .unavailable(message)
        } catch {
            return .unavailable("Gemini usage could not be read.")
        }
    }

    nonisolated private func fetchSnapshot() throws -> GeminiProviderSnapshot {
        guard let geminiURL = Self.locateExecutable(named: "gemini") else {
            throw GeminiProviderClientError.missingCLI
        }

        let version = Self.cleanVersion(try? runGemini(
            arguments: ["--version"],
            executable: geminiURL,
            stdin: nil,
            commandTimeout: 2
        ))
        let statsOutput = try runGemini(
            arguments: [],
            executable: geminiURL,
            stdin: "/stats model\n/quit\n/exit\n",
            commandTimeout: timeout
        )
        let cleanedOutput = Self.normalizedOutput(statsOutput)

        guard !cleanedOutput.isEmpty else {
            throw GeminiProviderClientError.invalidResponse("Gemini stats output was empty.")
        }

        if Self.requiresLogin(cleanedOutput) {
            throw GeminiProviderClientError.needsLogin(cleanedOutput)
        }

        let windows = Self.parseQuotaWindows(from: cleanedOutput)
        let primary = windows.first
        let secondary = windows.dropFirst().first
        let extras = windows.dropFirst(2).map {
            GeminiNamedRateLimitWindow(id: $0.id, title: $0.title, window: $0.window)
        }

        return GeminiProviderSnapshot(
            planName: Self.displayPlanName(from: cleanedOutput),
            rawPlanName: Self.rawPlanName(from: cleanedOutput),
            cliPath: geminiURL.path,
            version: version,
            usageSource: "/stats model",
            primaryTitle: primary?.title ?? ProviderQuotaWindowKind.session.title,
            primary: primary?.window,
            secondaryTitle: secondary?.title ?? ProviderQuotaWindowKind.weekly.title,
            secondary: secondary?.window,
            extraWindows: extras
        )
    }

    nonisolated private func runGemini(
        arguments: [String],
        executable: URL,
        stdin: String?,
        commandTimeout: TimeInterval
    ) throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = Self.providerEnvironment()

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        let input: Pipe?
        if stdin != nil {
            let pipe = Pipe()
            process.standardInput = pipe
            input = pipe
        } else {
            input = nil
        }

        do {
            try process.run()
        } catch {
            throw GeminiProviderClientError.launchFailed("Could not start Gemini CLI.")
        }

        if let stdin, let input {
            input.fileHandleForWriting.write(Data(stdin.utf8))
            input.fileHandleForWriting.closeFile()
        }

        let completed = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            process.waitUntilExit()
            completed.signal()
        }

        if completed.wait(timeout: .now() + commandTimeout) == .timedOut {
            process.terminate()
            let partialOutput = Self.combinedOutput(stdout: output, stderr: errors)
            if Self.requiresLogin(partialOutput) {
                throw GeminiProviderClientError.needsLogin(partialOutput)
            }
            throw GeminiProviderClientError.timedOut("Gemini CLI did not respond.")
        }

        let combined = Self.combinedOutput(stdout: output, stderr: errors)

        guard process.terminationStatus == 0 else {
            if Self.requiresLogin(combined) {
                throw GeminiProviderClientError.needsLogin(combined)
            }
            throw GeminiProviderClientError.invalidResponse(combined.isEmpty ? "Gemini CLI returned an error." : combined)
        }

        return combined
    }

    nonisolated private static func combinedOutput(stdout: Pipe, stderr: Pipe) -> String {
        let outputText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return [outputText, errorText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func parseQuotaWindows(
        from output: String
    ) -> [GeminiNamedRateLimitWindow] {
        var windows: [GeminiNamedRateLimitWindow] = []
        var seenIDs = Set<String>()

        for line in output.components(separatedBy: .newlines) {
            let normalizedLine = normalizeTableLine(line)
            guard shouldParseQuotaLine(normalizedLine),
                  let window = quotaWindow(from: normalizedLine) else {
                continue
            }

            let title = title(from: normalizedLine, fallbackIndex: windows.count)
            var id = identifier(from: title)
            if seenIDs.contains(id) {
                id = "\(id)-\(windows.count + 1)"
            }
            seenIDs.insert(id)

            windows.append(GeminiNamedRateLimitWindow(
                id: id,
                title: title,
                window: window
            ))
        }

        return windows.sorted { $0.window.remainingPercent < $1.window.remainingPercent }
    }

    nonisolated private static func quotaWindow(from line: String) -> GeminiRateLimitWindow? {
        let lowercased = line.lowercased()
        let resetDate = resetDate(from: lowercased)

        if let remaining = remainingPercent(from: lowercased) {
            let remainingPercent = clampPercent(remaining)
            return GeminiRateLimitWindow(
                usedPercent: clampPercent(100 - remainingPercent),
                remainingPercent: remainingPercent,
                resetsAt: resetDate
            )
        }

        if let used = usedPercent(from: lowercased) {
            let usedPercent = clampPercent(used)
            return GeminiRateLimitWindow(
                usedPercent: usedPercent,
                remainingPercent: clampPercent(100 - usedPercent),
                resetsAt: resetDate
            )
        }

        if let fraction = usageFraction(from: lowercased) {
            let usedPercent = clampPercent((fraction.used / fraction.limit) * 100)
            return GeminiRateLimitWindow(
                usedPercent: usedPercent,
                remainingPercent: clampPercent(100 - usedPercent),
                resetsAt: resetDate
            )
        }

        return nil
    }

    nonisolated private static func shouldParseQuotaLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        guard lowercased.contains("%") || lowercased.contains("/") else {
            return false
        }

        return lowercased.contains("quota")
            || lowercased.contains("limit")
            || lowercased.contains("remaining")
            || lowercased.contains("left")
            || lowercased.contains("available")
            || lowercased.contains("usage")
            || lowercased.contains("used")
            || lowercased.contains("request")
            || lowercased.contains("gemini")
            || lowercased.contains("model")
    }

    nonisolated private static func remainingPercent(from line: String) -> Double? {
        firstDouble(
            in: line,
            patterns: [
                #"(\d+(?:\.\d+)?)\s*%\s*(?:remaining|left|available)"#,
                #"(?:remaining|left|available)[^\d]*(\d+(?:\.\d+)?)\s*%"#
            ]
        )
    }

    nonisolated private static func usedPercent(from line: String) -> Double? {
        firstDouble(
            in: line,
            patterns: [
                #"(\d+(?:\.\d+)?)\s*%\s*(?:used|usage|utilized|utilization)"#,
                #"(?:used|usage|utilized|utilization)[^\d]*(\d+(?:\.\d+)?)\s*%"#
            ]
        )
    }

    nonisolated private static func usageFraction(from line: String) -> (used: Double, limit: Double)? {
        guard line.contains("quota")
                || line.contains("limit")
                || line.contains("usage")
                || line.contains("used")
                || line.contains("request") else {
            return nil
        }

        let pattern = #"(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)"#
        guard let match = firstMatch(in: line, pattern: pattern),
              match.numberOfRanges >= 3,
              let used = doubleValue(match: match, group: 1, in: line),
              let limit = doubleValue(match: match, group: 2, in: line),
              limit > 0 else {
            return nil
        }

        return (used, limit)
    }

    nonisolated private static func resetDate(from line: String) -> Date? {
        guard line.contains("reset"),
              let seconds = relativeSeconds(from: line) else {
            return nil
        }

        return Date().addingTimeInterval(seconds)
    }

    nonisolated private static func relativeSeconds(from line: String) -> TimeInterval? {
        let pattern = #"(?:(\d+)\s*d)?\s*(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?\s*(?:(\d+)\s*s)?"#
        let matches = matches(in: line, pattern: pattern)

        for match in matches where match.numberOfRanges >= 5 {
            let days = doubleValue(match: match, group: 1, in: line) ?? 0
            let hours = doubleValue(match: match, group: 2, in: line) ?? 0
            let minutes = doubleValue(match: match, group: 3, in: line) ?? 0
            let seconds = doubleValue(match: match, group: 4, in: line) ?? 0
            let total = days * 86_400 + hours * 3_600 + minutes * 60 + seconds
            if total > 0 {
                return total
            }
        }

        return nil
    }

    nonisolated private static func title(from line: String, fallbackIndex: Int) -> String {
        if let model = firstString(in: line, pattern: #"(gemini[-_a-z0-9.]+)"#) {
            return displayModelName(model)
        }

        let lowercased = line.lowercased()
        if lowercased.contains("pro") {
            return "Pro"
        }
        if lowercased.contains("flash") {
            return "Flash"
        }
        if lowercased.contains("session") {
            return ProviderQuotaWindowKind.session.title
        }
        if lowercased.contains("daily") {
            return "Daily"
        }

        return fallbackIndex == 0 ? "Quota" : "Quota \(fallbackIndex + 1)"
    }

    nonisolated private static func displayModelName(_ model: String) -> String {
        let lowercased = model.lowercased()
        if lowercased.contains("pro") {
            return "Pro"
        }
        if lowercased.contains("flash") {
            return "Flash"
        }
        return "Gemini"
    }

    nonisolated private static func rawPlanName(from output: String) -> String? {
        firstString(
            in: output,
            patterns: [
                #"(?im)^\s*(?:plan|tier)\s*[:：]\s*([^\n|]+)"#,
                #"(?i)(Gemini Code Assist[^\n|]+)"#
            ]
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func displayPlanName(from output: String) -> String {
        guard let raw = rawPlanName(from: output), !raw.isEmpty else {
            return "Stats"
        }

        let normalized = raw
            .replacingOccurrences(of: "Gemini Code Assist", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "Code Assist" : normalized
    }

    nonisolated private static func cleanVersion(_ output: String?) -> String? {
        guard let output, !output.isEmpty else { return nil }
        return output
            .replacingOccurrences(of: "Gemini CLI", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func requiresLogin(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("not authenticated")
            || normalized.contains("authenticate")
            || normalized.contains("sign in")
            || normalized.contains("login required")
            || normalized.contains("use /auth")
    }

    nonisolated private static func normalizedOutput(_ output: String) -> String {
        output
            .replacingOccurrences(of: #"\u001B\[[0-?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "│", with: " ")
            .replacingOccurrences(of: "┃", with: " ")
            .replacingOccurrences(of: "║", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func normalizeTableLine(_ line: String) -> String {
        normalizedOutput(line)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func identifier(from title: String) -> String {
        let lowercased = title.lowercased()
        let allowed = lowercased.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }
        return String(allowed)
            .split(separator: "-")
            .joined(separator: "-")
    }

    nonisolated private static func clampPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    nonisolated private static func firstDouble(in value: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            if let match = firstMatch(in: value, pattern: pattern),
               let double = doubleValue(match: match, group: 1, in: value) {
                return double
            }
        }

        return nil
    }

    nonisolated private static func firstString(in value: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let string = firstString(in: value, pattern: pattern) {
                return string
            }
        }

        return nil
    }

    nonisolated private static func firstString(in value: String, pattern: String) -> String? {
        guard let match = firstMatch(in: value, pattern: pattern),
              match.numberOfRanges >= 2 else {
            return nil
        }

        let range = match.range(at: 1)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: value) else {
            return nil
        }

        return String(value[swiftRange])
    }

    nonisolated private static func firstMatch(
        in value: String,
        pattern: String
    ) -> NSTextCheckingResult? {
        matches(in: value, pattern: pattern).first
    }

    nonisolated private static func matches(
        in value: String,
        pattern: String
    ) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        return regex.matches(
            in: value,
            range: NSRange(value.startIndex..<value.endIndex, in: value)
        )
    }

    nonisolated private static func doubleValue(
        match: NSTextCheckingResult,
        group: Int,
        in value: String
    ) -> Double? {
        guard group < match.numberOfRanges else { return nil }

        let range = match.range(at: group)
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: value) else {
            return nil
        }

        return Double(value[swiftRange])
    }

    nonisolated private static func locateExecutable(named name: String) -> URL? {
        var searched = Set<String>()

        for path in executableCandidates(named: name) {
            guard searched.insert(path).inserted else { continue }
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    nonisolated private static func executableCandidates(named name: String) -> [String] {
        let environment = ProcessInfo.processInfo.environment
        let home = environment["HOME"] ?? NSHomeDirectory()
        let pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        var knownDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
            "\(home)/node_modules/.bin"
        ]

        let nvmRoot = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmRoot) {
            knownDirectories.append(contentsOf: versions.map { "\(nvmRoot)/\($0)/bin" })
        }

        return (pathEntries + knownDirectories).map { "\($0)/\(name)" }
    }

    nonisolated private static func providerEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["NO_COLOR"] = "1"
        environment["CLICOLOR"] = "0"
        environment["FORCE_COLOR"] = "0"

        let home = environment["HOME"] ?? NSHomeDirectory()
        var additions = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
            "\(home)/node_modules/.bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        let nvmRoot = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmRoot) {
            additions.append(contentsOf: versions.map { "\(nvmRoot)/\($0)/bin" })
        }

        let currentPath = environment["PATH"] ?? ""
        environment["PATH"] = ([currentPath] + additions)
            .filter { !$0.isEmpty }
            .joined(separator: ":")
        return environment
    }
}
