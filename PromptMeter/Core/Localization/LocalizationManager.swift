import Combine
import Foundation

enum PromptMeterLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case korean = "ko"
    case japanese = "ja"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.current.identifier
        case .english:
            return "en"
        case .korean:
            return "ko"
        case .japanese:
            return "ja"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }

    var nativeDisplayName: String {
        switch self {
        case .system:
            let resolved = PromptMeterLanguage.fromSystem()
            let resolvedName = resolved.nativeDisplayName
            return String(
                format: L10nTables.template(for: .languageSystemFormat, language: resolved),
                arguments: [resolvedName]
            )
        case .english:
            return "English"
        case .korean:
            return "한국어"
        case .japanese:
            return "日本語"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    static func fromSystem() -> PromptMeterLanguage {
        guard let preferred = Locale.preferredLanguages.first else { return .english }
        let normalized = preferred.lowercased()
        if normalized.hasPrefix("ko") { return .korean }
        if normalized.hasPrefix("ja") { return .japanese }
        if normalized.hasPrefix("zh") { return .simplifiedChinese }
        return .english
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published private(set) var language: PromptMeterLanguage

    private static let languageKey = "PromptMeter.language"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.languageKey)
        self.language = PromptMeterLanguage(rawValue: stored ?? "") ?? .system
    }

    func setLanguage(_ language: PromptMeterLanguage) {
        guard self.language != language else { return }
        self.language = language
        defaults.set(language.rawValue, forKey: Self.languageKey)
    }

    var resolvedLanguage: PromptMeterLanguage {
        language == .system ? PromptMeterLanguage.fromSystem() : language
    }

    var resolvedLocale: Locale {
        Locale(identifier: resolvedLanguage.localeIdentifier)
    }
}

@MainActor
enum L10n {
    static func tr(_ key: L10nKey) -> String {
        L10nTables.template(for: key, language: LocalizationManager.shared.resolvedLanguage)
    }

    static func format(_ key: L10nKey, _ args: any CVarArg...) -> String {
        let template = tr(key)
        return String(format: template, arguments: args)
    }
}
