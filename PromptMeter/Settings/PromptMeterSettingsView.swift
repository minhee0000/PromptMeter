import Combine
import SwiftUI

final class PromptMeterSettingsState: ObservableObject {
    @Published var selectedTab: SettingsTab

    init(selectedTab: SettingsTab = .general) {
        self.selectedTab = selectedTab
    }
}

struct PromptMeterSettingsView: View {
    @ObservedObject var model: PromptMeterModel
    @ObservedObject var state: PromptMeterSettingsState

    init(
        model: PromptMeterModel,
        state: PromptMeterSettingsState = PromptMeterSettingsState()
    ) {
        self.model = model
        self.state = state
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            ScrollView(.vertical) {
                selectedPage
                    .padding(.horizontal, SettingsLayout.sidePadding)
                    .padding(.top, 18)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: SettingsLayout.windowWidth, height: SettingsLayout.windowHeight)
        .background(settingsBackground)
    }

    @ViewBuilder
    private var selectedPage: some View {
        switch state.selectedTab {
        case .general:
            GeneralSettingsPage(model: model)
        case .providers:
            ProvidersSettingsPage(model: model)
        case .display:
            DisplaySettingsPage(model: model)
        case .advanced:
            AdvancedSettingsPage(model: model)
        case .about:
            AboutSettingsPage()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SettingsPalette.primaryText)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SettingsPalette.controlFill)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "PromptMeter")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SettingsPalette.primaryText)

                Text(.settingsHeaderSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SettingsPalette.secondaryText)
            }

            Spacer()

            Text(verbatim: state.selectedTab.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SettingsPalette.secondaryText)
        }
        .padding(.horizontal, SettingsLayout.sidePadding)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var tabBar: some View {
        HStack(spacing: 5) {
            ForEach(SettingsTab.allCases) { tab in
                SettingsTabButton(
                    tab: tab,
                    isSelected: state.selectedTab == tab
                ) {
                    state.selectedTab = tab
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SettingsPalette.controlFill)
        )
        .padding(.horizontal, SettingsLayout.sidePadding)
    }

    private var settingsBackground: some View {
        ZStack {
            SettingsPalette.background
            LinearGradient(
                colors: [
                    SettingsPalette.backgroundHighlight,
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(verbatim: tab.displayName)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? SettingsPalette.primaryText : SettingsPalette.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? SettingsPalette.selectedFill : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? SettingsPalette.panelStroke : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
struct PromptMeterSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PromptMeterSettingsView(model: PromptMeterModel(autoRefreshProviders: false))
                .previewDisplayName("Light")
                .preferredColorScheme(.light)

            PromptMeterSettingsView(model: PromptMeterModel(autoRefreshProviders: false))
                .previewDisplayName("Dark")
                .preferredColorScheme(.dark)
        }
        .previewLayout(.fixed(width: SettingsLayout.windowWidth, height: SettingsLayout.windowHeight))
    }
}
#endif
