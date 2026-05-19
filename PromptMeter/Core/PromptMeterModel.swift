import AppKit
import Combine
import Foundation

@MainActor
final class PromptMeterModel: ObservableObject {
    static let contextOptions = [4_000, 8_000, 16_000, 32_000, 128_000]

    @Published var prompt: String {
        didSet {
            defaults.set(prompt, forKey: Self.promptKey)
            refreshMetrics()
        }
    }

    @Published var contextLimit: Int {
        didSet {
            defaults.set(contextLimit, forKey: Self.contextLimitKey)
            refreshMetrics()
        }
    }

    @Published private(set) var metrics: PromptMetrics
    @Published private(set) var codexState: CodexProviderState = .checking
    @Published private(set) var claudeState: ClaudeCodeProviderState = .checking
    @Published private(set) var geminiState: GeminiProviderState = .checking
    @Published private(set) var todayTokenUsages: [ProviderIconKind: LocalTokenUsageSnapshot] = [:]
    @Published private(set) var isRefreshingProviders = false
    @Published private(set) var lastProviderRefresh: Date?
    @Published private(set) var nextProviderRefresh: Date?

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Self.launchAtLoginKey)
            try? LaunchAtLoginController.setEnabled(launchAtLogin)
        }
    }

    @Published var refreshCadence: PromptMeterRefreshCadence {
        didSet {
            defaults.set(refreshCadence.rawValue, forKey: Self.refreshCadenceKey)
            configureRefreshTimer()
        }
    }

    @Published var usageBasis: PromptMeterUsageBasis {
        didSet {
            defaults.set(usageBasis.rawValue, forKey: Self.usageBasisKey)
        }
    }

    @Published var resetStyle: PromptMeterResetStyle {
        didSet {
            defaults.set(resetStyle.rawValue, forKey: Self.resetStyleKey)
        }
    }

    @Published var hidePersonalInformation: Bool {
        didSet {
            defaults.set(hidePersonalInformation, forKey: Self.hidePersonalInformationKey)
        }
    }

    @Published var debugMode: Bool {
        didSet {
            defaults.set(debugMode, forKey: Self.debugModeKey)
        }
    }

    var language: PromptMeterLanguage {
        get { LocalizationManager.shared.language }
        set {
            guard LocalizationManager.shared.language != newValue else { return }
            objectWillChange.send()
            LocalizationManager.shared.setLanguage(newValue)
        }
    }

    private static let promptKey = "PromptMeter.prompt"
    private static let contextLimitKey = "PromptMeter.contextLimit"
    private static let launchAtLoginKey = "PromptMeter.launchAtLogin"
    private static let refreshCadenceKey = "PromptMeter.refreshCadence"
    private static let usageBasisKey = "PromptMeter.usageBasis"
    private static let resetStyleKey = "PromptMeter.resetStyle"
    private static let hidePersonalInformationKey = "PromptMeter.hidePersonalInformation"
    private static let debugModeKey = "PromptMeter.debugMode"
    private let defaults: UserDefaults
    private let codexClient: CodexProviderClient
    private let claudeClient: ClaudeCodeProviderClient
    private let geminiClient: GeminiProviderClient
    private var refreshTimer: AnyCancellable?
    private var providerRefreshTask: Task<Void, Never>?
    private var deliveredQuotaWarnings = Set<QuotaNotificationKey>()
    private var claudeOAuthCooldownUntil: Date?
    private static let claudeOAuthRateLimitCooldown: TimeInterval = 5 * 60

    init(
        defaults: UserDefaults = .standard,
        codexClient: CodexProviderClient = CodexProviderClient(),
        claudeClient: ClaudeCodeProviderClient = ClaudeCodeProviderClient(),
        geminiClient: GeminiProviderClient = GeminiProviderClient(),
        autoRefreshProviders: Bool = true
    ) {
        self.defaults = defaults
        self.codexClient = codexClient
        self.claudeClient = claudeClient
        self.geminiClient = geminiClient

        let storedPrompt = defaults.string(forKey: Self.promptKey) ?? ""
        let storedLimit = defaults.integer(forKey: Self.contextLimitKey)
        let contextLimit = storedLimit > 0 ? storedLimit : 32_000
        let launchPreference = defaults.object(forKey: Self.launchAtLoginKey) as? Bool
        let storedRefreshCadence = defaults.string(forKey: Self.refreshCadenceKey)
        let storedUsageBasis = defaults.string(forKey: Self.usageBasisKey)
        let storedResetStyle = defaults.string(forKey: Self.resetStyleKey)

        prompt = storedPrompt
        self.contextLimit = contextLimit
        metrics = PromptMetrics(text: storedPrompt, contextLimit: contextLimit)
        launchAtLogin = launchPreference ?? LaunchAtLoginController.isEnabled
        refreshCadence = PromptMeterRefreshCadence(rawValue: storedRefreshCadence ?? "") ?? .oneMinute
        usageBasis = PromptMeterUsageBasis(rawValue: storedUsageBasis ?? "") ?? .remaining
        resetStyle = PromptMeterResetStyle(rawValue: storedResetStyle ?? "") ?? .clock
        hidePersonalInformation = defaults.bool(forKey: Self.hidePersonalInformationKey)
        debugMode = defaults.bool(forKey: Self.debugModeKey)

        if autoRefreshProviders {
            configureRefreshTimer()
            Task { [weak self] in
                self?.refreshProviders(allowClaudeKeychainPrompt: false)
            }
        }
    }

    deinit {
        refreshTimer?.cancel()
        providerRefreshTask?.cancel()
    }

    var menuBarTitle: String {
        guard metrics.estimatedTokens > 0 else { return "PromptMeter" }
        return "PM \(PromptMetrics.compactCount(metrics.estimatedTokens))"
    }

    var usagePercentText: String {
        "\(Int((metrics.usageRatio * 100).rounded()))%"
    }

    var menuBarSessionStatuses: [MenuBarSessionStatus] {
        lowestSessionRemainingStatuses(limit: 2)
    }

    var providerUsages: [MenuProviderUsage] {
        ProviderUsageMapper.menuProviders(
            codex: codexState,
            claude: claudeState,
            gemini: geminiState,
            usageBasis: usageBasis,
            resetStyle: resetStyle
        )
    }

    var providerRefreshLabel: String {
        if isRefreshingProviders {
            return L10n.tr(.statusSyncing)
        }

        if isProviderChecking {
            return L10n.tr(.statusChecking)
        }
        if hasConnectedProvider {
            return L10n.tr(.statusNow)
        }
        if needsProviderLogin {
            return L10n.tr(.statusLogin)
        }
        if hasMissingProviderCLI {
            return L10n.tr(.statusSetup)
        }

        return L10n.tr(.statusOffline)
    }

    private var isProviderChecking: Bool {
        if case .checking = codexState { return true }
        if case .checking = claudeState { return true }
        if case .checking = geminiState { return true }
        return false
    }

    private var hasConnectedProvider: Bool {
        if case .connected = codexState { return true }
        if case .connected = claudeState { return true }
        if case .connected = geminiState { return true }
        return false
    }

    private var needsProviderLogin: Bool {
        if case .needsLogin = codexState { return true }
        if case .needsLogin = claudeState { return true }
        if case .needsLogin = geminiState { return true }
        return false
    }

    private var hasMissingProviderCLI: Bool {
        if case .missingCLI = codexState { return true }
        if case .missingCLI = claudeState { return true }
        if case .missingCLI = geminiState { return true }
        return false
    }

    var claudeSettingsTitle: String {
        let providerName = ProviderIconKind.claude.displayName

        switch claudeState {
        case .checking:
            return L10n.format(.providerCheckingTitleFormat, providerName)
        case .connected(let snapshot):
            return L10n.format(.providerConnectedTitleFormat, snapshot.subscriptionName)
        case .missingCLI:
            return L10n.format(.providerMissingCLITitleFormat, providerName)
        case .needsLogin:
            return L10n.format(.providerNeedsLoginTitleFormat, providerName)
        case .unavailable:
            return L10n.format(.providerUnavailableTitleFormat, providerName)
        }
    }

    var claudeSettingsDetail: String {
        switch claudeState {
        case .checking:
            return L10n.tr(.providerCheckingDetailClaude)
        case .connected(let snapshot):
            if let email = snapshot.accountEmail, !email.isEmpty, !hidePersonalInformation {
                return L10n.format(.providerClaudeConnectedDetailWithEmailFormat, email)
            }
            return L10n.tr(.providerClaudeConnectedDetailNoEmail)
        case .missingCLI:
            return L10n.tr(.providerMissingCLIDetailClaude)
        case .needsLogin:
            return L10n.format(.providerNeedsLoginDetailGenericFormat, ProviderIconKind.claude.loginCommand)
        case .unavailable(let message):
            return message
        }
    }

    var providerRefreshScheduleText: String {
        guard let lastProviderRefresh else {
            return L10n.tr(.refreshScheduleNotRefreshedYet)
        }

        if let nextProviderRefresh {
            return L10n.format(
                .refreshScheduleLastAndNextFormat,
                Self.shortTimeFormatter.string(from: lastProviderRefresh),
                Self.shortTimeFormatter.string(from: nextProviderRefresh)
            )
        }

        return L10n.format(
            .refreshScheduleLastOnlyFormat,
            Self.shortTimeFormatter.string(from: lastProviderRefresh)
        )
    }

    var codexSettingsTitle: String {
        let providerName = ProviderIconKind.codex.displayName

        switch codexState {
        case .checking:
            return L10n.format(.providerCheckingCLITitleFormat, providerName)
        case .connected(let snapshot):
            return L10n.format(.providerConnectedTitleFormat, snapshot.planName)
        case .missingCLI:
            return L10n.format(.providerMissingCLITitleFormat, providerName)
        case .needsLogin:
            return L10n.format(.providerNeedsLoginTitleFormat, providerName)
        case .unavailable:
            return L10n.format(.providerUnavailableTitleFormat, providerName)
        }
    }

    var codexSettingsDetail: String {
        switch codexState {
        case .checking:
            return L10n.tr(.providerCheckingDetailCodex)
        case .connected(let snapshot):
            if let email = snapshot.accountEmail, !email.isEmpty, !hidePersonalInformation {
                return L10n.format(.providerCodexConnectedDetailWithEmailFormat, email)
            }
            return L10n.tr(.providerCodexConnectedDetailNoEmail)
        case .missingCLI:
            return L10n.tr(.providerMissingCLIDetailCodex)
        case .needsLogin:
            return L10n.format(.providerNeedsLoginDetailGenericFormat, ProviderIconKind.codex.loginCommand)
        case .unavailable(let message):
            return message
        }
    }

    var geminiSettingsTitle: String {
        let providerName = ProviderIconKind.gemini.displayName

        switch geminiState {
        case .checking:
            return L10n.format(.providerCheckingTitleFormat, providerName)
        case .connected(let snapshot):
            return L10n.format(.providerConnectedTitleFormat, snapshot.planName)
        case .missingCLI:
            return L10n.format(.providerMissingTitleFormat, providerName)
        case .needsLogin:
            return L10n.format(.providerNeedsLoginTitleFormat, providerName)
        case .unavailable:
            return L10n.format(.providerUnavailableTitleFormat, providerName)
        }
    }

    var geminiSettingsDetail: String {
        switch geminiState {
        case .checking:
            return L10n.tr(.providerCheckingDetailGemini)
        case .connected(let snapshot):
            return L10n.format(.providerGeminiConnectedDetailFormat, snapshot.usageSource)
        case .missingCLI:
            return L10n.tr(.providerMissingCLIDetailGemini)
        case .needsLogin:
            return L10n.tr(.providerNeedsLoginDetailGemini)
        case .unavailable(let message):
            return message
        }
    }

    var codexLoginCommand: String {
        ProviderIconKind.codex.loginCommand
    }

    var codexInstallCommand: String {
        ProviderIconKind.codex.installCommand
    }

    var claudeLoginCommand: String {
        ProviderIconKind.claude.loginCommand
    }

    var claudeInstallCommand: String {
        ProviderIconKind.claude.installCommand
    }

    var geminiLoginCommand: String {
        ProviderIconKind.gemini.loginCommand
    }

    var geminiInstallCommand: String {
        ProviderIconKind.gemini.installCommand
    }

    var codexDebugRows: [SettingsInfoRowData] {
        guard case .connected(let snapshot) = codexState else {
            return []
        }

        let dash = L10n.tr(.commonDash)
        return [
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugCLI), value: snapshot.cliPath),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugRawPlan), value: snapshot.rawPlanName ?? dash),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugLimit), value: snapshot.limitId ?? dash)
        ]
    }

    var claudeDebugRows: [SettingsInfoRowData] {
        guard case .connected(let snapshot) = claudeState else {
            return []
        }

        let dash = L10n.tr(.commonDash)
        return [
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugCLI), value: snapshot.cliPath),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugVersion), value: snapshot.version ?? dash),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugRawPlan), value: snapshot.rawSubscriptionName ?? dash),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugAuth), value: snapshot.authMethod ?? dash),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugProvider), value: snapshot.apiProvider ?? dash),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugUsageSource), value: snapshot.usageSource),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugCredential), value: snapshot.oauthCredentialSource),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugRateTier), value: snapshot.oauthRateLimitTier ?? dash),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugTokenExpiry), value: tokenExpiryText(snapshot.oauthExpiresAt))
        ]
    }

    var geminiDebugRows: [SettingsInfoRowData] {
        guard case .connected(let snapshot) = geminiState else {
            return []
        }

        let dash = L10n.tr(.commonDash)
        return [
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugCLI), value: snapshot.cliPath),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugVersion), value: snapshot.version ?? dash),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugRawPlan), value: snapshot.rawPlanName ?? dash),
            SettingsInfoRowData(title: L10n.tr(.settingsProvidersDebugUsageSource), value: snapshot.usageSource)
        ]
    }

    func clear() {
        prompt = ""
    }

    func copySummary() {
        let summary = """
        PromptMeter
        Estimated tokens: \(metrics.estimatedTokens)
        Context limit: \(metrics.contextLimit)
        Remaining tokens: \(metrics.remainingTokens)
        Characters: \(metrics.characterCount)
        Words: \(metrics.wordCount)
        Lines: \(metrics.lineCount)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    func refreshProviders() {
        refreshProviders(allowClaudeKeychainPrompt: true)
    }

    func refreshProviders(allowClaudeKeychainPrompt: Bool) {
        guard providerRefreshTask == nil, !isRefreshingProviders else { return }

        let shouldShowPlaceholders = lastProviderRefresh == nil
        isRefreshingProviders = true

        if shouldShowPlaceholders {
            codexState = .checking
            claudeState = .checking
            geminiState = .checking
        }

        let codexClient = codexClient
        let claudeClient = claudeClient
        let geminiClient = geminiClient
        let previousClaudeState = claudeState
        let skipsClaudeRefresh = claudeOAuthCooldownUntil.map { Date() < $0 } ?? false
        providerRefreshTask = Task { [weak self] in
            let states = await Task.detached(priority: .utility) {
                let codexState = codexClient.fetchState()
                let claudeState = skipsClaudeRefresh
                    ? previousClaudeState
                    : await claudeClient.fetchState(
                        allowClaudeKeychainPrompt: allowClaudeKeychainPrompt
                    )
                let geminiState = geminiClient.fetchState()
                let todayTokenUsages = LocalTokenUsageScanner.todayUsage(
                    includeCodex: !Self.isMissingCLI(codexState),
                    includeClaude: !Self.isMissingCLI(claudeState)
                )
                return (
                    codex: codexState,
                    claude: claudeState,
                    gemini: geminiState,
                    todayTokenUsages: todayTokenUsages,
                    skippedClaudeRefresh: skipsClaudeRefresh
                )
            }.value

            guard let self else { return }
            guard !Task.isCancelled else {
                finishProviderRefresh()
                return
            }

            applyProviderStates(
                codex: states.codex,
                claude: states.claude,
                gemini: states.gemini,
                todayTokenUsages: states.todayTokenUsages,
                skippedClaudeRefresh: states.skippedClaudeRefresh
            )
        }
    }

    func copyCodexLoginCommand() {
        copyToPasteboard(codexLoginCommand)
    }

    func copyCodexInstallCommand() {
        copyToPasteboard(codexInstallCommand)
    }

    func copyClaudeLoginCommand() {
        copyToPasteboard(claudeLoginCommand)
    }

    func copyClaudeInstallCommand() {
        copyToPasteboard(claudeInstallCommand)
    }

    func copyGeminiLoginCommand() {
        copyToPasteboard(geminiLoginCommand)
    }

    func copyGeminiInstallCommand() {
        copyToPasteboard(geminiInstallCommand)
    }

    private func refreshMetrics() {
        metrics = PromptMetrics(text: prompt, contextLimit: contextLimit)
    }

    private func applyProviderStates(
        codex: CodexProviderState,
        claude: ClaudeCodeProviderState,
        gemini: GeminiProviderState,
        todayTokenUsages: [ProviderIconKind: LocalTokenUsageSnapshot],
        skippedClaudeRefresh: Bool
    ) {
        let resolvedClaude = resolvedClaudeState(claude)
        codexState = codex
        claudeState = resolvedClaude
        geminiState = gemini
        if !skippedClaudeRefresh {
            updateClaudeOAuthCooldown(for: claude)
        }
        self.todayTokenUsages = todayTokenUsages
        notifyIfNeededForProviderQuota(codex: codex, claude: resolvedClaude, gemini: gemini)
        lastProviderRefresh = Date()
        nextProviderRefresh = Date().addingTimeInterval(refreshCadence.interval)
        finishProviderRefresh()
    }

    private func notifyIfNeededForProviderQuota(
        codex: CodexProviderState,
        claude: ClaudeCodeProviderState,
        gemini: GeminiProviderState
    ) {
        let warnings = quotaWarnings(for: codex) + quotaWarnings(for: claude) + quotaWarnings(for: gemini)
        PromptMeterQuotaNotifier.postLowQuota(warnings)
    }

    private func quotaWarnings(for state: CodexProviderState) -> [QuotaWarning] {
        guard case .connected(let snapshot) = state else { return [] }

        return quotaWarnings(
            provider: .codex,
            windows: [
                quotaWindow(.session, remainingPercent: snapshot.primary?.remainingPercent),
                quotaWindow(.weekly, remainingPercent: snapshot.secondary?.remainingPercent)
            ]
        )
    }

    private func quotaWarnings(for state: ClaudeCodeProviderState) -> [QuotaWarning] {
        guard case .connected(let snapshot) = state else { return [] }

        let extraWindows = snapshot.extraWindows.map {
            (id: $0.id, title: $0.title, remainingPercent: Optional($0.window.remainingPercent))
        }

        return quotaWarnings(
            provider: .claude,
            windows: [
                quotaWindow(.session, remainingPercent: snapshot.session?.remainingPercent),
                quotaWindow(.weekly, remainingPercent: snapshot.weekly?.remainingPercent)
            ] + extraWindows
        )
    }

    private func quotaWarnings(for state: GeminiProviderState) -> [QuotaWarning] {
        guard case .connected(let snapshot) = state else { return [] }

        let extraWindows = snapshot.extraWindows.map {
            (id: $0.id, title: $0.title, remainingPercent: Optional($0.window.remainingPercent))
        }

        return quotaWarnings(
            provider: .gemini,
            windows: [
                (id: "primary", title: snapshot.primaryTitle, remainingPercent: snapshot.primary?.remainingPercent),
                (id: "secondary", title: snapshot.secondaryTitle, remainingPercent: snapshot.secondary?.remainingPercent)
            ] + extraWindows
        )
    }

    private func quotaWarnings(
        provider: ProviderIconKind,
        windows: [(id: String, title: String, remainingPercent: Double?)]
    ) -> [QuotaWarning] {
        var activeKeys = Set<QuotaNotificationKey>()

        let warnings = windows.compactMap { window in
            let key = QuotaNotificationKey(providerID: provider.providerID, windowID: window.id)
            activeKeys.insert(key)
            return quotaWarning(
                key: key,
                providerName: provider.displayName,
                windowTitle: window.title,
                remainingPercent: window.remainingPercent
            )
        }

        deliveredQuotaWarnings = Set(deliveredQuotaWarnings.filter {
            $0.providerID != provider.providerID || activeKeys.contains($0)
        })

        return warnings
    }

    private func quotaWindow(
        _ kind: ProviderQuotaWindowKind,
        remainingPercent: Double?
    ) -> (id: String, title: String, remainingPercent: Double?) {
        (id: kind.id, title: kind.localizedTitle, remainingPercent: remainingPercent)
    }

    private func quotaWarning(
        key: QuotaNotificationKey,
        providerName: String,
        windowTitle: String,
        remainingPercent: Double?
    ) -> QuotaWarning? {
        guard let remainingPercent else {
            deliveredQuotaWarnings.remove(key)
            return nil
        }

        guard remainingPercent <= PromptMeterQuotaPolicy.notificationRemainingThreshold else {
            deliveredQuotaWarnings.remove(key)
            return nil
        }

        guard deliveredQuotaWarnings.insert(key).inserted else {
            return nil
        }

        return QuotaWarning(
            key: key,
            providerName: providerName,
            windowTitle: windowTitle,
            remainingPercent: remainingPercent
        )
    }

    private func resolvedClaudeState(_ newState: ClaudeCodeProviderState) -> ClaudeCodeProviderState {
        guard case .connected = claudeState,
              case .unavailable(let message) = newState,
              Self.isTransientClaudeFailure(message) else {
            return newState
        }

        return claudeState
    }

    private func updateClaudeOAuthCooldown(for state: ClaudeCodeProviderState) {
        if case .unavailable(let message) = state,
           Self.isClaudeOAuthRateLimited(message) {
            claudeOAuthCooldownUntil = Date().addingTimeInterval(Self.claudeOAuthRateLimitCooldown)
            return
        }

        if case .connected = state {
            claudeOAuthCooldownUntil = nil
        }
    }

    private static func isTransientClaudeFailure(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("did not respond")
            || normalized.contains("request failed")
            || normalized.contains("timed out")
            || normalized.contains("network")
            || normalized.contains("offline")
            || isClaudeOAuthRateLimited(message)
    }

    private static func isClaudeOAuthRateLimited(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("http 429")
            || normalized.contains("rate limited")
            || normalized.contains("too many requests")
    }

    nonisolated private static func isMissingCLI(_ state: CodexProviderState) -> Bool {
        if case .missingCLI = state { return true }
        return false
    }

    nonisolated private static func isMissingCLI(_ state: ClaudeCodeProviderState) -> Bool {
        if case .missingCLI = state { return true }
        return false
    }

    private func finishProviderRefresh() {
        providerRefreshTask = nil
        isRefreshingProviders = false
    }

    private func configureRefreshTimer() {
        refreshTimer?.cancel()
        nextProviderRefresh = Date().addingTimeInterval(refreshCadence.interval)

        refreshTimer = Timer
            .publish(every: refreshCadence.interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshProviders(allowClaudeKeychainPrompt: false)
            }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func tokenExpiryText(_ date: Date?) -> String {
        guard let date else { return L10n.tr(.commonDash) }

        let seconds = max(0, Int(date.timeIntervalSinceNow))
        if seconds < 60 {
            return L10n.tr(.tokenExpiryNow)
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return L10n.format(.unitMinuteShortFormat, minutes)
        }

        let hours = minutes / 60
        if hours < 24 {
            return L10n.format(.unitHourShortFormat, hours)
        }

        return L10n.format(.unitDayShortFormat, hours / 24)
    }

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct SettingsInfoRowData: Identifiable {
    var id: String { title }
    let title: String
    let value: String
}

struct MenuBarSessionStatus {
    let remainingPercent: Double
    let icon: ProviderIconKind
    let providerName: String

    var percentText: String {
        "\(Int(remainingPercent.rounded()))%"
    }
}
