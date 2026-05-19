import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SettingsPalette.panelSecondaryText)
                .textCase(.uppercase)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SettingsPalette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(SettingsPalette.panelStroke, lineWidth: 1)
        )
    }
}

struct SettingToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .settingTitle()
                Text(detail)
                    .settingDetail()
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(SettingsPalette.toggleTint)
        }
    }
}

struct SettingPickerRow: View {
    let title: String
    let detail: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .settingTitle()
                Text(detail)
                    .settingDetail()
            }

            Spacer()

            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 112)
        }
    }
}

struct SettingInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .settingDetail()
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SettingsPalette.panelSecondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CommonProviderSettingsCard: View {
    let title: String
    let icon: ProviderIconKind
    let statusColor: Color
    let statusTitle: String
    let statusDetail: String
    let isRefreshing: Bool
    let scheduleText: String?
    let installAction: ProviderInstallAction?
    let loginAction: ProviderCommandAction?
    let debugRows: [SettingsInfoRowData]
    let refreshAction: () -> Void

    var body: some View {
        SettingsCard(title: title) {
            providerHeader

            if let scheduleText {
                SettingDivider()
                SettingInfoRow(title: "Schedule", value: scheduleText)
            }

            if let installAction {
                SettingDivider()
                ProviderInstallRows(action: installAction)
            }

            if let loginAction {
                SettingDivider()
                ProviderCommandRow(action: loginAction, prominent: true)
            }

            if !debugRows.isEmpty {
                SettingDivider()

                ForEach(debugRows) { row in
                    SettingInfoRow(title: row.title, value: row.value)
                }
            }
        }
    }

    private var providerHeader: some View {
        HStack(spacing: 12) {
            ProviderIconView(kind: icon)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .settingTitle()
                Text(statusDetail)
                    .settingDetail()
            }

            Spacer()

            Button(isRefreshing ? L10n.tr(.menuFooterRefreshing) : L10n.tr(.menuFooterRefresh)) {
                refreshAction()
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
        }
    }
}

struct ProviderInstallAction {
    let title: String
    let detail: String
    let command: String
    let primaryButtonTitle: String
    let commandTitle: String
    let primaryAction: () -> Void
    let copyCommandAction: () -> Void
}

struct ProviderCommandAction {
    let title: String
    let command: String
    let copyCommandAction: () -> Void
}

private struct ProviderInstallRows: View {
    let action: ProviderInstallAction

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .settingTitle()
                    Text(action.detail)
                        .settingDetail()
                }

                Spacer()

                Button(action.primaryButtonTitle) {
                    action.primaryAction()
                }
                .buttonStyle(.borderedProminent)
            }

            ProviderCommandRow(
                action: ProviderCommandAction(
                    title: action.commandTitle,
                    command: action.command,
                    copyCommandAction: action.copyCommandAction
                ),
                prominent: false
            )
        }
    }
}

private struct ProviderCommandRow: View {
    let action: ProviderCommandAction
    let prominent: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .settingTitle()
                Text(action.command)
                    .settingDetail()
            }

            Spacer()

            copyButton
        }
    }

    @ViewBuilder
    private var copyButton: some View {
        if prominent {
            Button(L10n.tr(.providerCopyButton)) {
                action.copyCommandAction()
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button(L10n.tr(.providerCopyButton)) {
                action.copyCommandAction()
            }
            .buttonStyle(.bordered)
        }
    }
}

struct SettingDivider: View {
    var body: some View {
        Rectangle()
            .fill(SettingsPalette.divider)
            .frame(height: 1)
    }
}

struct AboutLinkButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(SettingsPalette.accent)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(SettingsPalette.controlFill)
            )
        }
        .buttonStyle(.plain)
    }
}

extension Text {
    func settingTitle() -> some View {
        self
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(SettingsPalette.panelPrimaryText)
    }

    func settingDetail() -> some View {
        self
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(SettingsPalette.panelMutedText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
