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
    private static func checkingPlaceholder(provider: ProviderIconKind) -> ProviderUsageSnapshot {
        providerSnapshot(
            provider: provider,
            plan: L10n.tr(.statusChecking),
            detail: nil,
            primary: .empty(title: ProviderQuotaWindowKind.session.localizedTitle),
            secondary: .empty(title: ProviderQuotaWindowKind.weekly.localizedTitle),
            isPlaceholder: true
        )
    }

    private static func loginRequiredPlaceholder(
        provider: ProviderIconKind,
        detail: String
    ) -> ProviderUsageSnapshot {
        providerSnapshot(
            provider: provider,
            plan: L10n.tr(.providerLoginRequiredPlan),
            detail: detail,
            primary: .empty(title: ProviderQuotaWindowKind.session.localizedTitle),
            secondary: .empty(title: ProviderQuotaWindowKind.weekly.localizedTitle),
            extraMetrics: []
        )
    }

    private static func unavailablePlaceholder(
        provider: ProviderIconKind,
        detail: String
    ) -> ProviderUsageSnapshot {
        providerSnapshot(
            provider: provider,
            plan: L10n.tr(.providerUnavailablePlan),
            detail: detail,
            primary: .empty(title: ProviderQuotaWindowKind.session.localizedTitle),
            secondary: .empty(title: ProviderQuotaWindowKind.weekly.localizedTitle),
            extraMetrics: []
        )
    }

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
            return checkingPlaceholder(provider: .codex)
        case .connected(let snapshot):
            return providerSnapshot(
                provider: .codex,
                plan: snapshot.planName,
                detail: nil,
                primary: codexMetric(title: ProviderQuotaWindowKind.session.localizedTitle, window: snapshot.primary, usageBasis: usageBasis, resetStyle: resetStyle),
                secondary: codexMetric(title: ProviderQuotaWindowKind.weekly.localizedTitle, window: snapshot.secondary, usageBasis: usageBasis, resetStyle: resetStyle),
                extraMetrics: []
            )
        case .missingCLI:
            return nil
        case .needsLogin:
            return loginRequiredPlaceholder(
                provider: .codex,
                detail: L10n.format(.providerLoginRequiredCardDetailFormat, ProviderIconKind.codex.loginCommand)
            )
        case .unavailable(let message):
            return unavailablePlaceholder(provider: .codex, detail: message)
        }
    }

    private static func geminiSnapshot(
        from state: GeminiProviderState,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> ProviderUsageSnapshot? {
        switch state {
        case .checking:
            return checkingPlaceholder(provider: .gemini)
        case .connected(let snapshot):
            return providerSnapshot(
                provider: .gemini,
                plan: snapshot.planName,
                detail: snapshot.hasRateLimits ? nil : L10n.tr(.providerGeminiNoQuotaPercentages),
                primary: geminiMetric(title: snapshot.primaryTitle, window: snapshot.primary, usageBasis: usageBasis, resetStyle: resetStyle),
                secondary: geminiMetric(title: snapshot.secondaryTitle, window: snapshot.secondary, usageBasis: usageBasis, resetStyle: resetStyle),
                extraMetrics: snapshot.extraWindows.map {
                    geminiMetric(title: $0.title, window: $0.window, usageBasis: usageBasis, resetStyle: resetStyle)
                }
            )
        case .missingCLI:
            return nil
        case .needsLogin:
            return loginRequiredPlaceholder(
                provider: .gemini,
                detail: L10n.format(.providerLoginRequiredCardDetailGeminiFormat, ProviderIconKind.gemini.loginCommand)
            )
        case .unavailable(let message):
            return unavailablePlaceholder(provider: .gemini, detail: message)
        }
    }

    private static func claudeSnapshot(
        from state: ClaudeCodeProviderState,
        usageBasis: PromptMeterUsageBasis,
        resetStyle: PromptMeterResetStyle
    ) -> ProviderUsageSnapshot? {
        switch state {
        case .checking:
            return checkingPlaceholder(provider: .claude)
        case .connected(let snapshot):
            return providerSnapshot(
                provider: .claude,
                plan: snapshot.subscriptionName,
                detail: snapshot.hasRateLimits ? nil : L10n.tr(.providerClaudeNoRateLimits),
                primary: claudeMetric(title: ProviderQuotaWindowKind.session.localizedTitle, window: snapshot.session, usageBasis: usageBasis, resetStyle: resetStyle),
                secondary: claudeMetric(title: ProviderQuotaWindowKind.weekly.localizedTitle, window: snapshot.weekly, usageBasis: usageBasis, resetStyle: resetStyle),
                extraMetrics: snapshot.extraWindows.map {
                    claudeMetric(title: $0.title, window: $0.window, usageBasis: usageBasis, resetStyle: resetStyle)
                }
            )
        case .missingCLI:
            return nil
        case .needsLogin:
            return loginRequiredPlaceholder(
                provider: .claude,
                detail: L10n.format(.providerLoginRequiredCardDetailFormat, ProviderIconKind.claude.loginCommand)
            )
        case .unavailable(let message):
            return unavailablePlaceholder(provider: .claude, detail: message)
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
        ProviderQuotaWindowKind(displayTitle: title)?.defaultDuration
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
        guard let date else { return L10n.tr(.commonDash) }

        if style == .countdown {
            return formatCountdown(to: date)
        }

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        if Calendar.current.isDateInToday(date) {
            return L10n.format(.timeTodayFormat, timeFormatter.string(from: date))
        }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = LocalizationManager.shared.resolvedLocale
        weekdayFormatter.dateFormat = "EEE HH:mm"
        return weekdayFormatter.string(from: date)
    }

    private static func formatCountdown(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return L10n.format(.unitDayHourShortFormat, days, hours)
        }

        if hours > 0 {
            return L10n.format(.unitHourMinuteShortFormat, hours, minutes)
        }

        return L10n.format(.unitMinuteShortFormat, max(1, minutes))
    }
}
