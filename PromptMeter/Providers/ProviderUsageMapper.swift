import Foundation
import SwiftUI

struct ProviderUsageSnapshot {
    let id: String
    let name: String
    let icon: ProviderIconKind
    let plan: String
    let detail: String?
    let accent: ProviderAccent
    let primary: ProviderUsageMetricSnapshot
    let secondary: ProviderUsageMetricSnapshot
    let extraMetrics: [ProviderUsageMetricSnapshot]
    let isPlaceholder: Bool

    init(
        id: String,
        name: String,
        icon: ProviderIconKind,
        plan: String,
        detail: String?,
        accent: ProviderAccent,
        primary: ProviderUsageMetricSnapshot,
        secondary: ProviderUsageMetricSnapshot,
        extraMetrics: [ProviderUsageMetricSnapshot],
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.plan = plan
        self.detail = detail
        self.accent = accent
        self.primary = primary
        self.secondary = secondary
        self.extraMetrics = extraMetrics
        self.isPlaceholder = isPlaceholder
    }
}

struct ProviderUsageMetricSnapshot {
    let title: String
    let value: String
    let reset: String
    let progress: Double
    let paceProgress: Double?
    let isLowQuota: Bool

    static func empty(title: String) -> ProviderUsageMetricSnapshot {
        ProviderUsageMetricSnapshot(
            title: title,
            value: "--",
            reset: "--",
            progress: 0,
            paceProgress: nil,
            isLowQuota: false
        )
    }
}

enum ProviderAccent {
    case codex
    case claude
    case gemini

    var color: Color {
        switch self {
        case .codex:
            return MenuPalette.codexProgressAccent
        case .claude:
            return MenuPalette.claudeProgressAccent
        case .gemini:
            return MenuPalette.geminiProgressAccent
        }
    }
}

@MainActor
enum ProviderUsageMapper {
    static let checkingSnapshots = [
        providerSnapshot(
            provider: .codex,
            plan: "Checking",
            detail: nil,
            primary: .empty(title: ProviderQuotaWindowKind.session.title),
            secondary: .empty(title: ProviderQuotaWindowKind.weekly.title),
            isPlaceholder: true
        ),
        providerSnapshot(
            provider: .claude,
            plan: "Checking",
            detail: nil,
            primary: .empty(title: ProviderQuotaWindowKind.session.title),
            secondary: .empty(title: ProviderQuotaWindowKind.weekly.title),
            isPlaceholder: true
        ),
        providerSnapshot(
            provider: .gemini,
            plan: "Checking",
            detail: nil,
            primary: .empty(title: ProviderQuotaWindowKind.session.title),
            secondary: .empty(title: ProviderQuotaWindowKind.weekly.title),
            isPlaceholder: true
        )
    ]

