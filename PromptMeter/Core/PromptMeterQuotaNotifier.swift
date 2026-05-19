import Foundation
@preconcurrency import UserNotifications

struct QuotaNotificationKey: Hashable, Sendable {
    let providerID: String
    let windowID: String

    nonisolated var notificationIdentifier: String {
        "promptmeter.\(providerID).\(windowID).quota.low"
    }
}

struct QuotaWarning: Sendable {
    let key: QuotaNotificationKey
    let providerName: String
    let windowTitle: String
    let remainingPercent: Double

    nonisolated var roundedPercent: Int {
        max(0, min(100, Int(remainingPercent.rounded())))
    }
}

enum PromptMeterQuotaNotifier {
    private nonisolated static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound]

    nonisolated static func postLowQuota(_ warnings: [QuotaWarning]) {
        guard !warnings.isEmpty else { return }

        let payload = notificationPayload(for: warnings)
        requestAuthorizationAndDeliver(
            identifier: payload.identifier,
            title: payload.title,
            body: payload.body
        )
    }

    nonisolated private static func notificationPayload(
        for warnings: [QuotaWarning]
    ) -> (identifier: String, title: String, body: String) {
        if warnings.count == 1, let warning = warnings.first {
            return (
                identifier: warning.key.notificationIdentifier,
                title: "\(warning.providerName) \(warning.windowTitle.lowercased()) quota low",
                body: "\(warning.windowTitle) remaining is \(warning.roundedPercent)%."
            )
        }

        let singleProviderName = commonProviderName(in: warnings)
        let summary = warnings
            .map { warning in
                if singleProviderName != nil {
                    return "\(warning.windowTitle) \(warning.roundedPercent)%"
                }

                return "\(warning.providerName) \(warning.windowTitle) \(warning.roundedPercent)%"
            }
            .joined(separator: " · ")

        return (
            identifier: "promptmeter.quota.low",
            title: singleProviderName.map { "\($0) quota low" } ?? "Provider quota low",
            body: "\(summary) remaining."
        )
    }

    nonisolated private static func commonProviderName(in warnings: [QuotaWarning]) -> String? {
        guard let first = warnings.first?.providerName,
              warnings.allSatisfy({ $0.providerName == first }) else {
            return nil
        }

        return first
    }

    nonisolated private static func requestAuthorizationAndDeliver(
        identifier: String,
        title: String,
        body: String
    ) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: authorizationOptions) { granted, _ in
                    guard granted else { return }
                    deliver(identifier: identifier, title: title, body: body)
                }
            case .authorized, .provisional, .ephemeral:
                deliver(identifier: identifier, title: title, body: body)
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated private static func deliver(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
