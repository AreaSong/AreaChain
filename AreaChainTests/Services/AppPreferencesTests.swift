import Foundation
import SwiftUI
import Testing
@testable import AreaChain

struct AppPreferencesTests {
    @Test func systemChineseResolvesToHans() {
        #expect(AppLanguage.system.resolvedCode(preferredLanguages: ["zh-Hans-CN"]) == "zh-Hans")
        #expect(AppLanguage.system.resolvedCode(preferredLanguages: ["zh-TW"]) == "zh-Hans")
    }

    @Test func forcedEnglishStaysEnglish() {
        #expect(AppLanguage.english.resolvedCode(preferredLanguages: ["zh-Hans-CN"]) == "en")
    }

    @Test func appearanceSystemIsNilAndDarkResolves() {
        #expect(AppAppearance.system.resolvedColorScheme == nil)
        #expect(AppAppearance.dark.resolvedColorScheme == .dark)
        #expect(AppAppearance.light.resolvedColorScheme == .light)
    }

    @Test func catalogFollowsExplicitLocale() {
        #expect(L10n.string("tab.tasks", locale: Locale(identifier: "zh-Hans")) == "任务")
        #expect(L10n.string("tab.tasks", locale: Locale(identifier: "en")) == "Tasks")
    }

    @Test func writesLanguageAndAppearanceToInjectedDefaults() {
        let name = "areachain.prefs.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let prefs = AppPreferences(defaults: defaults)
        prefs.language = .english
        prefs.appearance = .dark
        #expect(defaults.string(forKey: AppPreferences.languageKey) == "english")
        #expect(defaults.string(forKey: AppPreferences.appearanceKey) == "dark")
        #expect(prefs.resolvedLocale.identifier == "en")
        #expect(prefs.resolvedColorScheme == .dark)
        #expect(prefs.stampCaptureApp == false)
        #expect(prefs.wantsICloudSync == false)
        prefs.stampCaptureApp = true
        prefs.wantsICloudSync = true
        #expect(defaults.bool(forKey: AppPreferences.stampCaptureAppKey))
        #expect(defaults.bool(forKey: AppPreferences.iCloudDesiredKey))
    }
}
