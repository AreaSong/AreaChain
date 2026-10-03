import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 只挂载生产隐私页；原 Presenter 接收此夹具的 fake vault，不打开设置探测或内容保护入口。
@MainActor
final class PrivacyAutolockTestSupport {
    typealias Native = SettingsButtonTestSupport
    typealias Menus = MenuButtonTestSupport
    let fixture: PrivacyFixture
    let preferences: Native
    let store: MemoryVaultConfigurationStore
    let system: FakeSystemVaultKeys
    let window: NSWindow
    let locale: String
    let previousWindows: Set<ObjectIdentifier>
    let previousFallback: Bool
    var vault: PrivacyVault { fixture.vault }

    init(fixture: PrivacyFixture, preferences: Native, locale: String, scheme: ColorScheme) throws {
        self.fixture = fixture
        self.preferences = preferences
        self.locale = locale
        store = try #require(fixture.vault.store as? MemoryVaultConfigurationStore)
        system = try #require(fixture.vault.systemKeys as? FakeSystemVaultKeys)
        try #require(fixture.container.configurations.allSatisfy { $0.isStoredInMemoryOnly })
        try #require(Bundle.main.bundleIdentifier == "com.areachain.privacy-qa")
        try #require(!NSApp.windows.contains { $0.isVisible && $0.delegate === PrivacyUnlockPresenter.shared })
        previousWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        previousFallback = StoreHealth.shared.isUsingMemoryFallback
        StoreHealth.shared.isUsingMemoryFallback = false
        window = SystemPageHost.window(PrivacyUnlockSettingsView(vault: fixture.vault), container: fixture.container,
            scheme: scheme, locale: locale, size: NSSize(width: 420, height: 560), prefs: preferences.prefs)
    }

    var panel: NSWindow? {
        NSApp.windows.first {
            !previousWindows.contains(ObjectIdentifier($0)) && $0.isVisible
                && $0.delegate === PrivacyUnlockPresenter.shared
        }
    }

    func cleanup() async {
        // 只关闭本测试创建的面板；finish 会使原 continuation 取消并使本 vault 的认证代次失效。
        panel?.close()
        if await system.pendingRead != nil { await system.finishRead() }
        try? await SystemPageHost.settle(window)
        SystemPageHost.release(window)
        StoreHealth.shared.isUsingMemoryFallback = previousFallback
        preferences.cleanup()
        fixture.cleanup()
    }

    func ready() async throws {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await Native.reveal(node(), in: window)
    }

    func node() throws -> NSObject {
        try Menus.menu("privacy.autolock", locale: locale, in: window)
    }

    func menu() async throws -> NSMenu { try await Menus.openAndEscape(node(), in: window) }

    func wait(_ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !(await condition()), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(40)) }
        try #require(await condition())
    }

    func startSystemAuthentication() async throws -> NSWindow {
        try await wait { self.panel != nil }
        let panel = try #require(panel)
        try await NativeSyntaxUI.prepareFocus(in: panel)
        try await SystemPageHost.settle(panel)
        // Presenter 的按钮沿原 AppPreferences.shared locale；只读，不修改系统或 shared 偏好。
        let language = AppPreferences.shared.resolvedLocale.identifier
        try await Native.click(Native.button("privacy.unlock.system", locale: language, in: panel), in: panel)
        return panel
    }

    func cancelPanel() async throws {
        let panel = try #require(panel)
        try await NativeSyntaxUI.prepareFocus(in: panel)
        try await Native.click(Native.button("alert.cancel", locale: AppPreferences.shared.resolvedLocale.identifier,
                                            in: panel), in: panel)
        try await wait { self.panel == nil }
        try await ready()
    }

    func hasText(_ key: String, in target: NSWindow? = nil) -> Bool {
        let target = target ?? window
        let language = target === window ? locale : AppPreferences.shared.resolvedLocale.identifier
        let expected = Menus.localized(key, language)
        return Native.elements(target.contentView).contains { node in
            ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].contains {
                Native.value(node, $0) as? String == expected
            }
        }
    }

    func assertValue(_ seconds: Int) throws {
        let key = [60: "privacy.idle.1", 300: "privacy.idle.5", 900: "privacy.idle.15"][seconds]!
        #expect(vault.idleSeconds == seconds && store.value?.idleSeconds == seconds)
        let actual = Native.value(try node(), "accessibilityValue") as? String
        let expected = Menus.localized(key, locale)
        #expect(actual == expected)
    }

    func assertEnabled(_ enabled: Bool) throws {
        #expect(try node().value(forKey: "accessibilityEnabled") as? Bool == enabled)
        for key in ["privacy.tags.manage", "privacy.lock.toggle"] {
            #expect(try Native.button(key, locale: locale, in: window).value(forKey: "accessibilityEnabled") as? Bool == enabled)
        }
    }
}

extension PrivacyAutolockPickerTests {
    func withHost(locale: String = "en", scheme: ColorScheme = .light,
                  _ work: (PrivacyAutolockTestSupport) async throws -> Void) async throws {
        let fixture = try await PrivacyFixture.make()
        let preferences = try SettingsButtonTestSupport()
        let host = try PrivacyAutolockTestSupport(fixture: fixture, preferences: preferences, locale: locale, scheme: scheme)
        do {
            try await host.vault.enableSystemUnlock()
            try await host.ready()
            try await work(host)
            await host.cleanup()
        } catch {
            await host.cleanup()
            throw error
        }
    }
}
