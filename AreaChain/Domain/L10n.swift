import Foundation

enum L10n {
    static func bundle(for locale: Locale) -> Bundle {
        let code = locale.identifier.hasPrefix("zh") ? "zh-Hans" : "en"
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, table: nil, bundle: bundle(for: locale), locale: locale)
    }

    static func format(_ key: String, locale: Locale, _ args: CVarArg...) -> String {
        let template = bundle(for: locale).localizedString(forKey: key, value: key, table: nil)
        return String(format: template, locale: locale, arguments: args)
    }
}
