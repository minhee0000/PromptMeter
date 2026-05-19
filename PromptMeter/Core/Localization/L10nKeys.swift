import Foundation

enum L10nKey: String, CaseIterable, Sendable {
    // Menu - popover today usage
    case menuTodayUsage
    case menuTodayUsageEmptyTitle
    case menuTodayUsageEmptySubtitle
    case menuTodayUsageIn
    case menuTodayUsageOut
    case menuTodayUsageCache
    case menuTodayUsageEstimated
    case menuTodayUsageTokensFormat

    // Menu - footer
    case menuFooterRefresh
    case menuFooterRefreshing
    case menuFooterSettings
    case menuFooterAbout
    case menuFooterQuit

    // Refresh status capsule
    case statusSyncing
    case statusChecking
    case statusNow
    case statusLogin
    case statusSetup
    case statusOffline

    // Provider status titles
    case providerCheckingTitleFormat
    case providerCheckingCLITitleFormat
    case providerConnectedTitleFormat
    case providerMissingCLITitleFormat
    case providerMissingTitleFormat
    case providerNeedsLoginTitleFormat
    case providerUnavailableTitleFormat

    // Provider status details
    case providerCheckingDetailCodex
    case providerCheckingDetailClaude
    case providerCheckingDetailGemini

    case providerCodexConnectedDetailWithEmailFormat
    case providerCodexConnectedDetailNoEmail
    case providerClaudeConnectedDetailWithEmailFormat
    case providerClaudeConnectedDetailNoEmail
    case providerGeminiConnectedDetailFormat

    case providerMissingCLIDetailCodex
    case providerMissingCLIDetailClaude
    case providerMissingCLIDetailGemini

    case providerNeedsLoginDetailGenericFormat
    case providerNeedsLoginDetailGemini

    // Provider card placeholders
    case providerLoginRequiredPlan
    case providerUnavailablePlan
    case providerLoginRequiredCardDetailFormat
    case providerLoginRequiredCardDetailGeminiFormat

    case providerClaudeNoRateLimits
    case providerGeminiNoQuotaPercentages

    case providerInstallActionTitle
    case providerInstallActionDetailCodex
    case providerInstallActionDetailClaude
    case providerInstallActionDetailGeminiFormat
    case providerInstallCommandTitle
    case providerInstallGuideButton
    case providerLoginCommandTitle
    case providerCopyButton

    // Quota windows
    case quotaWindowSession
    case quotaWindowWeekly

    // Provider extra windows (Claude OAuth + Gemini stats categories)
    case extraWindowSonnet
    case extraWindowOpus
    case extraWindowHaiku
    case extraWindowDesigns
    case extraWindowRoutines
    case extraWindowPro
    case extraWindowFlash
    case extraWindowDaily
    case extraWindowQuota
    case extraWindowQuotaIndexedFormat

    // Notifications
    case notificationQuotaLowSingleTitleFormat
    case notificationQuotaLowSingleBodyFormat
    case notificationQuotaLowMultiTitleProviderFormat
    case notificationQuotaLowMultiTitleGeneric
    case notificationQuotaLowMultiBodyFormat
    case notificationQuotaLowSummaryWithProviderFormat
    case notificationQuotaLowSummaryNoProviderFormat

    // Settings tabs
    case settingsTabsGeneral
    case settingsTabsProviders
    case settingsTabsDisplay
    case settingsTabsAdvanced
    case settingsTabsAbout

    // Settings header
    case settingsHeaderSubtitle

    // Settings - General
    case settingsGeneralAppCard
    case settingsGeneralStartAtLoginTitle
    case settingsGeneralStartAtLoginDetail
    case settingsGeneralRefreshCadenceTitle
    case settingsGeneralRefreshCadenceDetail
    case settingsGeneralLanguageTitle
    case settingsGeneralLanguageDetail
    case settingsGeneralRefreshCard
    case settingsGeneralRefreshScheduleTitle
    case settingsGeneralRefreshNowTitle
    case settingsGeneralRefreshNowDetail
    case settingsGeneralRefreshNowButton
    case settingsGeneralRefreshingButton

    // Settings - Display
    case settingsDisplayMenuBarCard
    case settingsDisplayUsageValueTitle
    case settingsDisplayUsageValueDetail
    case settingsDisplayResetFormatTitle
    case settingsDisplayResetFormatDetail
    case settingsDisplayPopoverCard
    case settingsDisplayLayoutTitle
    case settingsDisplayLayoutValue
    case settingsDisplayMenuBarRowTitle
    case settingsDisplayMenuBarRowValue

    // Settings - Advanced
    case settingsAdvancedPrivacyCard
    case settingsAdvancedHidePersonalInformationTitle
    case settingsAdvancedHidePersonalInformationDetail
    case settingsAdvancedToolsCard
    case settingsAdvancedProviderCLIsTitle
    case settingsAdvancedProviderCLIsDetail
    case settingsAdvancedDiagnosticsCard
    case settingsAdvancedDebugModeTitle
    case settingsAdvancedDebugModeDetail

    // Settings - Providers debug rows
    case settingsProvidersDebugCLI
    case settingsProvidersDebugVersion
    case settingsProvidersDebugRawPlan
    case settingsProvidersDebugLimit
    case settingsProvidersDebugAuth
    case settingsProvidersDebugProvider
    case settingsProvidersDebugUsageSource
    case settingsProvidersDebugCredential
    case settingsProvidersDebugRateTier
    case settingsProvidersDebugTokenExpiry

    // Settings - About
    case settingsAboutVersionLabelFormat
    case settingsAboutTagline
    case settingsAboutCopyrightFormat
    case settingsAboutGitHubButton

    // Cadence display
    case cadenceThirtySeconds
    case cadenceOneMinute
    case cadenceFiveMinutes
    case cadenceFifteenMinutes

    // Usage basis / Reset style
    case usageBasisRemaining
    case usageBasisUsed
    case resetStyleClock
    case resetStyleCountdown

    // Language picker
    case languageSystemFormat
    case languageEnglish
    case languageKorean
    case languageJapanese
    case languageSimplifiedChinese

    // Time / units
    case timeNow
    case timeTodayFormat
    case unitMinuteShortFormat
    case unitHourShortFormat
    case unitDayShortFormat
    case unitDayHourShortFormat
    case unitHourMinuteShortFormat

    // Status item tooltip
    case tooltipBaseEstimatedTokensFormat
    case tooltipBaseWithUsageFormat
    case tooltipUsageProviderSessionLeftFormat

    // Provider refresh schedule
    case refreshScheduleNotRefreshedYet
    case refreshScheduleLastOnlyFormat
    case refreshScheduleLastAndNextFormat

    // Token expiry
    case tokenExpiryNow

    // Common
    case commonDash
    case commonPercentFormat
}
