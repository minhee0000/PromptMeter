import Darwin
import Foundation
import LocalAuthentication
import Security

struct ClaudeCodeProviderClient: Sendable {
    nonisolated private static let oauthUsageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    nonisolated private static let oauthTokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    nonisolated private static let oauthClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    nonisolated private static let oauthBetaHeader = "oauth-2025-04-20"
    nonisolated private static let fallbackClaudeVersion = "2.1.0"
    nonisolated private static let claudeKeychainService = "Claude Code-credentials"
    nonisolated private static let promptMeterKeychainService = "com.seo.promptMeter.oauth-cache"
    nonisolated private static let promptMeterClaudeOAuthAccount = "claude.oauth"
    nonisolated private static let promptMeterKeychainLabel = "PromptMeter Claude OAuth Cache"
    nonisolated private static let keychainAuthenticationUIFail = resolveKeychainAuthenticationUIFail()
    nonisolated private static let cliMetadataTimeout: TimeInterval = 2
    nonisolated private static let credentialCache = ClaudeOAuthCredentialCache()

    private let timeout: TimeInterval

    init(timeout: TimeInterval = 8) {
        self.timeout = timeout
    }

    nonisolated func fetchState(allowClaudeKeychainPrompt: Bool = true) async -> ClaudeCodeProviderState {
        do {
            return .connected(try await fetchSnapshot(allowClaudeKeychainPrompt: allowClaudeKeychainPrompt))
        } catch ClaudeCodeProviderClientError.missingCLI {
            return .missingCLI
        } catch ClaudeCodeProviderClientError.needsLogin {
            return .needsLogin
        } catch ClaudeCodeProviderClientError.timedOut(let message),
                ClaudeCodeProviderClientError.launchFailed(let message),
                ClaudeCodeProviderClientError.invalidResponse(let message) {
            return .unavailable(message)
        } catch {
            return .unavailable("Claude Code usage could not be read.")
        }
    }

    nonisolated private func fetchSnapshot(allowClaudeKeychainPrompt: Bool) async throws -> ClaudeCodeProviderSnapshot {
        guard let claudeURL = Self.locateExecutable(named: "claude") else {
            throw ClaudeCodeProviderClientError.missingCLI
        }

        let versionOutput = try? runClaude(
            arguments: ["--version"],
            executable: claudeURL,
            commandTimeout: Self.cliMetadataTimeout
        )
        let version = Self.cleanVersion(versionOutput)
        let auth: [String: Any]? = nil
        Self.logCredentialEvent("skipping Claude CLI auth status during refresh; using OAuth credentials only")

        Self.logCredentialEvent("loading OAuth credentials")
        var credentialRecord = try await Self.loadOAuthCredentials(allowClaudeKeychainPrompt: allowClaudeKeychainPrompt)
        var credentials = credentialRecord.credentials
        Self.logCredentialEvent("loaded OAuth credentials: \(Self.credentialSummary(credentialRecord))")

        guard credentials.scopes.isEmpty || credentials.scopes.contains("user:profile") else {
            Self.logCredentialEvent("credential scopes missing user:profile; login required")
            throw ClaudeCodeProviderClientError.needsLogin
        }

        if credentials.isExpired {
            Self.logCredentialEvent("cached credential expired; refreshing: \(Self.credentialSummary(credentialRecord))")
            credentialRecord = try await Self.refreshCredentialRecord(credentialRecord)
            credentials = credentialRecord.credentials
            Self.logCredentialEvent("credential refresh completed: \(Self.credentialSummary(credentialRecord))")
        }

        let usage: [String: Any]
        do {
            usage = try await Self.fetchOAuthUsage(
                accessToken: credentials.accessToken,
                claudeVersion: version,
                timeout: timeout
            )
        } catch ClaudeCodeProviderClientError.needsLogin {
            Self.logCredentialEvent("usage API rejected access token; clearing memory cache and refreshing token")
            await Self.credentialCache.clear()
            credentialRecord = try await Self.refreshCredentialRecord(credentialRecord)
            credentials = credentialRecord.credentials
            Self.logCredentialEvent("credential refresh after usage rejection completed: \(Self.credentialSummary(credentialRecord))")
            usage = try await Self.fetchOAuthUsage(
                accessToken: credentials.accessToken,
                claudeVersion: version,
                timeout: timeout
            )
        }
        let session = Self.decodeUsageWindow(from: usage, keys: ["five_hour"])
        let weekly = Self.decodeUsageWindow(from: usage, keys: ["seven_day"])
        let extraWindows = Self.decodeExtraUsageWindows(from: usage)

        guard session != nil || weekly != nil || !extraWindows.isEmpty else {
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth usage response did not include rate limits.")
        }

        let rawSubscription = (auth?["subscriptionType"] as? String) ?? credentials.subscriptionType
        let rawRateLimitTier = credentials.rateLimitTier

        return ClaudeCodeProviderSnapshot(
            accountEmail: auth?["email"] as? String,
            subscriptionName: Self.displayPlanName(
                subscriptionType: rawSubscription,
                rateLimitTier: rawRateLimitTier
            ),
            rawSubscriptionName: rawSubscription,
            authMethod: auth?["authMethod"] as? String,
            apiProvider: auth?["apiProvider"] as? String,
            cliPath: claudeURL.path,
            version: version,
            usageSource: "OAuth API",
            oauthCredentialSource: credentialRecord.sourceName,
            oauthRateLimitTier: rawRateLimitTier,
            oauthExpiresAt: credentials.expiresAt,
            session: session,
            weekly: weekly,
            extraWindows: extraWindows
        )
    }

