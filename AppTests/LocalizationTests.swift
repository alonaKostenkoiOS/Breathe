import Foundation
import Testing
import BreatheCore
@testable import Breathe

@Suite("Production localization")
struct LocalizationTests {
    private var catalogURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/Localizable.xcstrings")
    }

    private var catalog: [String: Any] {
        get throws {
            let data = try Data(contentsOf: catalogURL)
            return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
    }

    @Test func supportsExactlyTheRequiredLanguages() {
        #expect(AppLanguage.supportedLocaleIdentifiers == ["en", "uk", "es", "pt-BR", "de", "fr", "it", "pl", "tr", "ja", "ko", "zh-Hans"])
        #expect(!AppLanguage.supportedLocaleIdentifiers.contains("ru"))
    }

    @Test func everyCatalogValueIsPresentAndNonempty() throws {
        let strings = try #require(try catalog["strings"] as? [String: Any])
        for (key, rawEntry) in strings {
            let entry = try #require(rawEntry as? [String: Any], "Invalid entry: \(key)")
            let localizations = try #require(entry["localizations"] as? [String: Any], "Missing localizations: \(key)")
            for locale in AppLanguage.supportedLocaleIdentifiers.dropFirst() {
                let localization = try #require(localizations[locale] as? [String: Any], "Missing \(locale): \(key)")
                let unit = try #require(localization["stringUnit"] as? [String: Any], "Missing unit \(locale): \(key)")
                let value = try #require(unit["value"] as? String, "Missing value \(locale): \(key)")
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @Test func nonEnglishValuesAreNotEnglishPlaceholders() throws {
        let allowedCognates: Set<String> = ["Alcohol", "Home", "Notifications", "OK", "Social", "Stress", "Version"]
        let strings = try #require(try catalog["strings"] as? [String: Any])
        for (key, rawEntry) in strings where !key.contains("%@") {
            let entry = try #require(rawEntry as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any])
            for locale in AppLanguage.supportedLocaleIdentifiers.dropFirst() {
                let localization = try #require(localizations[locale] as? [String: Any])
                let unit = try #require(localization["stringUnit"] as? [String: Any])
                let value = try #require(unit["value"] as? String)
                if value == key { #expect(allowedCognates.contains(key), "English placeholder for \(locale): \(key)") }
            }
        }
    }

    @Test func unknownKeyUsesEnglishFallback() {
        #expect(AppLocalization.string("localization.test.unknown", language: .english) == "localization.test.unknown")
    }

    @Test func languagePreferencePersistsWithoutChangingProfileData() {
        let suite = UserDefaults(suiteName: "LocalizationTests.\(UUID().uuidString)")!
        let originalCurrency = "UAH"
        let originalQuitDate = Date(timeIntervalSince1970: 1_700_000_000)
        suite.set(AppLanguage.polish.rawValue, forKey: AppLanguage.defaultsKey)
        #expect(AppLocalization.selectedLanguage(defaults: suite) == .polish)
        #expect(originalCurrency == "UAH")
        #expect(originalQuitDate == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func datesCurrenciesPercentagesAndDurationsFollowLocale() {
        let date = Date(timeIntervalSince1970: 1_775_068_800)
        let englishDate = date.formatted(.dateTime.year().month(.wide).day().locale(Locale(identifier: "en_US")))
        let ukrainianDate = date.formatted(.dateTime.year().month(.wide).day().locale(Locale(identifier: "uk_UA")))
        #expect(englishDate != ukrainianDate)

        #expect(ProgressFormatter(locale: Locale(identifier: "de_DE")).money(12.5, currencyCode: "UAH").contains("UAH"))
        #expect(ProgressFormatter(locale: Locale(identifier: "de_DE")).percentage(0.42).contains("42"))

        let ukrainian = ProgressFormatter(locale: Locale(identifier: "uk_UA")).duration(2 * 86_400)
        let polish = ProgressFormatter(locale: Locale(identifier: "pl_PL")).duration(2 * 86_400)
        #expect(ukrainian.contains("2"))
        #expect(polish.contains("2"))
        #expect(ukrainian != polish)
    }

    @Test func sensitiveNotificationCopyIsLocalized() {
        for language in AppLanguage.allCases where language != .system && language != .english {
            #expect(AppLocalization.string("Milestone reached 🫁", language: language) != "Milestone reached 🫁")
            #expect(AppLocalization.string("Your progress still matters.", language: language) != "Your progress still matters.")
        }
    }
}
