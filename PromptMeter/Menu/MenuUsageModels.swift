import SwiftUI

struct MenuProviderUsage: Identifiable {
    let id: String
    let name: String
    let icon: ProviderIconKind
    let plan: String
    let detail: String?
    let accent: Color
    let primary: MenuUsageMetric
    let secondary: MenuUsageMetric
    let extraMetrics: [MenuUsageMetric]
    let isPlaceholder: Bool

    init(snapshot: ProviderUsageSnapshot) {
        id = snapshot.id
        name = snapshot.name
        icon = snapshot.icon
        plan = snapshot.plan
        detail = snapshot.detail
        accent = snapshot.accent.color
        primary = MenuUsageMetric(snapshot: snapshot.primary)
        secondary = MenuUsageMetric(snapshot: snapshot.secondary)
        extraMetrics = snapshot.extraMetrics.map(MenuUsageMetric.init)
        isPlaceholder = snapshot.isPlaceholder
    }
}

struct MenuTodayUsageItem: Identifiable {
    let id: String
    let provider: ProviderIconKind?
    let systemIcon: String?
    let title: String
    let value: String
    let metrics: [MenuTodayUsageMetric]
    let progress: Double?
}

struct MenuTodayUsageMetric: Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

struct MenuUsageMetric: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let reset: String
    let progress: Double
    let paceProgress: Double?
    let isLowQuota: Bool
    var isEmpty: Bool {
        value == "--" && reset == "--" && progress == 0
    }

    init(
        title: String,
        value: String,
        reset: String,
        progress: Double,
        paceProgress: Double? = nil,
        isLowQuota: Bool = false
    ) {
        self.title = title
        self.value = value
        self.reset = reset
        self.progress = progress
        self.paceProgress = paceProgress
        self.isLowQuota = isLowQuota
    }

    nonisolated init(snapshot: ProviderUsageMetricSnapshot) {
        title = snapshot.title
        value = snapshot.value
        reset = snapshot.reset
        progress = snapshot.progress
        paceProgress = snapshot.paceProgress
        isLowQuota = snapshot.isLowQuota
    }

    static func empty(title: String) -> MenuUsageMetric {
        MenuUsageMetric(title: title, value: "--", reset: "--", progress: 0)
    }
}