    nonisolated private static func fetchOAuthUsage(
        accessToken: String,
        claudeVersion: String?,
        timeout: TimeInterval
    ) async throws -> [String: Any] {
        var request = URLRequest(url: oauthUsageURL)
        request.httpMethod = "GET"
        request.timeoutInterval = max(8, timeout)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(oauthBetaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(Self.userAgent(for: claudeVersion), forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth API request failed: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth API response was invalid.")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw ClaudeCodeProviderClientError.needsLogin
        case 429:
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth API is rate limited. Keeping the last usage snapshot.")
        default:
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth API returned HTTP \(httpResponse.statusCode).")
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth usage response was not readable.")
        }

        return object
    }

    nonisolated private static func loadOAuthCredentials(
        allowClaudeKeychainPrompt: Bool
    ) async throws -> ClaudeOAuthCredentialRecord {
        if let cached = await credentialCache.cachedRecord() {
            Self.logCredentialEvent("credential cache hit: \(Self.credentialSummary(cached))")
            return cached
        }

        Self.logCredentialEvent("credential cache miss; checking PromptMeter Keychain cache")
        if let record = loadPromptMeterKeychainRecord() {
            Self.logCredentialEvent("PromptMeter Keychain cache parsed; storing in memory cache: \(Self.credentialSummary(record))")
            await credentialCache.store(record)
            return record
        }

        Self.logCredentialEvent("PromptMeter Keychain cache unavailable; checking credentials file")
        if let record = try loadCredentialsFileRecord() {
            Self.logCredentialEvent("credentials file parsed; storing in memory and PromptMeter Keychain cache: \(Self.credentialSummary(record))")
            await credentialCache.store(record)
            savePromptMeterKeychainCredentials(record.credentials)
            return record
        }

        let promptPolicy = allowClaudeKeychainPrompt ? "prompt allowed" : "without UI"
        Self.logCredentialEvent("credentials file unavailable; reading Claude Keychain \(promptPolicy)")

        do {
            if let data = try readClaudeKeychainCredentials(allowPrompt: allowClaudeKeychainPrompt) {
                let record = ClaudeOAuthCredentialRecord(
                    credentials: try ClaudeOAuthCredentials.parse(data: data),
                    source: .keychain,
                    sourceName: "Claude Keychain",
                    sourceData: data
                )
                Self.logCredentialEvent("Claude Keychain credential parsed; storing in memory and PromptMeter Keychain cache: \(Self.credentialSummary(record))")
                await credentialCache.store(record)
                savePromptMeterKeychainCredentials(record.credentials)
                return record
            }
            Self.logCredentialEvent("Claude Keychain credential not found or not readable without UI")
        } catch let error as ClaudeCodeProviderClientError {
            Self.logCredentialEvent("Claude Keychain read failed with client error: \(error)")
        } catch {
            Self.logCredentialEvent("Claude Keychain read failed with unexpected error: \(error.localizedDescription)")
        }

        Self.logCredentialEvent("no Claude OAuth credentials found; login required")
        throw ClaudeCodeProviderClientError.needsLogin
    }

    nonisolated private static func loadPromptMeterKeychainRecord() -> ClaudeOAuthCredentialRecord? {
        guard let data = readPromptMeterKeychainCredentials() else {
            return nil
        }

        do {
            return ClaudeOAuthCredentialRecord(
                credentials: try ClaudeOAuthCredentials.parse(data: data),
                source: .promptMeterKeychain,
                sourceName: "PromptMeter Keychain",
                sourceData: data
            )
        } catch {
            Self.logCredentialEvent("PromptMeter Keychain cache parse failed; clearing cache")
            clearPromptMeterKeychainCredentials()
            return nil
        }
    }

    nonisolated private static func loadCredentialsFileRecord() throws -> ClaudeOAuthCredentialRecord? {
        guard let data = try? Data(contentsOf: credentialsFileURL()) else {
            return nil
        }

        return ClaudeOAuthCredentialRecord(
            credentials: try ClaudeOAuthCredentials.parse(data: data),
            source: .credentialsFile,
            sourceName: "~/.claude/.credentials.json",
            sourceData: data
        )
    }

    nonisolated private static func refreshCredentialRecord(
        _ record: ClaudeOAuthCredentialRecord
    ) async throws -> ClaudeOAuthCredentialRecord {
        Self.logCredentialEvent("token refresh requested: \(Self.credentialSummary(record))")
        guard let refreshToken = record.credentials.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !refreshToken.isEmpty else {
            Self.logCredentialEvent("token refresh unavailable; missing refresh token")
            throw ClaudeCodeProviderClientError.needsLogin
        }

        var request = URLRequest(url: oauthTokenURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: oauthClientID)
        ]
        request.httpBody = (components.percentEncodedQuery ?? "").data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Self.logCredentialEvent("token refresh network request failed: \(error.localizedDescription)")
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth token refresh failed: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth token refresh response was invalid.")
        }

