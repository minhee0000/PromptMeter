import AppKit
import SwiftUI

struct GeneralSettingsPage: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard(title: L10n.tr(.settingsGeneralAppCard)) {
                SettingToggleRow(
                    title: L10n.tr(.settingsGeneralStartAtLoginTitle),
                    detail: L10n.tr(.settingsGeneralStartAtLoginDetail),
                    isOn: $model.launchAtLogin
                )

                SettingDivider()

                SettingPickerRow(
                    title: L10n.tr(.settingsGeneralRefreshCadenceTitle),
                    detail: L10n.tr(.settingsGeneralRefreshCadenceDetail),
                    selection: refreshCadenceSelection,
                    options: PromptMeterRefreshCadence.allCases.map(\.displayName)
                )

                SettingDivider()

                SettingPickerRow(
                    title: L10n.tr(.settingsGeneralLanguageTitle),
                    detail: L10n.tr(.settingsGeneralLanguageDetail),
                    selection: languageSelection,
                    options: PromptMeterLanguage.allCases.map(\.displayName)
                )
            }

            SettingsCard(title: L10n.tr(.settingsGeneralRefreshCard)) {
                SettingInfoRow(title: L10n.tr(.settingsGeneralRefreshScheduleTitle), value: model.providerRefreshScheduleText)

                SettingDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(.settingsGeneralRefreshNowTitle)
                            .settingTitle()
                        Text(.settingsGeneralRefreshNowDetail)
                            .settingDetail()
                    }

                    Spacer()

                    Button(model.isRefreshingProviders ? L10n.tr(.settingsGeneralRefreshingButton) : L10n.tr(.settingsGeneralRefreshNowButton)) {
                        model.refreshProviders()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRefreshingProviders)
                }
            }
        }
    }

    private var refreshCadenceSelection: Binding<String> {
        Binding(
            get: { model.refreshCadence.displayName },
            set: { value in
                if let cadence = PromptMeterRefreshCadence.from(displayName: value) {
                    model.refreshCadence = cadence
                }
            }
        )
    }

    private var languageSelection: Binding<String> {
        Binding(
            get: { model.language.displayName },
            set: { value in
                if let language = PromptMeterLanguage.from(displayName: value) {
                    model.language = language
                }
            }
        )
    }
}

struct ProvidersSettingsPage: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        VStack(spacing: 12) {
            CodexProviderSettingsCard(model: model)
            ClaudeProviderSettingsCard(model: model)
            GeminiProviderSettingsCard(model: model)
        }
    }
}

struct DisplaySettingsPage: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard(title: L10n.tr(.settingsDisplayMenuBarCard)) {
                SettingPickerRow(
                    title: L10n.tr(.settingsDisplayUsageValueTitle),
                    detail: L10n.tr(.settingsDisplayUsageValueDetail),
                    selection: usageBasisSelection,
                    options: PromptMeterUsageBasis.allCases.map(\.displayName)
                )

                SettingDivider()

                SettingPickerRow(
                    title: L10n.tr(.settingsDisplayResetFormatTitle),
                    detail: L10n.tr(.settingsDisplayResetFormatDetail),
                    selection: resetStyleSelection,
                    options: PromptMeterResetStyle.allCases.map(\.displayName)
                )
            }

            SettingsCard(title: L10n.tr(.settingsDisplayPopoverCard)) {
                SettingInfoRow(title: L10n.tr(.settingsDisplayLayoutTitle), value: L10n.tr(.settingsDisplayLayoutValue))
                SettingDivider()
                SettingInfoRow(title: L10n.tr(.settingsDisplayMenuBarRowTitle), value: L10n.tr(.settingsDisplayMenuBarRowValue))
            }
        }
    }

    private var usageBasisSelection: Binding<String> {
        Binding(
            get: { model.usageBasis.displayName },
            set: { value in
                if let basis = PromptMeterUsageBasis.from(displayName: value) {
                    model.usageBasis = basis
                }
            }
        )
    }

    private var resetStyleSelection: Binding<String> {
        Binding(
            get: { model.resetStyle.displayName },
            set: { value in
                if let style = PromptMeterResetStyle.from(displayName: value) {
                    model.resetStyle = style
                }
            }
        )
    }
}

