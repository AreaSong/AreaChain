import AppKit
import Foundation
import Observation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case chinese
    case english

    var id: String { rawValue }

    func resolvedCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        switch self {
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        case .system:
            let first = preferredLanguages.first ?? "en"
            if first.hasPrefix("zh") { return "zh-Hans" }
            return "en"
        }
    }

    var resolvedLocale: Locale {
        Locale(identifier: resolvedCode())
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var resolvedColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    static let languageKey = "areachain.prefs.language"
    static let appearanceKey = "areachain.prefs.appearance"
    static let stampCaptureAppKey = "areachain.prefs.stampCaptureApp"
    static let iCloudDesiredKey = "areachain.prefs.icloudDesired"

    private let defaults: UserDefaults
    private var isLoading = true

    var language: AppLanguage {
        didSet {
            guard !isLoading else { return }
            defaults.set(language.rawValue, forKey: Self.languageKey)
            notifyChange()
        }
    }

    var appearance: AppAppearance {
        didSet {
            guard !isLoading else { return }
            defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
            applyAppAppearance()
            notifyChange()
        }
    }

    var stampCaptureApp: Bool {
        didSet {
            guard !isLoading else { return }
            defaults.set(stampCaptureApp, forKey: Self.stampCaptureAppKey)
            notifyChange()
        }
    }

    var wantsICloudSync: Bool {
        didSet {
            guard !isLoading else { return }
            defaults.set(wantsICloudSync, forKey: Self.iCloudDesiredKey)
            notifyChange()
        }
    }

    var resolvedLocale: Locale { language.resolvedLocale }

    var resolvedColorScheme: ColorScheme? { appearance.resolvedColorScheme }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let languageRaw = defaults.string(forKey: Self.languageKey) ?? AppLanguage.system.rawValue
        language = AppLanguage(rawValue: languageRaw) ?? .system
        let appearanceRaw = defaults.string(forKey: Self.appearanceKey) ?? AppAppearance.system.rawValue
        appearance = AppAppearance(rawValue: appearanceRaw) ?? .system
        stampCaptureApp = defaults.bool(forKey: Self.stampCaptureAppKey)
        wantsICloudSync = defaults.bool(forKey: Self.iCloudDesiredKey)
        isLoading = false
        applyAppAppearance()
    }

    func applyAppAppearance() {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .appPreferencesDidChange, object: nil)
    }
}

struct AppChrome: ViewModifier {
    @Bindable var prefs: AppPreferences

    init(prefs: AppPreferences = .shared) {
        self.prefs = prefs
    }

    func body(content: Content) -> some View {
        content
            .environment(prefs)
            .environment(\.locale, prefs.resolvedLocale)
            .preferredColorScheme(prefs.resolvedColorScheme)
    }
}

extension View {
    func appChrome() -> some View {
        modifier(AppChrome())
    }
}
