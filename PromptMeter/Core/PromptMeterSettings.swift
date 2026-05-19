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
}

enum PromptMeterUsageBasis: String, CaseIterable, Identifiable {
    case remaining = "Remaining"
    case used = "Used"

    var id: String { rawValue }
}

enum PromptMeterResetStyle: String, CaseIterable, Identifiable {
    case clock = "Clock"
    case countdown = "Countdown"

    var id: String { rawValue }
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