struct AdvancedSettingsPage: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard(title: L10n.tr(.settingsAdvancedPrivacyCard)) {
                SettingToggleRow(
                    title: L10n.tr(.settingsAdvancedHidePersonalInformationTitle),
                    detail: L10n.tr(.settingsAdvancedHidePersonalInformationDetail),
                    isOn: $model.hidePersonalInformation
                )
            }

            SettingsCard(title: L10n.tr(.settingsAdvancedToolsCard)) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(.settingsAdvancedProviderCLIsTitle)
                            .settingTitle()
                        Text(.settingsAdvancedProviderCLIsDetail)
                            .settingDetail()
                    }

                    Spacer()

                    Button(ProviderIconKind.codex.displayName) {
                        SettingsLinks.openCodexInstallGuide()
                    }
                    .buttonStyle(.bordered)

                    Button(ProviderIconKind.claude.displayName) {
                        SettingsLinks.openClaudeInstallGuide()
                    }
                    .buttonStyle(.bordered)

                    Button(ProviderIconKind.gemini.displayName) {
                        SettingsLinks.openGeminiInstallGuide()
                    }
                    .buttonStyle(.bordered)
                }
            }

            SettingsCard(title: L10n.tr(.settingsAdvancedDiagnosticsCard)) {
                SettingToggleRow(
                    title: L10n.tr(.settingsAdvancedDebugModeTitle),
                    detail: L10n.tr(.settingsAdvancedDebugModeDetail),
                    isOn: $model.debugMode
                )
            }
        }
    }
}

struct CodexProviderSettingsCard: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        CommonProviderSettingsCard(
            title: ProviderIconKind.codex.displayName,
            icon: .codex,
            statusColor: statusColor,
            statusTitle: model.codexSettingsTitle,
            statusDetail: model.codexSettingsDetail,
            isRefreshing: model.isRefreshingProviders,
            scheduleText: scheduleText,
            installAction: installAction,
            loginAction: loginAction,
            debugRows: model.debugMode ? model.codexDebugRows : [],
            refreshAction: model.refreshProviders
        )
    }

    private var installAction: ProviderInstallAction? {
        if case .missingCLI = model.codexState {
            return ProviderInstallAction(
                title: L10n.tr(.providerInstallActionTitle),
                detail: L10n.tr(.providerInstallActionDetailCodex),
                command: model.codexInstallCommand,
                primaryButtonTitle: L10n.tr(.providerInstallGuideButton),
                commandTitle: L10n.tr(.providerInstallCommandTitle),
                primaryAction: SettingsLinks.openCodexInstallGuide,
                copyCommandAction: model.copyCodexInstallCommand
            )
        }
        return nil
    }

    private var scheduleText: String? {
        if case .missingCLI = model.codexState {
            return nil
        }
        return model.providerRefreshScheduleText
    }

    private var loginAction: ProviderCommandAction? {
        if case .needsLogin = model.codexState {
            return ProviderCommandAction(
                title: L10n.tr(.providerLoginCommandTitle),
                command: model.codexLoginCommand,
                copyCommandAction: model.copyCodexLoginCommand
            )
        }
        return nil
    }

    private var statusColor: Color {
        switch model.codexState {
        case .connected:
            return SettingsPalette.accent
        case .checking:
            return SettingsPalette.secondaryText
        case .missingCLI, .needsLogin, .unavailable:
            return SettingsPalette.orange
        }
    }
}

struct ClaudeProviderSettingsCard: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        CommonProviderSettingsCard(
            title: ProviderIconKind.claude.displayName,
            icon: .claude,
            statusColor: statusColor,
            statusTitle: model.claudeSettingsTitle,
            statusDetail: model.claudeSettingsDetail,
            isRefreshing: model.isRefreshingProviders,
            scheduleText: scheduleText,
            installAction: installAction,
            loginAction: loginAction,
            debugRows: model.debugMode ? model.claudeDebugRows : [],
            refreshAction: model.refreshProviders
        )
    }

    private var installAction: ProviderInstallAction? {
        if case .missingCLI = model.claudeState {
            return ProviderInstallAction(
                title: L10n.tr(.providerInstallActionTitle),
                detail: L10n.tr(.providerInstallActionDetailClaude),
                command: model.claudeInstallCommand,
                primaryButtonTitle: L10n.tr(.providerInstallGuideButton),
                commandTitle: L10n.tr(.providerInstallCommandTitle),
                primaryAction: SettingsLinks.openClaudeInstallGuide,
                copyCommandAction: model.copyClaudeInstallCommand
            )
        }

        return nil
    }

    private var scheduleText: String? {
        if case .missingCLI = model.claudeState {
            return nil
        }
        return model.providerRefreshScheduleText
    }

    private var loginAction: ProviderCommandAction? {
        if case .needsLogin = model.claudeState {
            return ProviderCommandAction(
                title: L10n.tr(.providerLoginCommandTitle),
                command: model.claudeLoginCommand,
                copyCommandAction: model.copyClaudeLoginCommand
            )
        }
        return nil
    }

    private var statusColor: Color {
        switch model.claudeState {
        case .connected:
            return SettingsPalette.orange
        case .checking:
            return SettingsPalette.secondaryText
        case .missingCLI, .needsLogin, .unavailable:
            return SettingsPalette.orange.opacity(0.72)
        }
    }
}

