import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case ukrainian = "uk"
    case spanish = "es"
    case portugueseBrazil = "pt-BR"
    case german = "de"
    case french = "fr"
    case italian = "it"
    case polish = "pl"
    case turkish = "tr"
    case japanese = "ja"
    case korean = "ko"
    case simplifiedChinese = "zh-Hans"

    static let defaultsKey = "app_language_preference"
    nonisolated(unsafe) static let sharedDefaults = UserDefaults(suiteName: "group.com.breathe.app") ?? .standard
    static let supportedLocaleIdentifiers = allCases.dropFirst().map(\.rawValue)

    var id: String { rawValue }
    var locale: Locale { self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue) }
    var nativeName: String {
        switch self {
        case .system: "System Default"
        case .english: "English"
        case .ukrainian: "Українська"
        case .spanish: "Español"
        case .portugueseBrazil: "Português (Brasil)"
        case .german: "Deutsch"
        case .french: "Français"
        case .italian: "Italiano"
        case .polish: "Polski"
        case .turkish: "Türkçe"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .simplifiedChinese: "简体中文"
        }
    }
}

enum AppLocalization {
    static func selectedLanguage(defaults: UserDefaults = AppLanguage.sharedDefaults) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: AppLanguage.defaultsKey) ?? "system") ?? .system
    }

    static func string(_ key: String, language: AppLanguage? = nil, bundle: Bundle = .main) -> String {
        let language = language ?? selectedLanguage()
        guard language != .system,
              let path = bundle.path(forResource: language.rawValue, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    #if DEBUG
    static func missingKeys(in catalogURL: URL) throws -> [String] {
        let data = try Data(contentsOf: catalogURL)
        let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = catalog?["strings"] as? [String: Any] ?? [:]
        return strings.compactMap { key, value -> String? in
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else { return key }
            for locale in AppLanguage.supportedLocaleIdentifiers where localizations[locale] == nil { return key }
            return nil
        }.sorted()
    }
    #endif
}
