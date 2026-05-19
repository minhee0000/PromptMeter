import Darwin
import Foundation

struct CodexProviderSnapshot: Equatable, Sendable {
    let accountEmail: String?
    let rawPlanName: String?
    let planName: String
    let cliPath: String
    let limitId: String?
    let limitName: String?
    let primary: CodexRateLimitWindow?
    let secondary: CodexRateLimitWindow?
}

struct CodexRateLimitWindow: Equatable, Sendable {
    let remainingPercent: Double
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Date?
}

enum CodexProviderState: Equatable, Sendable {
    case checking
    case connected(CodexProviderSnapshot)
    case missingCLI
    case needsLogin
    case unavailable(String)
}

enum CodexProviderClientError: Error, Equatable, Sendable {
    case missingCLI
    case launchFailed(String)
    case timedOut(String)
    case invalidResponse(String)
    case serverError(String)
}

struct CodexProviderClient: Sendable {
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 8) {
        self.timeout = timeout
    }

    nonisolated func fetchState() -> CodexProviderState {
        do {
            return .connected(try fetchSnapshot())
        } catch CodexProviderClientError.missingCLI {
            return .missingCLI
        } catch CodexProviderClientError.serverError(let message) where message.localizedCaseInsensitiveContains("auth") {
            return .needsLogin
        } catch CodexProviderClientError.timedOut(let message) {
            return .unavailable(message.isEmpty ? "Codex CLI did not respond." : message)
        } catch CodexProviderClientError.launchFailed(let message),
                CodexProviderClientError.invalidResponse(let message),
                CodexProviderClientError.serverError(let message) {
            return .unavailable(message)
        } catch {
            return .unavailable("Codex usage could not be read.")
        }
    }

    nonisolated private func fetchSnapshot() throws -> CodexProviderSnapshot {
        guard let codexURL = Self.locateCodexExecutable() else {
            throw CodexProviderClientError.missingCLI
        }

        let process = Process()
        process.executableURL = codexURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.environment = Self.codexEnvironment()

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw CodexProviderClientError.launchFailed("Could not start Codex CLI.")
        }

        defer {
            try? inputPipe.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
        }

        try sendStartupRequests(to: inputPipe.fileHandleForWriting)

        let responses = try readResponses(
            from: outputPipe.fileHandleForReading,
            errors: errorPipe.fileHandleForReading,
            process: process
        )

        return try decodeSnapshot(from: responses, cliPath: codexURL.path)
    }

    nonisolated private func sendStartupRequests(to input: FileHandle) throws {
        let initialize: [String: Any] = [
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "promptmeter",
                    "title": "PromptMeter",
                    "version": "0.1.0"
                ],
                "capabilities": NSNull()
            ]
        ]

        let requests: [[String: Any]] = [
            initialize,
            ["method": "initialized"],
            ["id": 2, "method": "account/read", "params": ["refreshToken": false]],
            ["id": 3, "method": "account/rateLimits/read"]
        ]

        for request in requests {
            let data = try JSONSerialization.data(withJSONObject: request)
            input.write(data)
            input.write(Data([0x0A]))
        }
    }

    nonisolated private func readResponses(
        from output: FileHandle,
        errors: FileHandle,
        process: Process
    ) throws -> [Int: [String: Any]] {
        var responses: [Int: [String: Any]] = [:]
        var outputBuffer = Data()
        var stderrText = ""
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if responses[2] != nil && responses[3] != nil {
                return responses
            }

            var descriptors = [
                pollfd(fd: output.fileDescriptor, events: Int16(POLLIN), revents: 0),
                pollfd(fd: errors.fileDescriptor, events: Int16(POLLIN), revents: 0)
            ]

            let remainingMilliseconds = max(1, min(250, Int(deadline.timeIntervalSinceNow * 1000)))
            let ready = Darwin.poll(&descriptors, nfds_t(descriptors.count), Int32(remainingMilliseconds))

            if ready < 0 {
                throw CodexProviderClientError.invalidResponse("Could not read Codex CLI output.")
            }

            if ready == 0 {
                if !process.isRunning {
                    break
                }
                continue
            }

            if descriptors[0].revents & Int16(POLLIN) != 0 {
                let data = output.availableData
                guard !data.isEmpty else { continue }
                outputBuffer.append(data)

                for message in parseJSONLines(from: &outputBuffer) {
                    guard let id = message["id"] as? Int else { continue }
                    responses[id] = message
                }
            }

            if descriptors[1].revents & Int16(POLLIN) != 0 {
                let data = errors.availableData
                if !data.isEmpty {
                    stderrText += String(data: data, encoding: .utf8) ?? ""
                    if stderrText.count > 1_500 {
                        stderrText = String(stderrText.suffix(1_500))
                    }
                }
            }
        }

        if let accountResponse = responses[2] {
            if let error = accountResponse["error"] as? [String: Any] {
                throw CodexProviderClientError.serverError(error["message"] as? String ?? "Codex login is required.")
            }

            if let result = accountResponse["result"] as? [String: Any],
               Self.accountDictionary(from: result) == nil,
               Self.boolValue(result["requiresOpenaiAuth"]) == true {
                throw CodexProviderClientError.serverError("Codex login is required.")
            }
        }

        let trimmedError = stderrText
            .split(separator: "\n")
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        throw CodexProviderClientError.timedOut(trimmedError)
    }

    nonisolated private func parseJSONLines(from buffer: inout Data) -> [[String: Any]] {
        var messages: [[String: Any]] = []
        let newline = Data([0x0A])

        while let range = buffer.firstRange(of: newline) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)

            guard containsNonWhitespace(lineData) else { continue }

            if let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                messages.append(object)
            }
        }

        return messages
    }

    nonisolated private func containsNonWhitespace(_ data: Data) -> Bool {
        data.contains { byte in
            switch byte {
            case 0x09, 0x0A, 0x0D, 0x20:
                return false
            default:
                return true
            }
        }
    }

    nonisolated private func decodeSnapshot(from responses: [Int: [String: Any]], cliPath: String) throws -> CodexProviderSnapshot {
        let accountResult = try responseResult(responses[2], fallback: "Codex account was not returned.")
        let account = Self.accountDictionary(from: accountResult)

        if account == nil, Self.boolValue(accountResult["requiresOpenaiAuth"]) == true {
            throw CodexProviderClientError.serverError("Codex login is required.")
        }

        let rateResult = try responseResult(responses[3], fallback: "Codex rate limits were not returned.")
        let rateLimit = Self.codexRateLimitDictionary(from: rateResult)

        guard account != nil || rateLimit != nil else {
            throw CodexProviderClientError.serverError("Codex login is required.")
        }

        let accountType = account?["type"] as? String
        let accountPlan = account?["planType"] as? String
        let ratePlan = rateLimit?["planType"] as? String
        let rawPlan = accountPlan ?? ratePlan
        let planName = Self.displayPlanName(raw: rawPlan, accountType: accountType)

        return CodexProviderSnapshot(
            accountEmail: account?["email"] as? String,
            rawPlanName: rawPlan,
            planName: planName,
            cliPath: cliPath,
            limitId: rateLimit?["limitId"] as? String,
            limitName: rateLimit?["limitName"] as? String,
            primary: Self.decodeRateLimitWindow(rateLimit?["primary"]),
            secondary: Self.decodeRateLimitWindow(rateLimit?["secondary"])
        )
    }

    nonisolated private func responseResult(_ response: [String: Any]?, fallback: String) throws -> [String: Any] {
        guard let response else {
            throw CodexProviderClientError.invalidResponse(fallback)
        }

        if let error = response["error"] as? [String: Any] {
            throw CodexProviderClientError.serverError(error["message"] as? String ?? fallback)
        }

        guard let result = response["result"] as? [String: Any] else {
            throw CodexProviderClientError.invalidResponse(fallback)
        }

        return result
    }

    nonisolated private static func accountDictionary(from result: [String: Any]) -> [String: Any]? {
        guard let account = result["account"] as? [String: Any] else {
            return nil
        }
        return account
    }

    nonisolated private static func codexRateLimitDictionary(from result: [String: Any]) -> [String: Any]? {
        if let byLimitId = result["rateLimitsByLimitId"] as? [String: Any] {
            if let codex = byLimitId["codex"] as? [String: Any] {
                return codex
            }

            if let first = byLimitId.values.compactMap({ $0 as? [String: Any] }).first {
                return first
            }
        }

        return result["rateLimits"] as? [String: Any]
    }

    nonisolated private static func decodeRateLimitWindow(_ value: Any?) -> CodexRateLimitWindow? {
        guard let dictionary = value as? [String: Any],
              let usedPercent = doubleValue(dictionary["usedPercent"]) else {
            return nil
        }

        let remainingPercent = max(0, min(100, 100 - usedPercent))
        let duration = intValue(dictionary["windowDurationMins"])
        let resetsAt = dateValue(dictionary["resetsAt"])

        return CodexRateLimitWindow(
            remainingPercent: remainingPercent,
            usedPercent: usedPercent,
            windowDurationMins: duration,
            resetsAt: resetsAt
        )
    }

    nonisolated private static func displayPlanName(raw: String?, accountType: String?) -> String {
        guard let raw, !raw.isEmpty else {
            if accountType == "apiKey" {
                return "API Key"
            }
            return ProviderIconKind.codex.displayName
        }

        switch raw.lowercased() {
        case "free":
            return "Free"
        case "plus":
            return "Plus"
        case "pro":
            return "Pro"
        case "prolite":
            return "Pro 5x"
        case "team":
            return "Team"
        case "enterprise":
            return "Enterprise"
        default:
            return raw
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }

    nonisolated private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    nonisolated private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    nonisolated private static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }

    nonisolated private static func dateValue(_ value: Any?) -> Date? {
        guard var timestamp = doubleValue(value), timestamp > 0 else {
            return nil
        }

        if timestamp > 10_000_000_000 {
            timestamp /= 1_000
        }

        return Date(timeIntervalSince1970: timestamp)
    }

    nonisolated private static func locateCodexExecutable() -> URL? {
        var searched = Set<String>()

        for path in executableCandidates() {
            guard searched.insert(path).inserted else { continue }
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    nonisolated private static func executableCandidates() -> [String] {
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

        return (pathEntries + knownDirectories).map { "\($0)/codex" }
    }

    nonisolated private static func codexEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
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
