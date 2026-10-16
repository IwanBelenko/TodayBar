import Foundation

/// UI language only. Persisted task text, category names and JSON stay unchanged.
enum L10n {
    static func isRussian(_ language: String?) -> Bool {
        language?.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first == "ru"
    }

    static let language: String = {
        #if DEBUG
        if let testLanguage = ProcessInfo.processInfo.environment["TODAYBAR_TEST_LANGUAGE"] {
            return testLanguage
        }
        #endif
        return Locale.preferredLanguages.first ?? "en"
    }()

    static let locale = Locale(identifier: isRussian(language) ? "ru_RU" : "en_US")
    static func text(_ russian: String, _ english: String) -> String {
        isRussian(language) ? russian : english
    }
}
