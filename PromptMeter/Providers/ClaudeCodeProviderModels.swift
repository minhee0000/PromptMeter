import Foundation

struct ClaudeCodeRateLimitWindow: Equatable, Sendable {
    let usedPercent: Double
    let remainingPercent: Double
    let resetsAt: Date?
}

struct ClaudeCodeNamedRateLimitWindow: Equatable, Sendable {
    let id: String
    let title: String
    let window: ClaudeCodeRateLimitWindow
}

struct ClaudeCodeProviderSnapshot: Equatable, Sendable {
    let accountEmail: String?
    let subscriptionName: String
    let rawSubscriptionName: String?
    let authMethod: String?
    let apiProvider: String?
    let cliPath: String
    let version: String?
    let usageSource: String
    let oauthCredentialSource: String
    let oauthRateLimitTier: String?
    let oauthExpiresAt: Date?
    let session: ClaudeCodeRateLimitWindow?
    let weekly: ClaudeCodeRateLimitWindow?
    let extraWindows: [ClaudeCodeNamedRateLimitWindow]

    var hasRateLimits: Bool {
        session != nil || weekly != nil || !extraWindows.isEmpty
    }
}

enum ClaudeCodeProviderState: Equatable, Sendable {
    case checking
    case connected(ClaudeCodeProviderSnapshot)
    case missingCLI
    case needsLogin
    case unavailable(String)
}

enum ClaudeCodeProviderClientError: Error, Equatable, Sendable {
    case missingCLI
    case launchFailed(String)
    case timedOut(String)
    case invalidResponse(String)
    case needsLogin
}
