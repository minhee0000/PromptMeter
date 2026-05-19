import Foundation

enum ProviderIconKind: Hashable, Sendable {
    case codex
    case claude
    case gemini

    nonisolated var providerID: String {
        switch self {
        case .codex:
            return "codex"
        case .claude:
            return "claude-code"
        case .gemini:
            return "gemini-cli"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude Code"
        case .gemini:
            return "Gemini CLI"
        }
    }

    nonisolated var assetName: String {
        switch self {
        case .codex:
            return "ProviderCodex"
        case .claude:
            return "ProviderClaude"
        case .gemini:
            return "ProviderGemini"
        }
    }

    nonisolated var installGuideURL: URL {
        switch self {
        case .codex:
            return URL(string: "https://github.com/openai/codex#quickstart")!
        case .claude:
            return URL(string: "https://docs.anthropic.com/en/docs/claude-code/setup")!
        case .gemini:
            return URL(string: "https://github.com/google-gemini/gemini-cli/blob/main/docs/get-started/index.md")!
        }
    }

    nonisolated var loginCommand: String {
        switch self {
        case .codex:
            return "codex login"
        case .claude:
            return "claude auth login"
        case .gemini:
            return "gemini"
        }
    }

    nonisolated var installCommand: String {
        switch self {
        case .codex:
            return "npm install -g @openai/codex"
        case .claude:
            return "npm install -g @anthropic-ai/claude-code"
        case .gemini:
            return "npm install -g @google/gemini-cli"
        }
    }
}

enum ProviderQuotaWindowKind: Sendable {
    case session
    case weekly

    nonisolated var id: String {
        switch self {
        case .session:
            return "session"
        case .weekly:
            return "weekly"
        }
    }

    nonisolated var title: String {
        switch self {
        case .session:
            return "Session"
        case .weekly:
            return "Weekly"
        }
    }

    nonisolated var defaultDuration: TimeInterval {
        switch self {
        case .session:
            return 5 * 60 * 60
        case .weekly:
            return 7 * 24 * 60 * 60
        }
    }

    init?(title: String) {
        switch title.lowercased() {
        case Self.session.title.lowercased():
            self = .session
        case Self.weekly.title.lowercased():
            self = .weekly
        default:
            return nil
        }
    }
}

enum PromptMeterQuotaPolicy {
    static let notificationRemainingThreshold = 25.0
    static let lowProgressRemainingThreshold = 30.0
}
