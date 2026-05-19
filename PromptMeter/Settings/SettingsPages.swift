import AppKit
import SwiftUI

struct GeneralSettingsPage: View {
    @ObservedObject var model: PromptMeterModel

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard(title: "App") {
                SettingToggleRow(
                    title: "Start at login",
                    detail: "Open PromptMeter quietly in the menu bar.",
                    isOn: $model.launchAtLogin
                )

                SettingDivider()

                SettingPickerRow(
                    title: "Refresh cadence",
                    detail: "Background provider usage refresh interval.",
                    selection: refreshCadenceSelection,
                    options: PromptMeterRefreshCadence.allCases.map(\.rawValue)
                )
            }

            SettingsCard(title: "Refresh") {
                SettingInfoRow(title: "Schedule", value: model.providerRefreshScheduleText)

                SettingDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Refresh now")
                            .settingTitle()
                        Text("Pull the latest provider quota from local CLIs.")
                            .settingDetail()
                    }

                    Spacer()

                    Button(model.isRefreshingProviders ? "Refreshing" : "Refresh") {
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
            get: { model.refreshCadence.rawValue },
            set: { value in
                if let cadence = PromptMeterRefreshCadence(rawValue: value) {
                    model.refreshCadence = cadence
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
            SettingsCard(title: "Menu Bar") {
                SettingPickerRow(
                    title: "Usage value",
                    detail: "Choose whether bars show remaining quota or consumed quota.",
                    selection: usageBasisSelection,
                    options: PromptMeterUsageBasis.allCases.map(\.rawValue)
                )

                SettingDivider()

                SettingPickerRow(
                    title: "Reset format",
                    detail: "Show reset as a clean clock value or a countdown.",
                    selection: resetStyleSelection,
                    options: PromptMeterResetStyle.allCases.map(\.rawValue)
                )
            }

            SettingsCard(title: "Popover") {
                SettingInfoRow(title: "Layout", value: "Aligned compact rows")
                SettingDivider()
                SettingInfoRow(title: "Menu bar", value: "Icon only")
            }
        }
    }

    private var usageBasisSelection: Binding<String> {
        Binding(
            get: { model.usageBasis.rawValue },
            set: { value in
                if let basis = PromptMeterUsageBasis(rawValue: value) {
                    model.usageBasis = basis
                }
            }
        )
    }

    private var resetStyleSelection: Binding<String> {
        Binding(
            get: { model.resetStyle.rawValue },
            set: { value in
                if let style = PromptMeterResetStyle(rawValue: value) {
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
            SettingsCard(title: "Privacy") {
                SettingToggleRow(
                    title: "Hide personal information",
                    detail: "Obscure account emails in settings.",
                    isOn: $model.hidePersonalInformation
                )
            }

            SettingsCard(title: "Tools") {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Provider CLIs")
                            .settingTitle()
                        Text("PromptMeter reads usage through local provider CLIs.")
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

            SettingsCard(title: "Diagnostics") {
                SettingToggleRow(
                    title: "Debug mode",
                    detail: "Expose provider CLI paths, raw plans, and limit identifiers.",
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
                title: "Local CLI required",
                detail: "Install \(ProviderIconKind.codex.displayName) CLI with npm or Homebrew, then run \(ProviderIconKind.codex.loginCommand).",
                command: model.codexInstallCommand,
                primaryButtonTitle: "Guide",
                commandTitle: "Install command",
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
                title: "Login command",
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
                title: "Local CLI required",
                detail: "Install \(ProviderIconKind.claude.displayName), then sign in with your Claude account.",
                command: model.claudeInstallCommand,
                primaryButtonTitle: "Guide",
                commandTitle: "Install command",
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
                title: "Login command",
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
                title: "Local CLI required",
                detail: "Install \(ProviderIconKind.gemini.displayName), then run \(ProviderIconKind.gemini.loginCommand) to sign in.",
                command: model.geminiInstallCommand,
                primaryButtonTitle: "Guide",
                commandTitle: "Install command",
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
                title: "Login command",
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
                Text("PromptMeter")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SettingsPalette.primaryText)
                Text("Version 0.1.0")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SettingsPalette.secondaryText)
                Text("A quiet menu bar meter for prompt usage.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SettingsPalette.mutedText)
            }

            HStack(spacing: 10) {
                AboutLinkButton(icon: "chevron.left.forwardslash.chevron.right", title: "GitHub") {
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

            Text("© 2026 PromptMeter")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SettingsPalette.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
}
