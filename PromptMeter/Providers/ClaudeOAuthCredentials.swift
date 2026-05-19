import Foundation

actor ClaudeOAuthCredentialCache {
    private var record: ClaudeOAuthCredentialRecord?

    func cachedRecord() -> ClaudeOAuthCredentialRecord? {
        return record
    }

    func store(_ record: ClaudeOAuthCredentialRecord) {
        self.record = record
    }

    func clear() {
        record = nil
    }
}

nonisolated enum ClaudeOAuthCredentialSource: Equatable, Sendable {
    case keychain
    case promptMeterKeychain
    case credentialsFile
    case memory
}

nonisolated struct ClaudeOAuthCredentialRecord: Equatable, Sendable {
    let credentials: ClaudeOAuthCredentials
    let source: ClaudeOAuthCredentialSource
    let sourceName: String
    let sourceData: Data?
}

nonisolated struct ClaudeOAuthCredentials: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scopes: [String]
    let rateLimitTier: String?
    let subscriptionType: String?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    var hasRefreshToken: Bool {
        guard let refreshToken else { return false }
        return !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func parse(data: Data) throws -> ClaudeOAuthCredentials {
        let root = try JSONDecoder().decode(ClaudeOAuthCredentialsRoot.self, from: data)
        guard let oauth = root.claudeAiOauth else {
            throw ClaudeCodeProviderClientError.needsLogin
        }

        let accessToken = oauth.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !accessToken.isEmpty else {
            throw ClaudeCodeProviderClientError.needsLogin
        }

        return ClaudeOAuthCredentials(
            accessToken: accessToken,
            refreshToken: oauth.refreshToken,
            expiresAt: oauth.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
            scopes: oauth.scopes ?? [],
            rateLimitTier: oauth.rateLimitTier,
            subscriptionType: oauth.subscriptionType
        )
    }
}

nonisolated struct ClaudeOAuthTokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

nonisolated struct ClaudeOAuthCredentialsRoot: Decodable {
    let claudeAiOauth: ClaudeOAuthCredentialsPayload?
}

nonisolated struct ClaudeOAuthCredentialsPayload: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Double?
    let scopes: [String]?
    let rateLimitTier: String?
    let subscriptionType: String?
}