    static func menuProviders(
        codex: CodexProviderState,
        claude: ClaudeCodeProviderState,
        gemini: GeminiProviderState,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> [MenuProviderUsage] {
        [
            codexSnapshot(from: codex, usageBasis: usageBasis, resetStyle: resetStyle),
            claudeSnapshot(from: claude, usageBasis: usageBasis, resetStyle: resetStyle),
            geminiSnapshot(from: gemini, usageBasis: usageBasis, resetStyle: resetStyle)
        ]
        .compactMap { $0.map(MenuProviderUsage.init) }
    }

    private static func codexSnapshot(
        from state: CodexProviderState,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> ProviderUsageSnapshot? {
        switch state {
        case .checking:
            return checkingSnapshots[0]
        case .connected(let snapshot):
            return providerSnapshot(
                provider: .codex,
                plan: snapshot.planName,
                detail: nil,
                primary: codexMetric(title: ProviderQuotaWindowKind.session.title, window: snapshot.primary, usageBasis: usageBasis, resetStyle: resetStyle),
                secondary: codexMetric(title: ProviderQuotaWindowKind.weekly.title, window: snapshot.secondary, usageBasis: usageBasis, resetStyle: resetStyle),
                extraMetrics: []
            )
        case .missingCLI:
            return nil
        case .needsLogin:
            return providerSnapshot(
                provider: .codex,
                plan: "Login required",
                detail: "Run \(ProviderIconKind.codex.loginCommand) from Terminal.",
                primary: .empty(title: ProviderQuotaWindowKind.session.title),
                secondary: .empty(title: ProviderQuotaWindowKind.weekly.title),
                extraMetrics: []
            )
        case .unavailable(let message):
            return providerSnapshot(
                provider: .codex,
                plan: "Unavailable",
                detail: message,
                primary: .empty(title: ProviderQuotaWindowKind.session.title),
                secondary: .empty(title: ProviderQuotaWindowKind.weekly.title),
                extraMetrics: []
            )
        }
    }

    private static func geminiSnapshot(
        from state: GeminiProviderState,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> ProviderUsageSnapshot? {
        switch state {
        case .checking:
            return checkingSnapshots[2]
        case .connected(let snapshot):
            return providerSnapshot(
                provider: .gemini,
                plan: snapshot.planName,
                detail: snapshot.hasRateLimits ? nil : "Gemini stats did not include quota percentages.",
                primary: geminiMetric(title: snapshot.primaryTitle, window: snapshot.primary, usageBasis: usageBasis, resetStyle: resetStyle),
                secondary: geminiMetric(title: snapshot.secondaryTitle, window: snapshot.secondary, usageBasis: usageBasis, resetStyle: resetStyle),
                extraMetrics: snapshot.extraWindows.map {
                    geminiMetric(title: $0.title, window: $0.window, usageBasis: usageBasis, resetStyle: resetStyle)
                }
            )
        case .missingCLI:
            return nil
        case .needsLogin:
            return providerSnapshot(
                provider: .gemini,
                plan: "Login required",
                detail: "Run \(ProviderIconKind.gemini.loginCommand) and sign in with Google.",
                primary: .empty(title: ProviderQuotaWindowKind.session.title),
                secondary: .empty(title: ProviderQuotaWindowKind.weekly.title),
                extraMetrics: []
            )
        case .unavailable(let message):
            return providerSnapshot(
                provider: .gemini,
                plan: "Unavailable",
                detail: message,
                primary: .empty(title: ProviderQuotaWindowKind.session.title),
                secondary: .empty(title: ProviderQuotaWindowKind.weekly.title),
                extraMetrics: []
            )
        }
    }

    private static func claudeSnapshot(
        from state: ClaudeCodeProviderState,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> ProviderUsageSnapshot? {
        switch state {
        case .checking:
            return checkingSnapshots[1]
        case .connected(let snapshot):
            return providerSnapshot(
                provider: .claude,
                plan: snapshot.subscriptionName,
                detail: snapshot.hasRateLimits ? nil : "Claude OAuth usage did not include rate limits.",
                primary: claudeMetric(title: ProviderQuotaWindowKind.session.title, window: snapshot.session, usageBasis: usageBasis, resetStyle: resetStyle),
                secondary: claudeMetric(title: ProviderQuotaWindowKind.weekly.title, window: snapshot.weekly, usageBasis: usageBasis, resetStyle: resetStyle),
                extraMetrics: snapshot.extraWindows.map {
                    claudeMetric(title: $0.title, window: $0.window, usageBasis: usageBasis, resetStyle: resetStyle)
                }
            )
        case .missingCLI:
            return nil
        case .needsLogin:
            return providerSnapshot(
                provider: .claude,
                plan: "Login required",
                detail: "Run \(ProviderIconKind.claude.loginCommand) from Terminal.",
                primary: .empty(title: ProviderQuotaWindowKind.session.title),
                secondary: .empty(title: ProviderQuotaWindowKind.weekly.title),
                extraMetrics: []
            )
        case .unavailable(let message):
            return providerSnapshot(
                provider: .claude,
                plan: "Unavailable",
                detail: message,
                primary: .empty(title: ProviderQuotaWindowKind.session.title),
                secondary: .empty(title: ProviderQuotaWindowKind.weekly.title),
                extraMetrics: []
            )
        }
    }

    private static func providerSnapshot(
        provider: ProviderIconKind,
        plan: String,
        detail: String?,
        primary: ProviderUsageMetricSnapshot,
        secondary: ProviderUsageMetricSnapshot,
        extraMetrics: [ProviderUsageMetricSnapshot] = [],
        isPlaceholder: Bool = false
    ) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            id: provider.providerID,
            name: provider.displayName,
            icon: provider,
            plan: plan,
            detail: detail,
            accent: accent(for: provider),
            primary: primary,
            secondary: secondary,
            extraMetrics: extraMetrics,
            isPlaceholder: isPlaceholder
        )
    }

    private static func accent(for provider: ProviderIconKind) -> ProviderAccent {
        switch provider {
        case .codex:
            return .codex
        case .claude:
            return .claude
        case .gemini:
            return .gemini
        }
    }

    private static func codexMetric(
        title: String,
        window: CodexRateLimitWindow?,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> ProviderUsageMetricSnapshot {
        guard let window else {
            return .empty(title: title)
        }

        return quotaMetric(
            title: title,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            resetsAt: window.resetsAt,
            windowDuration: window.windowDurationMins.map { TimeInterval($0 * 60) } ?? defaultWindowDuration(for: title),
            isLowQuota: window.remainingPercent < PromptMeterQuotaPolicy.lowProgressRemainingThreshold,
            usageBasis: usageBasis,
            resetStyle: resetStyle
        )
    }

    private static func claudeMetric(
        title: String,
        window: ClaudeCodeRateLimitWindow?,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> ProviderUsageMetricSnapshot {
        guard let window else {
            return .empty(title: title)
        }

        return quotaMetric(
            title: title,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            resetsAt: window.resetsAt,
            windowDuration: defaultWindowDuration(for: title),
            isLowQuota: false,
            usageBasis: usageBasis,
            resetStyle: resetStyle
        )
    }

    private static func geminiMetric(
        title: String,
        window: GeminiRateLimitWindow?,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> ProviderUsageMetricSnapshot {
        guard let window else {
            return .empty(title: title)
        }

        return quotaMetric(
            title: title,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            resetsAt: window.resetsAt,
            windowDuration: defaultWindowDuration(for: title),
            isLowQuota: false,
            usageBasis: usageBasis,
            resetStyle: resetStyle
        )
    }

    private static func quotaMetric(
        title: String,
        usedPercent: Double,
        remainingPercent: Double,
        resetsAt: Date?,
        windowDuration: TimeInterval?,
        isLowQuota: Bool,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> ProviderUsageMetricSnapshot {
        let percent: Double
        switch usageBasis {
        case .remaining:
            percent = remainingPercent
        case .used:
            percent = usedPercent
        }
        let pace = paceMarker(
            usedPercent: usedPercent,
            remainingPercent: remainingPercent,
            resetsAt: resetsAt,
            windowDuration: windowDuration,
            usageBasis: usageBasis
        )

        return ProviderUsageMetricSnapshot(
            title: title,
            value: "\(Int(percent.rounded()))%",
            reset: formatReset(resetsAt, style: resetStyle),
            progress: percent / 100,
            paceProgress: pace,
            isLowQuota: isLowQuota
        )
    }

    private static func defaultWindowDuration(for title: String) -> TimeInterval? {
        ProviderQuotaWindowKind(title: title)?.defaultDuration
    }

    private static func paceMarker(
        usedPercent: Double,
        remainingPercent: Double,
        resetsAt: Date?,
        windowDuration: TimeInterval?,
        usageBasis: PromptMeterUsageBasis
    ) -> Double? {
        guard let resetsAt,
              let windowDuration,
              windowDuration > 0,
              remainingPercent > 0 else {
            return nil
        }

        let remaining = resetsAt.timeIntervalSinceNow
        guard remaining > 0, remaining <= windowDuration else {
            return nil
        }

        let expectedUsedPercent = min(max(1 - (remaining / windowDuration), 0), 1) * 100
        guard expectedUsedPercent >= 3 else {
            return nil
        }

        let delta = usedPercent - expectedUsedPercent
        guard abs(delta) > 2 else {
            return nil
        }

        let displayPercent: Double
        switch usageBasis {
        case .remaining:
            displayPercent = 100 - expectedUsedPercent
        case .used:
            displayPercent = expectedUsedPercent
        }

        return min(max(displayPercent / 100, 0), 1)
    }

    private static func formatReset(_ date: Date?, style: PromptMeterResetStyle) -> String {
        guard let date else { return "--" }

        if style == .countdown {
            return formatCountdown(to: date)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Today' HH:mm"
        } else {
            formatter.dateFormat = "EEE HH:mm"
        }

        return formatter.string(from: date)
    }

    private static func formatCountdown(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(max(1, minutes))m"
    }
}
