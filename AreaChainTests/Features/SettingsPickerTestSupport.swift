import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor @Observable
final class SettingsPickerProbe {
    var login = false
    var loginRequests: [Bool] = []
    var notifications = 0
    var disabled = false
    var message: String?
}

struct SettingsPickerForm: View {
    let prefs: AppPreferences
    @Bindable var state: SettingsPickerProbe

    var body: some View {
        Form {
            GeneralSettingsSection(prefs: prefs, launchesAtLogin: $state.login,
                loginNeedsApproval: false, statusMessage: state.message,
                onUpdateLoginItem: { state.loginRequests.append($0) })
        }
        .formStyle(.grouped)
        .daybookScroll()
        .disabled(state.disabled)
    }
}

/// 读宿主实际环境；不从 prefs 推导断言值，也不向环境写入测试期望。
struct SettingsPickerEnvironment: View {
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(verbatim: "environment:\(locale.identifier):\(scheme == .dark ? "dark" : "light")")
            .accessibilityIdentifier("settings.picker.environment")
    }
}

extension SettingsPickerConsumerTests {
    func dynamicWindow(_ fixture: Native, state: SettingsPickerProbe, prefs: AppPreferences? = nil) -> NSWindow {
        let preferences = prefs ?? fixture.prefs
        return SystemPageHost.preferenceWindow(
            VStack(spacing: 0) {
                SettingsPickerForm(prefs: preferences, state: state)
                SettingsPickerEnvironment()
            }, container: fixture.container, prefs: preferences, size: NSSize(width: 420, height: 560))
    }

    func prepare(_ window: NSWindow) async throws {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
    }

    func hasText(_ expected: String, in window: NSWindow) -> Bool {
        Native.elements(window.contentView).contains { node in
            ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].contains {
                Native.value(node, $0) as? String == expected
            }
        }
    }

    func assertLocalized(_ locale: String, prefs: AppPreferences, in window: NSWindow) async throws {
        let values = [prefs.language.rawValue, prefs.appearance.rawValue, prefs.quadrantTitleTruncation.rawValue]
        for (index, group) in Self.groups.enumerated() {
            let (key, prefix, options, _) = group
            let node = try Menus.menu(key, locale: locale, in: window)
            #expect(Menus.title(node) == Menus.localized(key, locale))
            #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("\(prefix).\(values[index])", locale))
            let menu = try await Menus.openAndEscape(node, in: window)
            #expect(menu.items.map(\.title) == options.map { Menus.localized("\(prefix).\($0)", locale) })
            #expect(menu.items.map(\.state) == options.map { $0 == values[index] ? .on : .off })
        }
        for key in ["settings.quadrant.truncation.help", "settings.capture.stamp.help", "settings.capture.screen.help"] {
            #expect(hasText(Menus.localized(key, locale), in: window), "相邻说明未随语言更新：\(key)")
        }
    }

    /// 真实菜单项的程序化 action，和合成键盘证据分别计数。
    func choose(_ key: String, option: String, locale: String, fixture: Native,
                state: SettingsPickerProbe, in window: NSWindow) async throws {
        let before = stored(fixture)
        let count = state.notifications
        let group = try #require(Self.groups.first { $0.0 == key })
        let node = try Menus.menu(key, locale: locale, in: window)
        let menu = try await Menus.openAndEscape(node, in: window)
        #expect(stored(fixture) == before && state.notifications == count)
        try Menus.dispatch(Menus.localized("\(group.1).\(option)", locale), in: menu)
        try await SystemPageHost.settle(window)
        #expect(state.notifications == count + 1)
        #expect(fixture.defaults.string(forKey: group.3) == option)
        #expect(stored(fixture).filter { $0.key != group.3 } == before.filter { $0.key != group.3 })
        #expect(!state.login && state.loginRequests.isEmpty && !fixture.prefs.stampCaptureApp && !fixture.prefs.syncCalendarEvents)
    }
}