struct GeminiProviderSettingsCard: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        CommonProviderSettingsCard(
            title: ProviderIconKind.gemini.displayName,
            icon: .gemini,
            statusColor: statusColor,
            statusTitle: model.geminiSettingsTitle,
            statusDetail: model.geminiSettingsDetail,
            isRefreshing: model.isRefreshingProviders,
            scheduleText: scheduleText,
            installAction: installAction,
            loginAction: loginAction,
            debugRows: model.debugMode ? model.geminiDebugRows : [],
            refreshAction: model.refreshProviders
        )
    }

    private var installAction: ProviderInstallAction? {
        if case .missingCLI = model.geminiState {
            return ProviderInstallAction(
                title: L10n.tr(.providerInstallActionTitle),
                detail: L10n.format(.providerInstallActionDetailGeminiFormat, ProviderIconKind.gemini.loginCommand),
                command: model.geminiInstallCommand,
                primaryButtonTitle: L10n.tr(.providerInstallGuideButton),
                commandTitle: L10n.tr(.providerInstallCommandTitle),
                primaryAction: SettingsLinks.openGeminiInstallGuide,
                copyCommandAction: model.copyGeminiInstallCommand
            )
        }

        return nil
    }

    private var scheduleText: String? {
        if case .missingCLI = model.geminiState {
            return nil
        }
        return model.providerRefreshScheduleText
    }

    private var loginAction: ProviderCommandAction? {
        if case .needsLogin = model.geminiState {
            return ProviderCommandAction(
                title: L10n.tr(.providerLoginCommandTitle),
                command: model.geminiLoginCommand,
                copyCommandAction: model.copyGeminiLoginCommand
            )
        }
        return nil
    }

    private var statusColor: Color {
        switch model.geminiState {
        case .connected:
            return SettingsPalette.accent
        case .checking:
            return SettingsPalette.secondaryText
        case .missingCLI, .needsLogin, .unavailable:
            return SettingsPalette.orange.opacity(0.72)
        }
    }
}

enum SettingsLinks {
    static func openCodexInstallGuide() {
        openInstallGuide(for: .codex)
    }

    static func openClaudeInstallGuide() {
        openInstallGuide(for: .claude)
    }

    static func openGeminiInstallGuide() {
        openInstallGuide(for: .gemini)
    }

    static func openGitHub() {
        guard let url = URL(string: "https://github.com/minhee0000/PromptMeter") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func openInstallGuide(for provider: ProviderIconKind) {
        NSWorkspace.shared.open(provider.installGuideURL)
    }
}

struct AboutSettingsPage: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 8)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                SettingsPalette.accent,
                                Color(red: 0.08, green: 0.36, blue: 0.80)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 76, height: 76)

            VStack(spacing: 4) {
                Text(verbatim: "PromptMeter")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SettingsPalette.primaryText)
                Text(verbatim: L10n.format(.settingsAboutVersionLabelFormat, "0.1.0"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SettingsPalette.secondaryText)
                Text(.settingsAboutTagline)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SettingsPalette.mutedText)
            }

            HStack(spacing: 10) {
                AboutLinkButton(icon: "chevron.left.forwardslash.chevron.right", title: L10n.tr(.settingsAboutGitHubButton)) {
                    SettingsLinks.openGitHub()
                }
                AboutLinkButton(icon: "globe", title: ProviderIconKind.codex.displayName) {
                    SettingsLinks.openCodexInstallGuide()
                }
                AboutLinkButton(icon: "terminal", title: ProviderIconKind.claude.displayName) {
                    SettingsLinks.openClaudeInstallGuide()
                }
                AboutLinkButton(icon: "sparkle", title: ProviderIconKind.gemini.displayName) {
                    SettingsLinks.openGeminiInstallGuide()
                }
            }

            Spacer()

            Text(verbatim: L10n.format(.settingsAboutCopyrightFormat, "2026"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SettingsPalette.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
}
