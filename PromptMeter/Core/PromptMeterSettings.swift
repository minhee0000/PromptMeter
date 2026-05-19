import Foundation
import ServiceManagement

enum PromptMeterRefreshCadence: String, CaseIterable, Identifiable {
    case thirtySeconds = "30 sec"
    case oneMinute = "1 min"
    case fiveMinutes = "5 min"
    case fifteenMinutes = "15 min"

    var id: String { rawValue }

    var interval: TimeInterval {
        switch self {
        case .thirtySeconds:
            return 30
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 300
        case .fifteenMinutes:
            return 900
        }
    }

    @MainActor
    var displayName: String {
        switch self {
        case .thirtySeconds:
            return L10n.tr(.cadenceThirtySeconds)
        case .oneMinute:
            return L10n.tr(.cadenceOneMinute)
        case .fiveMinutes:
            return L10n.tr(.cadenceFiveMinutes)
        case .fifteenMinutes:
            return L10n.tr(.cadenceFifteenMinutes)
        }
    }

    @MainActor
    static func from(displayName: String) -> PromptMeterRefreshCadence? {
        allCases.first { $0.displayName == displayName }
    }
}

enum PromptMeterUsageBasis: String, CaseIterable, Identifiable {
    case remaining = "Remaining"
    case used = "Used"

    var id: String { rawValue }

    @MainActor
    var displayName: String {
        switch self {
        case .remaining:
            return L10n.tr(.usageBasisRemaining)
        case .used:
            return L10n.tr(.usageBasisUsed)
        }
    }

    @MainActor
    static func from(displayName: String) -> PromptMeterUsageBasis? {
        allCases.first { $0.displayName == displayName }
    }
}

enum PromptMeterResetStyle: String, CaseIterable, Identifiable {
    case clock = "Clock"
    case countdown = "Countdown"

    var id: String { rawValue }

    @MainActor
    var displayName: String {
        switch self {
        case .clock:
            return L10n.tr(.resetStyleClock)
        case .countdown:
            return L10n.tr(.resetStyleCountdown)
        }
    }

    @MainActor
    static func from(displayName: String) -> PromptMeterResetStyle? {
        allCases.first { $0.displayName == displayName }
    }
}

extension PromptMeterLanguage {
    @MainActor
    var displayName: String {
        nativeDisplayName
    }

    @MainActor
    static func from(displayName: String) -> PromptMeterLanguage? {
        allCases.first { $0.displayName == displayName }
    }
}

enum LaunchAtLoginController {
    @MainActor
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @MainActor
    static func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