        guard httpResponse.statusCode == 200 else {
            Self.logCredentialEvent("token refresh returned HTTP \(httpResponse.statusCode)")
            if [400, 401, 403].contains(httpResponse.statusCode) {
                clearPromptMeterKeychainCredentials()
                await credentialCache.clear()
                throw ClaudeCodeProviderClientError.needsLogin
            }
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth token refresh returned HTTP \(httpResponse.statusCode).")
        }

        let tokenResponse: ClaudeOAuthTokenRefreshResponse
        do {
            tokenResponse = try JSONDecoder().decode(ClaudeOAuthTokenRefreshResponse.self, from: data)
        } catch {
            Self.logCredentialEvent("token refresh response could not be decoded")
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth token refresh response was not readable.")
        }

        let refreshedCredentials = ClaudeOAuthCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresAt: Date(timeIntervalSinceNow: TimeInterval(tokenResponse.expiresIn)),
            scopes: record.credentials.scopes,
            rateLimitTier: record.credentials.rateLimitTier,
            subscriptionType: record.credentials.subscriptionType
        )
        let refreshedSourceName = "PromptMeter Keychain"

        if record.source == .keychain {
            Self.logCredentialEvent("skipping Claude Keychain write-back to avoid macOS Keychain prompt")
        }

        savePromptMeterKeychainCredentials(refreshedCredentials)

        let refreshedRecord = ClaudeOAuthCredentialRecord(
            credentials: refreshedCredentials,
            source: .promptMeterKeychain,
            sourceName: refreshedSourceName,
            sourceData: nil
        )
        await credentialCache.store(refreshedRecord)
        Self.logCredentialEvent("token refresh stored in memory and PromptMeter Keychain cache: \(Self.credentialSummary(refreshedRecord)); expiresIn=\(tokenResponse.expiresIn)s")

        return refreshedRecord
    }

    nonisolated private static func readPromptMeterKeychainCredentials() -> Data? {
        Self.logCredentialEvent("PromptMeter Keychain cache read start; service=\(promptMeterKeychainService)")
        let query = keychainCacheQuery(returnData: true)

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            Self.logCredentialEvent("PromptMeter Keychain cache read success")
            return result as? Data
        case errSecItemNotFound:
            Self.logCredentialEvent("PromptMeter Keychain cache item not found")
            return nil
        case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed, errSecNoAccessForItem:
            Self.logCredentialEvent("PromptMeter Keychain cache not readable without UI; status=\(status)")
            return nil
        default:
            Self.logCredentialEvent("PromptMeter Keychain cache read unexpected status=\(status)")
            return nil
        }
    }

    nonisolated private static func savePromptMeterKeychainCredentials(_ credentials: ClaudeOAuthCredentials) {
        let data: Data
        do {
            data = try encodeClaudeCredentials(credentials)
        } catch {
            Self.logCredentialEvent("PromptMeter Keychain cache encode failed: \(error.localizedDescription)")
            return
        }

        let query = keychainCacheQuery(returnData: false)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            Self.logCredentialEvent("PromptMeter Keychain cache updated")
            return
        }

        if updateStatus != errSecItemNotFound {
            Self.logCredentialEvent("PromptMeter Keychain cache update failed; status=\(updateStatus)")
            return
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrLabel as String] = promptMeterKeychainLabel
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            Self.logCredentialEvent("PromptMeter Keychain cache added")
        } else {
            Self.logCredentialEvent("PromptMeter Keychain cache add failed; status=\(addStatus)")
        }
    }

    nonisolated private static func clearPromptMeterKeychainCredentials() {
        let status = SecItemDelete(keychainCacheQuery(returnData: false) as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            Self.logCredentialEvent("PromptMeter Keychain cache cleared")
        } else {
            Self.logCredentialEvent("PromptMeter Keychain cache clear failed; status=\(status)")
        }
    }

    nonisolated private static func keychainCacheQuery(returnData: Bool) -> [String: Any] {
        var query = keychainBaseQuery(
            service: promptMeterKeychainService,
            account: promptMeterClaudeOAuthAccount
        )
        if returnData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            applyNoUIKeychainPolicy(to: &query)
        }
        return query
    }

    nonisolated private static func encodeClaudeCredentials(_ credentials: ClaudeOAuthCredentials) throws -> Data {
        var oauth: [String: Any] = [
            "accessToken": credentials.accessToken,
            "scopes": credentials.scopes
        ]

        if let refreshToken = credentials.refreshToken {
            oauth["refreshToken"] = refreshToken
        }
        if let expiresAt = credentials.expiresAt {
            oauth["expiresAt"] = expiresAt.timeIntervalSince1970 * 1000
        }
        if let rateLimitTier = credentials.rateLimitTier {
            oauth["rateLimitTier"] = rateLimitTier
        }
        if let subscriptionType = credentials.subscriptionType {
            oauth["subscriptionType"] = subscriptionType
        }

        let root: [String: Any] = ["claudeAiOauth": oauth]
        guard JSONSerialization.isValidJSONObject(root) else {
            throw ClaudeCodeProviderClientError.invalidResponse("Claude OAuth credentials could not be encoded.")
        }
        return try JSONSerialization.data(withJSONObject: root, options: [])
    }

    nonisolated private static func readClaudeKeychainCredentials(allowPrompt: Bool) throws -> Data? {
        Self.logCredentialEvent("SecItemCopyMatching start; service=\(claudeKeychainService), allowPrompt=\(allowPrompt)")
        var query = keychainBaseQuery(service: claudeKeychainService)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if !allowPrompt {
            applyNoUIKeychainPolicy(to: &query)
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            Self.logCredentialEvent("SecItemCopyMatching success")
            return result as? Data
        case errSecItemNotFound:
            Self.logCredentialEvent("SecItemCopyMatching item not found")
            return nil
        case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed, errSecNoAccessForItem:
            Self.logCredentialEvent("SecItemCopyMatching skipped to avoid authentication UI; status=\(status)")
            return nil
        default:
            Self.logCredentialEvent("SecItemCopyMatching unexpected status=\(status)")
            return nil
        }
    }

    nonisolated private static func keychainBaseQuery(
        service: String,
        account: String? = nil
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        return query
    }

    nonisolated private static func applyNoUIKeychainPolicy(to query: inout [String: Any]) {
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        query[kSecUseAuthenticationUI as String] = keychainAuthenticationUIFail as CFString
    }

    nonisolated private static func resolveKeychainAuthenticationUIFail() -> String {
        let securityPath = "/System/Library/Frameworks/Security.framework/Security"
        guard let handle = dlopen(securityPath, RTLD_NOW) else {
            return "u_AuthUIF"
        }
        defer { dlclose(handle) }

        guard let symbol = dlsym(handle, "kSecUseAuthenticationUIFail") else {
            return "u_AuthUIF"
        }
        let valuePointer = symbol.assumingMemoryBound(to: CFString?.self)
        return (valuePointer.pointee as String?) ?? "u_AuthUIF"
    }

    nonisolated private static func credentialsFileURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude")
            .appendingPathComponent(".credentials.json")
    }

    nonisolated private func runClaude(
        arguments: [String],
        executable: URL,
        commandTimeout: TimeInterval? = nil
    ) throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = Self.providerEnvironment()

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw ClaudeCodeProviderClientError.launchFailed("Could not start Claude Code CLI.")
        }

        let completed = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            process.waitUntilExit()
            completed.signal()
        }

        if completed.wait(timeout: .now() + (commandTimeout ?? timeout)) == .timedOut {
            process.terminate()
            throw ClaudeCodeProviderClientError.timedOut("Claude Code CLI did not respond.")
        }

        let stdout = output.fileHandleForReading.readDataToEndOfFile()
        let stderr = errors.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: stderr, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ClaudeCodeProviderClientError.invalidResponse(message?.isEmpty == false ? message! : "Claude Code CLI returned an error.")
        }

        return String(data: stdout, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    nonisolated private func decodeAuthStatus(_ output: String) throws -> [String: Any] {
        guard let data = output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeCodeProviderClientError.invalidResponse("Claude Code auth status was not readable.")
        }

        return object
    }

    nonisolated private func readAuthStatus(
        executable: URL,
        commandTimeout: TimeInterval
    ) throws -> [String: Any] {
        let output = try runClaude(
            arguments: ["auth", "status", "--json"],
            executable: executable,
            commandTimeout: commandTimeout
        )
        return try decodeAuthStatus(output)
    }

    nonisolated private static func decodeUsageWindow(
        from usage: [String: Any],
        keys: [String]
    ) -> ClaudeCodeRateLimitWindow? {
        let dictionary = keys
            .lazy
            .compactMap { usage[$0] as? [String: Any] }
            .first

        guard let dictionary,
              let usedPercent = doubleValue(
                dictionary["utilization"]
                    ?? dictionary["used_percentage"]
                    ?? dictionary["usedPercent"]
                    ?? dictionary["used"]
              ) else {
            return nil
        }

        let remainingPercent = doubleValue(
            dictionary["remaining_percentage"]
                ?? dictionary["remainingPercent"]
                ?? dictionary["remaining"]
        ) ?? max(0, 100 - usedPercent)

        return ClaudeCodeRateLimitWindow(
            usedPercent: clampPercent(usedPercent),
            remainingPercent: clampPercent(remainingPercent),
            resetsAt: dateValue(
                dictionary["resets_at"]
                    ?? dictionary["reset_at"]
                    ?? dictionary["resetAt"]
            )
        )
    }

    nonisolated private static func decodeExtraUsageWindows(from usage: [String: Any]) -> [ClaudeCodeNamedRateLimitWindow] {
        [
            (
                id: "claude-sonnet",
                title: "Sonnet",
                keys: ["seven_day_sonnet", "seven_day_opus"],
                preserveNull: false
            ),
            (
                id: "claude-design",
                title: "Designs",
                keys: [
                    "seven_day_design",
                    "seven_day_claude_design",
                    "claude_design",
                    "design",
                    "seven_day_omelette",
                    "omelette",
                    "omelette_promotional"
                ],
                preserveNull: true
            ),
            (
                id: "claude-routines",
                title: "Routines",
                keys: [
                    "seven_day_routines",
                    "seven_day_claude_routines",
                    "claude_routines",
                    "routines",
                    "routine",
                    "seven_day_cowork",
                    "cowork"
                ],
                preserveNull: true
            )
        ].compactMap { definition in
            guard let window = decodeUsageWindow(
                from: usage,
                keys: definition.keys,
                preserveNullKey: definition.preserveNull
            ) else {
                return nil
            }

            return ClaudeCodeNamedRateLimitWindow(
                id: definition.id,
                title: definition.title,
                window: window
            )
        }
    }

    nonisolated private static func decodeUsageWindow(
        from usage: [String: Any],
        keys: [String],
        preserveNullKey: Bool
    ) -> ClaudeCodeRateLimitWindow? {
        if let window = decodeUsageWindow(from: usage, keys: keys) {
            return window
        }

        guard preserveNullKey, keys.contains(where: { usage.keys.contains($0) }) else {
            return nil
        }

        return ClaudeCodeRateLimitWindow(
            usedPercent: 0,
            remainingPercent: 100,
            resetsAt: nil
        )
    }

    nonisolated private static func cleanVersion(_ output: String?) -> String? {
        guard let output, !output.isEmpty else { return nil }
        return output
            .replacingOccurrences(of: " (Claude Code)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func userAgent(for version: String?) -> String {
        let normalized = version?
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let userAgentVersion = normalized?.isEmpty == false ? normalized! : fallbackClaudeVersion
        return "claude-code/\(userAgentVersion)"
    }

    nonisolated private static func displayPlanName(subscriptionType: String?, rateLimitTier: String?) -> String {
        displayRateLimitTier(rateLimitTier) ?? displaySubscriptionName(subscriptionType)
    }

    nonisolated private static func displayRateLimitTier(_ raw: String?) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let words = raw
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        if words.contains("max") || words.contains(where: { $0.hasPrefix("max") }) {
            if let multiplier = maxMultiplier(from: words) {
                return "Max \(multiplier)"
            }
            return "Max"
        }

        if words.contains("pro") {
            return "Pro"
        }
        if words.contains("team") {
            return "Team"
        }
        if words.contains("enterprise") {
            return "Enterprise"
        }
        if words.contains("ultra") {
            return "Ultra"
        }

        return nil
    }

    nonisolated private static func maxMultiplier(from words: [String]) -> String? {
        for word in words {
            let candidates = [
                word,
                word.hasPrefix("max") ? String(word.dropFirst(3)) : ""
            ]

            for candidate in candidates {
                guard candidate.count >= 2,
                      candidate.hasSuffix("x") else {
                    continue
                }

                let number = candidate.dropLast()
                if !number.isEmpty, number.allSatisfy(\.isNumber) {
                    return "\(number)x"
                }
            }
        }

        return nil
    }

    nonisolated private static func displaySubscriptionName(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return ProviderIconKind.claude.displayName }

        switch raw.lowercased() {
        case "max":
            return "Max"
        case "pro":
            return "Pro"
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

    nonisolated private static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
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

    nonisolated private static func dateValue(_ value: Any?) -> Date? {
        if let number = doubleValue(value) {
            let seconds = number > 4_000_000_000 ? number / 1000 : number
            return Date(timeIntervalSince1970: seconds)
        }

        guard let string = value as? String else { return nil }

        if let number = Double(string) {
            let seconds = number > 4_000_000_000 ? number / 1000 : number
            return Date(timeIntervalSince1970: seconds)
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fractionalFormatter.date(from: string) {
            return date
        }

        return ISO8601DateFormatter().date(from: string)
    }

    nonisolated private static func clampPercent(_ value: Double) -> Double {
        max(0, min(100, value))
    }

    nonisolated private static func locateExecutable(named executableName: String) -> URL? {
        var searched = Set<String>()

        for path in executableCandidates(named: executableName) {
            guard searched.insert(path).inserted else { continue }
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    nonisolated private static func executableCandidates(named executableName: String) -> [String] {
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

        return (pathEntries + knownDirectories).map { "\($0)/\(executableName)" }
    }

    nonisolated private static func providerEnvironment() -> [String: String] {
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

    nonisolated private static func credentialSummary(_ record: ClaudeOAuthCredentialRecord) -> String {
        "source=\(record.sourceName), expired=\(record.credentials.isExpired), hasRefreshToken=\(record.credentials.hasRefreshToken), preservesSourceData=\(record.sourceData != nil)"
    }

    nonisolated private static func logCredentialEvent(_ message: String) {
        NSLog("[PromptMeter][ClaudeCredentials] %@", message)
    }
}
