import AppKit
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
        #expect(L10n.string("tab.tasks", locale: Locale(identifier: "zh-Hans")) == "事项")
        #expect(L10n.string("tab.tasks", locale: Locale(identifier: "en")) == "Items")
        #expect(L10n.string("tab.residents", locale: Locale(identifier: "zh-Hans")) == "重复事项")
        #expect(L10n.string("tab.residents", locale: Locale(identifier: "en")) == "Recurring")
        #expect(L10n.string("residents.hint", locale: Locale(identifier: "zh-Hans")) == "打开的会出现在今天的清单里。点星期决定哪几天出现；关掉只是先不出现，不是删除。")
        #expect(L10n.string("residents.empty", locale: Locale(identifier: "en")) == "None yet. Add one below.")
        #expect(L10n.string("sidebar.parent", locale: Locale(identifier: "en")) == "Nest under")
        #expect(L10n.string("row.attach.screen", locale: Locale(identifier: "en")) == "Capture current screen")
        #expect(L10n.string("empty.filter", locale: Locale(identifier: "zh-Hans")) == "这个筛选下没有事项。")
        #expect(L10n.string("empty.filter", locale: Locale(identifier: "en")) == "Nothing matches this filter.")
        #expect(L10n.string("tag.preset.reserved", locale: Locale(identifier: "zh-Hans")) == "「密码」「小巧思」「日记」是手记分类，不能当作待办标签。")
        #expect(L10n.string("tag.preset.reserved", locale: Locale(identifier: "en")) == "「密码」「小巧思」「日记」 are note categories, not task tags.")
    }

    @Test func noteEntryPointsUseConsistentNamesWithoutRenamingJournalCategory() {
        let zh = Locale(identifier: "zh-Hans")
        let en = Locale(identifier: "en")
        let keys: [String.LocalizationValue] = ["tab.diary", "capture.diary", "trash.kind.diary", "attachments.owner.diary"]
        for key in keys {
            #expect(L10n.string(key, locale: zh) == "手记")
            #expect(L10n.string(key, locale: en) == "Notes")
        }
        #expect(L10n.string("search.kind.diary", locale: zh) == "手记")
        #expect(L10n.string("search.kind.diary", locale: en) == "Note")
        #expect(L10n.string("手记 (⌘→)", locale: zh) == "手记 (⌘→)")
        #expect(L10n.string("手记 (⌘→)", locale: en) == "Notes (⌘→)")
        #expect(L10n.string("直接存入手记", locale: zh) == "直接存入手记")
        #expect(L10n.string("直接存入手记", locale: en) == "Save to notes")
        #expect(DiaryMemoTags.journal == "日记")
    }

    @Test @MainActor func writesLanguageAndAppearanceToInjectedDefaults() {
        let previousAppearance = NSApp.appearance
        defer { NSApp.appearance = previousAppearance }
        let name = "areachain.prefs.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let prefs = AppPreferences(defaults: defaults)
        prefs.language = .english
        prefs.appearance = .dark
        #expect(NSApp.appearance?.name == .darkAqua)
        #expect(defaults.string(forKey: AppPreferences.languageKey) == "english")
        #expect(defaults.string(forKey: AppPreferences.appearanceKey) == "dark")
        #expect(prefs.resolvedLocale.identifier == "en")
        #expect(prefs.resolvedColorScheme == .dark)
        #expect(prefs.stampCaptureApp == false)
        #expect(prefs.wantsICloudSync == false)
        #expect(prefs.syncCalendarEvents == false)
        prefs.stampCaptureApp = true
        prefs.wantsICloudSync = true
        prefs.syncCalendarEvents = true
        #expect(defaults.bool(forKey: AppPreferences.stampCaptureAppKey))
        #expect(defaults.bool(forKey: AppPreferences.iCloudDesiredKey))
        #expect(defaults.bool(forKey: AppPreferences.syncCalendarEventsKey))
    }
}
