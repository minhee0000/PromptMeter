import AppKit
import SwiftUI

struct MenuTodayUsageCard: View {
    let items: [MenuTodayUsageItem]
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Today usage")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MenuPalette.panelSecondaryText)
                    .textCase(.uppercase)

                Spacer()

                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MenuPalette.panelSecondaryText)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(
                        Capsule()
                            .fill(MenuPalette.panelControlFill)
                    )
            }

            if items.isEmpty {
                MenuEmptyTodayUsageRow()
            } else {
                VStack(spacing: 7) {
                    ForEach(items) { item in
                        MenuTodayUsageRow(item: item)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MenuPalette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MenuPalette.panelStroke, lineWidth: 1)
        )
    }
}

private struct MenuTodayUsageRow: View {
    let item: MenuTodayUsageItem

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if let provider = item.provider {
                ProviderIconView(kind: provider)
                    .frame(width: 17, height: 17)
            } else if let systemIcon = item.systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MenuPalette.panelIconSecondary)
                    .frame(width: 17)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MenuPalette.panelPrimaryText)
                        .lineLimit(1)
                        .layoutPriority(0)

                    Spacer(minLength: 8)

                    Text(item.value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MenuPalette.panelPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                }

                if !item.metrics.isEmpty {
                    MenuTodayUsageMetrics(metrics: item.metrics)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MenuTodayUsageMetrics: View {
    let metrics: [MenuTodayUsageMetric]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                if index > 0 {
                    Rectangle()
                        .fill(MenuPalette.panelDivider)
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 7)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(metric.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MenuPalette.panelMutedText)
                        .lineLimit(1)

                    Text(metric.value)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MenuPalette.panelSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct MenuEmptyTodayUsageRow: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MenuPalette.panelIconSecondary)
                .frame(width: 17)

            VStack(alignment: .leading, spacing: 2) {
                Text("No token usage today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MenuPalette.panelPrimaryText)

                Text("Local session logs are empty")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MenuPalette.panelSecondaryText)
            }

            Spacer(minLength: 0)
        }
    }
}

struct MenuProviderPanel: View {
    let provider: MenuProviderUsage
    let isLoading: Bool

    private var showsSkeleton: Bool {
        isLoading && provider.isPlaceholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ProviderIconView(kind: provider.icon)
                        .frame(width: 18, height: 18)

                    Text(provider.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MenuPalette.panelPrimaryText)
                }

                Spacer()

                planBadge
            }

            if let detail = provider.detail {
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MenuPalette.panelSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 7) {
                MenuMetricRow(metric: provider.primary, accent: provider.accent, isLoading: isLoading)
                MenuMetricRow(metric: provider.secondary, accent: provider.accent, isLoading: isLoading)
                ForEach(provider.extraMetrics) { metric in
                    MenuMetricRow(metric: metric, accent: provider.accent, isLoading: isLoading)
                }
            }
        }
        .padding(MenuLayout.panelPadding)
        .frame(minHeight: MenuLayout.providerPanelMinHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MenuPalette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MenuPalette.panelStroke, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: isLoading)
    }

    private var planBadge: some View {
        Text(provider.plan)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(MenuPalette.panelSecondaryText.opacity(showsSkeleton ? 0 : 1))
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                Capsule()
                    .fill(MenuPalette.panelControlFill)
            )
            .overlay {
                if showsSkeleton {
                    MenuSkeletonCapsule(width: 42, height: 9)
                }
            }
    }
}

struct MenuMetricRow: View {
    let metric: MenuUsageMetric
    let accent: Color
    let isLoading: Bool

    private var showsSkeleton: Bool {
        isLoading && metric.isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(metric.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MenuPalette.panelMetricTitleText)
                .lineLimit(1)
                .frame(width: MenuLayout.metricTitleWidth, alignment: .leading)

            MenuThinProgressBar(
                progress: metric.progress,
                paceProgress: metric.paceProgress,
                accent: metricAccent,
                isLoading: isLoading
            )
                .frame(width: MenuLayout.metricBarWidth)

            if metric.reset.isEmpty {
                metricValue(width: MenuLayout.metricValueWidth + MenuLayout.metricResetWidth + 8)
            } else {
                metricValue(width: MenuLayout.metricValueWidth)

                metricReset
            }
        }
        .frame(height: 22)
    }

    private func metricValue(width: CGFloat) -> some View {
        Text(metric.value)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(MenuPalette.panelPrimaryText.opacity(showsSkeleton ? 0 : 1))
            .monospacedDigit()
            .lineLimit(1)
            .frame(width: width, alignment: .trailing)
            .overlay(alignment: .trailing) {
                if showsSkeleton {
                    MenuSkeletonCapsule(width: 26, height: 9)
                }
            }
    }

    private var metricAccent: Color {
        metric.isLowQuota ? MenuPalette.lowQuotaProgressAccent : accent
    }

    private var metricReset: some View {
        Text(metric.reset)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(MenuPalette.panelSecondaryText.opacity(showsSkeleton ? 0 : 1))
            .lineLimit(1)
            .frame(width: MenuLayout.metricResetWidth, alignment: .trailing)
            .overlay(alignment: .trailing) {
                if showsSkeleton {
                    MenuSkeletonCapsule(width: 48, height: 8)
                }
            }
    }
}

