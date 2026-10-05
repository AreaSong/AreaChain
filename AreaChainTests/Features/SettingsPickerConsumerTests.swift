import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SettingsPickerConsumerTests {
    typealias Native = SettingsButtonTestSupport
    typealias Menus = MenuButtonTestSupport

    static let groups = [
        ("settings.language", "language", ["system", "chinese", "english"], AppPreferences.languageKey),
        ("settings.look", "appearance", ["system", "light", "dark"], AppPreferences.appearanceKey),
        ("settings.quadrant.truncation", "settings.quadrant.truncation", ["tail", "middle"], AppPreferences.quadrantTitleTruncationKey)
    ]

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func groupedFormSelectionAndCancellation(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let state = SettingsPickerProbe()
        let window = fixture.window(SettingsPickerForm(prefs: fixture.prefs, state: state), locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let observer = observe(state, fixture: fixture)
        defer { fixture.preferenceCenter.removeObserver(observer) }
        try Native.snapshot(window, name: "picker-general-layout-\(locale)-\(scheme)")
        #expect(Menus.menus(in: window).count == 3)
        let identifiers = Set(Native.elements(window.contentView).compactMap {
            Native.value($0, "accessibilityIdentifier") as? String
        })
        #expect(Set(Self.groups.map(\.0)).isSubset(of: identifiers))
        try Native.assertBounds(Menus.menus(in: window), in: window)
        for (key, prefix, options, storage) in Self.groups {
            let node = try Menus.menu(key, locale: locale, in: window)
            #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("\(prefix).\(options[0])", locale))
            let popup = try #require(Native.elements(window.contentView).compactMap { $0 as? NSPopUpButton }
                .first { $0.accessibilityLabel() == Menus.localized(key, locale) })
            let accessible = try Native.frame(node, in: window)
            let native = popup.convert(popup.bounds, to: nil)
            // 辅助框包含公共菜单的水平内边距，但中心必须落在真实原生入口。
            #expect(accessible.contains(native))
            #expect(native.contains(NSPoint(x: accessible.midX, y: accessible.midY)),
                    "辅助框中心必须命中原生入口：\(accessible)，原生框 \(native)")
            let before = stored(fixture)
            let count = state.notifications
            let menu = try await Menus.openAndEscape(node, in: window)
            #expect(stored(fixture) == before && state.notifications == count)
            #expect(menu.items.map(\.title) == options.map { Menus.localized("\(prefix).\($0)", locale) })
            #expect(menu.items.map(\.state) == options.indices.map { $0 == 0 ? .on : .off })
            try await PickerNativeTestSupport.keyboardSelection(node, moveDown: false, in: window)
            #expect(state.notifications == count + 1)
            #expect(fixture.defaults.string(forKey: storage) == options[0])
            #expect(stored(fixture).filter { $0.key != storage } == before.filter { $0.key != storage })
        }
        #expect(state.loginRequests.isEmpty && !state.login && !fixture.prefs.stampCaptureApp)
        try Native.snapshot(window, name: "picker-general-\(locale)-\(scheme)")
    }

    func stored(_ fixture: Native) -> [String: NSObject] {
        (fixture.defaults.persistentDomain(forName: fixture.suite) ?? [:]).compactMapValues { $0 as? NSObject }
    }

    @Test func languageChangesThroughAppChromeWithoutFallback() async throws {
        let fixture = try Native(isolatedPreferences: true)
        defer { fixture.cleanup() }
        fixture.prefs.language = .english
        fixture.prefs.appearance = .light
        let state = SettingsPickerProbe()
        let window = dynamicWindow(fixture, state: state)
        defer { SystemPageHost.release(window) }
        try await prepare(window)
        let observer = observe(state, fixture: fixture)
        defer { fixture.preferenceCenter.removeObserver(observer) }
        try await assertLocalized("en", prefs: fixture.prefs, in: window)
        #expect(hasText("environment:en:light", in: window))
        try await choose("settings.language", option: "chinese", locale: "en", fixture: fixture, state: state, in: window)
        #expect(fixture.prefs.language == .chinese)
        #expect(hasText("environment:zh-Hans:light", in: window))
        try await assertLocalized("zh-Hans", prefs: fixture.prefs, in: window)
        try Native.snapshot(window, name: "picker-dynamic-chinese")
        let count = state.notifications
        let before = stored(fixture)
        let node = try Menus.menu("settings.language", locale: "zh-Hans", in: window)
        try await PickerNativeTestSupport.keyboardSelection(node, moveDown: true, in: window)
        #expect(fixture.prefs.language == .english && state.notifications == count + 1)
        #expect(fixture.defaults.string(forKey: AppPreferences.languageKey) == "english")
        #expect(stored(fixture).filter { $0.key != AppPreferences.languageKey } == before.filter { $0.key != AppPreferences.languageKey })
        try await assertLocalized("en", prefs: fixture.prefs, in: window)
        #expect(hasText("environment:en:light", in: window))
        try await choose("settings.language", option: "system", locale: "en", fixture: fixture, state: state, in: window)
        #expect(fixture.prefs.language == .system)
        let resolved = AppLanguage.system.resolvedCode()
        try await assertLocalized(resolved, prefs: fixture.prefs, in: window)
        #expect(hasText("environment:\(resolved):light", in: window))
        #expect(fixture.prefs.appearance == .light && fixture.prefs.quadrantTitleTruncation == .tail)
    }

    @Test func appearanceUsesProcessAndHostEnvironment() async throws {
        let previous = NSApp.appearance
        let fixture = try Native()
        defer { fixture.cleanup() }
        fixture.prefs.language = .english
        let state = SettingsPickerProbe()
        let window = dynamicWindow(fixture, state: state)
        defer { SystemPageHost.release(window) }
        try await prepare(window)
        let observer = observe(state, fixture: fixture)
        defer { fixture.preferenceCenter.removeObserver(observer) }
        try Native.snapshot(window, name: "picker-dynamic-initial-system")
        let systemDark = hasText("environment:en:dark", in: window)
        #expect(systemDark || hasText("environment:en:light", in: window))
        for appearance in [AppAppearance.light, .dark, .system] {
            try await choose("settings.look", option: appearance.rawValue, locale: "en", fixture: fixture, state: state, in: window)
            #expect(fixture.prefs.appearance == appearance)
            let expected: NSAppearance.Name? = appearance == .system ? nil : appearance == .dark ? .darkAqua : .aqua
            #expect(NSApp.appearance?.name == expected)
            let effective = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
            #expect(effective == (expected ?? NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])))
            if appearance == .system { try await Task.sleep(for: .seconds(1)) }
            let expectedDark = appearance == .system ? systemDark : appearance == .dark
            if appearance == .system && !systemDark {
                withKnownIssue("B 原生 Picker 对照同样失败：dark→system 后环境仍深色，见工程手册第四阶段 B") {
                    #expect(hasText("environment:en:light", in: window))
                }
            } else {
                #expect(hasText("environment:en:\(expectedDark ? "dark" : "light")", in: window))
            }
            #expect(fixture.prefs.resolvedColorScheme == appearance.resolvedColorScheme)
            try await assertLocalized("en", prefs: fixture.prefs, in: window)
            try Native.snapshot(window, name: "picker-dynamic-\(appearance.rawValue)")
        }
        #expect(fixture.prefs.language == .english && fixture.prefs.quadrantTitleTruncation == .tail)
        fixture.cleanup()
        #expect(NSApp.appearance === previous)
    }

    @Test func persistenceReopenRebuildAndTruncationKeepTitle() async throws {
        let fixture = try Native(isolatedPreferences: true)
        defer { fixture.cleanup() }
        fixture.prefs.language = .english
        let state = SettingsPickerProbe()
        let title = String(repeating: "Synthetic title · 合成标题 ", count: 8)
        let item = TodoItem(title: title, dayKey: "2026-10-02")
        fixture.container.mainContext.insert(item)
        try fixture.container.mainContext.save()
        let window = dynamicWindow(fixture, state: state)
        try await prepare(window)
        let observer = observe(state, fixture: fixture)
        defer { fixture.preferenceCenter.removeObserver(observer) }
        defer { SystemPageHost.release(window) }
        for mode in [QuadrantTitleTruncation.middle, .tail, .middle] {
            try await choose("settings.quadrant.truncation", option: mode.rawValue, locale: "en",
                             fixture: fixture, state: state, in: window)
            #expect(fixture.prefs.quadrantTitleTruncation == mode)
            #expect(fixture.prefs.quadrantTitleTruncation.textTruncation == (mode == .tail ? .tail : .middle))
            #expect(item.title == title && !fixture.container.mainContext.hasChanges)
        }
        try await choose("settings.look", option: "dark", locale: "en", fixture: fixture, state: state, in: window)
        try await choose("settings.language", option: "chinese", locale: "en", fixture: fixture, state: state, in: window)
        SystemPageHost.release(window)
        let saved = stored(fixture)
        let count = state.notifications
        for prefs in [fixture.prefs, AppPreferences(defaults: fixture.defaults, effects: fixture.preferenceEffects)] {
            #expect(prefs.language == .chinese && prefs.appearance == .dark && prefs.quadrantTitleTruncation == .middle)
            let reopened = dynamicWindow(fixture, state: state, prefs: prefs)
            defer { SystemPageHost.release(reopened) }
            try await prepare(reopened)
            try await assertLocalized("zh-Hans", prefs: prefs, in: reopened)
            #expect(stored(fixture) == saved && state.notifications == count)
            #expect(hasText("environment:zh-Hans:dark", in: reopened) && item.title == title)
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func disabledExternalUpdatesAndLongDescription(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let state = SettingsPickerProbe()
        state.disabled = true
        state.message = String(repeating: "Synthetic startup explanation · 合成启动说明。", count: 6)
        let window = fixture.window(SettingsPickerForm(prefs: fixture.prefs, state: state), locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await prepare(window)
        let before = stored(fixture)
        for node in Menus.menus(in: window) {
            #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
            try await Native.click(node, in: window)
        }
        #expect(stored(fixture) == before && state.loginRequests.isEmpty)
        state.disabled = false
        fixture.prefs.language = .chinese
        fixture.prefs.appearance = .dark
        fixture.prefs.quadrantTitleTruncation = .middle
        try await SystemPageHost.settle(window)
        let saved = stored(fixture)
        let observer = observe(state, fixture: fixture)
        defer { fixture.preferenceCenter.removeObserver(observer) }
        try await assertLocalized(locale, prefs: fixture.prefs, in: window)
        #expect(stored(fixture) == saved && state.notifications == 0)
        let menus = Menus.menus(in: window)
        try Native.assertBounds(menus, in: window)
        let frames = try menus.map { try Native.frame($0, in: window) }
        for rect in frames {
            #expect(abs(rect.height - 28) < 1)
            #expect(abs(rect.maxX - frames[0].maxX) < 1)
        }
        #expect(try hasText(#require(state.message), in: window))
        try Native.snapshot(window, name: "picker-general-long-\(locale)-\(scheme)")
        let message = try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityRole") as? String == "AXStaticText"
                && Native.value($0, "accessibilityValue") as? String == state.message
        })
        try await Native.reveal(message, in: window)
        try Native.assertBounds([message], in: window)
        try Native.snapshot(window, name: "picker-general-long-scrolled-\(locale)-\(scheme)")
    }

    func observe(_ state: SettingsPickerProbe, fixture: Native) -> NSObjectProtocol {
        let source = fixture.prefs.localPreferenceSource
        return fixture.preferenceCenter.addObserver(forName: .localPreferenceDidChange, object: nil, queue: nil) { note in
            guard (note.object as? LocalPreferenceChange)?.source == source else { return }
            MainActor.assumeIsolated { state.notifications += 1 }
        }
    }
}
