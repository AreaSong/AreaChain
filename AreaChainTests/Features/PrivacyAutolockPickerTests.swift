import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PrivacyAutolockPickerTests {
    typealias Native = SettingsButtonTestSupport
    typealias Menus = MenuButtonTestSupport

    @Test(arguments: [false, true])
    func selectionRequiresFreshAuthenticationEvenWhenUnlocked(reselect: Bool) async throws {
        try await withHost { host in
            let original = host.store.value
            let generation = host.vault.generation
            #expect(host.vault.isUnlocked)
            let menu = try await host.menu()
            #expect(host.panel == nil && host.vault.generation == generation)
            #expect(host.store.value == original)
            await host.system.suspend()
            try await PickerNativeTestSupport.keyboardSelection(host.node(), moveDown: !reselect, in: host.window)
            try await host.wait { host.panel != nil }
            #expect(host.vault.generation == generation, "已解锁仍须显示重新认证面板")
            #expect(host.store.value == original)
            try host.assertEnabled(false)
            try host.assertValue(300)
            // performActionForItem 会先强制改变 AppKit 选中项，即使菜单已禁用；
            // 此处直接派发原 target/action 验证防重入，另用合成鼠标检查可达的禁用入口。
            for item in [menu.items[0], menu.items[2]] {
                NSApp.sendAction(try #require(item.action), to: item.target, from: item)
            }
            try await host.ready()
            try await Native.click(host.node(), in: host.window)
            try host.assertValue(300)
            let panel = try await host.startSystemAuthentication()
            try await host.wait { await host.system.pendingRead != nil }
            #expect(host.vault.generation == generation + 1)
            #expect(!host.hasText("privacy.settings.saved"))
            #expect(!host.hasText(PrivacyError.busy.messageKey))
            try host.assertValue(300)
            try await Native.click(Native.button("privacy.unlock.system",
                locale: AppPreferences.shared.resolvedLocale.identifier, in: panel), in: panel)
            #expect(host.vault.generation == generation + 1)
            await host.system.finishRead()
            try await host.wait { host.panel == nil && host.hasText("privacy.settings.saved") }
            try await host.ready()
            let expected = reselect ? 300 : 900
            try host.assertValue(expected)
            try host.assertEnabled(true)
            #expect(host.vault.isUnlocked)
            let current = try await host.menu()
            #expect(current.items.map(\.state) == [NSControl.StateValue.off, reselect ? .on : .off, reselect ? .off : .on])
            let reopened = PrivacyVault(store: host.store, systemKeys: host.system)
            #expect(reopened.idleSeconds == expected && reopened.state == .locked)
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func layoutOptionsAndEscape(locale: String, scheme: ColorScheme) async throws {
        try await withHost(locale: locale, scheme: scheme) { host in
            let revision = host.vault.revision
            try host.assertValue(300)
            let node = try host.node()
            try Native.assertBounds([node], in: host.window)
            let frame = try Native.frame(node, in: host.window)
            print("AUTOLOCK_LAYOUT \(locale) \(scheme) \(frame)")
            let popup = try #require(Native.elements(host.window.contentView).compactMap { $0 as? NSPopUpButton }.first)
            let native = popup.convert(popup.bounds, to: nil)
            #expect(frame.contains(native))
            #expect(native.contains(NSPoint(x: frame.midX, y: frame.midY)))
            #expect(frame.height == DaybookMetrics.Hit.regular)
            #expect(Menus.title(node) == Menus.localized("privacy.autolock", locale))
            let ids = Set(Native.elements(host.window.contentView).compactMap {
                Native.value($0, "accessibilityIdentifier") as? String
            })
            #expect(ids.contains("privacy.autolock"))
            let markerValues = Native.elements(host.window.contentView).compactMap {
                Native.value($0, "accessibilityValue") as? String
            }
            #expect(markerValues.contains { $0.split(separator: " ").contains("privacy.autolock") })
            let menu = try await host.menu()
            #expect(menu.items.map(\.title) == ["privacy.idle.1", "privacy.idle.5", "privacy.idle.15"].map {
                Menus.localized($0, locale)
            })
            #expect(menu.items.map(\.state) == [.off, .on, .off])
            #expect(host.vault.revision == revision && host.panel == nil)
            try Native.snapshot(host.window, name: "autolock-\(locale)-\(scheme)")
            let scrolls = Native.elements(host.window.contentView).compactMap { $0 as? NSScrollView }
            let scroll = try #require(scrolls.first)
            let document = try #require(scroll.documentView)
            let end = NSRect(x: 0, y: document.isFlipped ? document.bounds.maxY - 1 : 0, width: 1, height: 1)
            document.scrollToVisible(end)
            scroll.reflectScrolledClipView(scroll.contentView)
            try await SystemPageHost.settle(host.window)
            try Native.snapshot(host.window, name: "autolock-bottom-\(locale)-\(scheme)")
            try await host.ready()
            _ = try await host.menu()
            #expect(host.vault.revision == revision && host.panel == nil)
        }
    }

    @Test(arguments: [false, true])
    func cancellationKeepsDurationAndLateAuthenticationCannotSave(inFlight: Bool) async throws {
        try await withHost { host in
            let original = host.store.value
            let menu = try await host.menu()
            await host.system.suspend()
            try Menus.dispatch(Menus.localized("privacy.idle.1", host.locale), in: menu)
            try await host.wait { host.panel != nil }
            if inFlight {
                _ = try await host.startSystemAuthentication()
                try await host.wait { await host.system.pendingRead != nil }
            }
            try await host.cancelPanel()
            if inFlight { await host.system.finishRead() }
            try await SystemPageHost.settle(host.window)
            #expect(host.store.value == original && host.vault.state == .locked)
            #expect(host.hasText(PrivacyError.cancelled.messageKey) && !host.hasText("privacy.settings.saved"))
            try host.assertValue(300)
            try host.assertEnabled(true)
            #expect(!host.vault.isAuthenticating && host.panel == nil)
        }
    }

    @Test func authenticationFailureRemainsInOriginalPanelUntilRetry() async throws {
        try await withHost { host in
            host.vault.lock()
            try await host.ready()
            let original = host.store.value
            await host.system.setReadError(.systemUnavailable)
            let menu = try await host.menu()
            try Menus.dispatch(Menus.localized("privacy.idle.1", host.locale), in: menu)
            let panel = try await host.startSystemAuthentication()
            try await host.wait { host.hasText(PrivacyError.systemUnavailable.messageKey, in: panel) }
            #expect(host.store.value == original && host.vault.state == .locked)
            #expect(!host.hasText("privacy.settings.saved") && host.panel === panel)
            try host.assertValue(300)
            try host.assertEnabled(false)
            await host.system.setReadError(nil)
            _ = try await host.startSystemAuthentication()
            try await host.wait { host.panel == nil && host.hasText("privacy.settings.saved") }
            try await host.ready()
            try host.assertValue(60)
            try host.assertEnabled(true)
            #expect(host.vault.isUnlocked)
        }
    }

    @Test func configurationSaveFailureKeepsValueAndAllowsRetry() async throws {
        try await withHost { host in
            let original = host.store.value
            let menu = try await host.menu()
            await host.system.suspend()
            try Menus.dispatch(Menus.localized("privacy.idle.1", host.locale), in: menu)
            _ = try await host.startSystemAuthentication()
            try await host.wait { await host.system.pendingRead != nil }
            host.store.saveError = PrivacyError.storageFailure
            await host.system.finishRead()
            try await host.wait { host.panel == nil && host.hasText(PrivacyError.storageFailure.messageKey) }
            try await host.ready()
            #expect(host.store.value == original && host.vault.isUnlocked)
            #expect(!host.hasText("privacy.settings.saved"))
            try host.assertValue(300)
            try host.assertEnabled(true)
            host.store.saveError = nil
            try Menus.dispatch(Menus.localized("privacy.idle.1", host.locale), in: menu)
            _ = try await host.startSystemAuthentication()
            try await host.wait { await host.system.pendingRead != nil }
            await host.system.finishRead()
            try await host.wait { host.panel == nil && host.hasText("privacy.settings.saved") }
            try await host.ready()
            try host.assertValue(60)
        }
    }

    @Test func externalValuesReadBackAndFallbackDisablesWholeGroup() async throws {
        try await withHost { host in
            for seconds in [60, 900, 300] {
                try host.vault.setIdleSeconds(seconds)
                try await SystemPageHost.settle(host.window)
                try host.assertValue(seconds)
                #expect(host.panel == nil && !host.hasText("privacy.settings.saved"))
                let data = try JSONEncoder().encode(host.store.value)
                let decoded = try JSONDecoder().decode(PrivacyConfiguration.self, from: data)
                try decoded.validate()
                #expect(decoded.idleSeconds == seconds)
                #expect(PrivacyVault(store: MemoryVaultConfigurationStore(decoded), systemKeys: host.system).idleSeconds == seconds)
            }
            for minutes in [1, 5, 15] {
                #expect(throws: PrivacyError.corruptData) { try host.vault.setIdleSeconds(minutes) }
            }
            let menu = try await host.menu()
            let original = host.store.value
            StoreHealth.shared.isUsingMemoryFallback = true
            try await SystemPageHost.settle(host.window)
            try host.assertEnabled(false)
            menu.performActionForItem(at: 0)
            try await SystemPageHost.settle(host.window)
            #expect(host.panel == nil && host.store.value == original)
            #expect(try host.fixture.context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        }
    }

    /// 只证明公共 formRow 的长字段布局，不作为生产认证链证据。
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func longFormRowLabel(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let window = fixture.window(Form {
            DaybookPicker("dev.controls.picker.long", selection: .constant(300), options: [
                DaybookPickerOption(60, "privacy.idle.1"), DaybookPickerOption(300, "privacy.idle.5"),
                DaybookPickerOption(900, "privacy.idle.15")
            ], layout: .formRow)
        }.formStyle(.grouped), locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try Menus.menu("dev.controls.picker.long", locale: locale, in: window)
        try Native.assertBounds([node], in: window)
        let popup = try #require(Native.elements(window.contentView).compactMap { $0 as? NSPopUpButton }.first)
        let frame = try Native.frame(node, in: window)
        #expect(popup.convert(popup.bounds, to: nil).contains(NSPoint(x: frame.midX, y: frame.midY)))
        _ = try await Menus.openAndEscape(node, in: window)
        try Native.snapshot(window, name: "autolock-long-\(locale)-\(scheme)")
    }
}