struct MenuThinProgressBar: View {
    let progress: Double
    let paceProgress: Double?
    let accent: Color
    let isLoading: Bool
    @State private var shimmerPhase = false

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MenuPalette.panelTrack)

                    Capsule()
                        .fill(accent)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))

                    if isLoading {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                MenuPalette.panelShimmer,
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 34)
                        .offset(x: shimmerPhase ? proxy.size.width + 34 : -34)
                        .blendMode(.plusLighter)
                    }

                    if let paceProgress {
                        MenuPaceMarker()
                            .offset(x: markerOffset(progress: paceProgress, width: proxy.size.width))
                            .accessibilityHidden(true)
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 5)
        }
        .frame(height: 7)
        .onAppear {
            if isLoading {
                startShimmer()
            }
        }
        .onChange(of: isLoading) { _, loading in
            if loading {
                startShimmer()
            } else {
                shimmerPhase = false
            }
        }
        .onDisappear {
            shimmerPhase = false
        }
        .animation(
            .linear(duration: 1.25).repeatForever(autoreverses: false),
            value: shimmerPhase
        )
    }

    private func startShimmer() {
        shimmerPhase = false
        DispatchQueue.main.async {
            shimmerPhase = true
        }
    }

    private func markerOffset(progress: Double, width: CGFloat) -> CGFloat {
        let markerWidth = MenuLayout.paceMarkerWidth
        let rawCenter = width * min(max(progress, 0), 1)
        let center = rawCenter.rounded(.toNearestOrAwayFromZero)
        let clampedCenter = min(max(center, markerWidth / 2), width - markerWidth / 2)
        return clampedCenter - markerWidth / 2
    }
}

private struct MenuPaceMarker: View {
    var body: some View {
        Rectangle()
            .fill(MenuPalette.paceMarker)
            .frame(width: MenuLayout.paceMarkerWidth, height: MenuLayout.paceMarkerHeight)
    }
}

struct MenuSkeletonCapsule: View {
    let width: CGFloat
    let height: CGFloat
    @State private var shimmerPhase = false

    var body: some View {
        Capsule()
            .fill(MenuPalette.panelSkeletonFill)
            .frame(width: width, height: height)
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            MenuPalette.panelShimmer,
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: max(proxy.size.width * 0.72, 28))
                    .offset(x: shimmerPhase ? proxy.size.width : -proxy.size.width)
                }
                .clipShape(Capsule())
            }
            .onAppear {
                startShimmer()
            }
            .onDisappear {
                shimmerPhase = false
            }
            .animation(
                .linear(duration: 1.2).repeatForever(autoreverses: false),
                value: shimmerPhase
            )
            .accessibilityHidden(true)
    }

    private func startShimmer() {
        shimmerPhase = false
        DispatchQueue.main.async {
            shimmerPhase = true
        }
    }
}

struct MenuFooterActions: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        VStack(spacing: 4) {
            MenuFooterButton(
                icon: "arrow.clockwise",
                title: model.isRefreshingProviders ? "Refreshing" : "Refresh",
                shortcut: "⌘R",
                isDisabled: model.isRefreshingProviders
            ) {
                model.refreshProviders()
            }
            MenuFooterButton(icon: "gearshape", title: "Settings", shortcut: "⌘,") {
                PromptMeterSettingsWindow.shared.show(model: model)
            }
            MenuFooterButton(icon: "info.circle", title: "About", shortcut: nil) {
                PromptMeterSettingsWindow.shared.show(model: model, selectedTab: .about)
            }
            MenuFooterButton(icon: "power", title: "Quit", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MenuPalette.trackpadSurface)
        )
        .padding(.top, 2)
    }
}

struct MenuFooterButton: View {
    let icon: String
    let title: String
    let shortcut: String?
    var isDisabled = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MenuPalette.iconSecondary)
                    .frame(width: 14)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MenuPalette.primaryText.opacity(0.9))

                Spacer()

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MenuPalette.mutedText)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .padding(.horizontal, MenuLayout.panelPadding)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovering ? MenuPalette.hoverFill : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.62 : 1)
        .onHover { isHovering = $0 && !isDisabled }
    }
}
