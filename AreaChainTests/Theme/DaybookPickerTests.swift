import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookPickerTests {
    typealias Native = SettingsButtonTestSupport
    typealias Menus = MenuButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"])
    func bindingIdentityRejectionAndLifetime(locale: String) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = PickerProbe()
        let window = fixture.window(PickerProbeView(state: state), locale: locale)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try Menus.menu("clipboard.searchMode", locale: locale, in: window)
        #expect(state.writes.isEmpty)
        let menu = try await Menus.openAndEscape(node, in: window)
        #expect(state.writes.isEmpty)
        try await PickerNativeTestSupport.accessibilityOpenAndEscape(node, in: window)
        #expect(state.writes.isEmpty)
        #expect(menu.items.map(\.state) == [.on, .off])
        try Menus.dispatch(Menus.localized("clipboard.searchMode.mixed", locale), in: menu)
        #expect(state.writes == [11], "当前项仍提交一次")
        try Menus.dispatch(Menus.localized("clipboard.searchMode.exact", locale), in: menu)
        #expect(state.value == 99 && state.writes == [11, 99])
        state.value = 11
        try await SystemPageHost.settle(window)
        #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("clipboard.searchMode.mixed", locale))
        state.reject = true
        try await SystemPageHost.settle(window)
        try Menus.dispatch(Menus.localized("clipboard.searchMode.exact", locale), in: menu)
        #expect(state.value == 11 && state.writes == [11, 99, 99])
        #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("clipboard.searchMode.mixed", locale))
        #expect(menu.items.map(\.state) == [.on, .off])
        try await PickerNativeTestSupport.keyboardSelection(node, moveDown: true, in: window)
        #expect(state.value == 11 && state.writes == [11, 99, 99, 99])
        #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("clipboard.searchMode.mixed", locale))
        state.disabled = true
        try await SystemPageHost.settle(window)
        #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
        menu.performActionForItem(at: 1)
        try await Native.click(node, in: window)
        #expect(state.writes == [11, 99, 99, 99])
        state.disabled = false
        state.reject = false
        try await SystemPageHost.settle(window)
        window.contentView?.removeFromSuperview()
        window.contentView = nil
        menu.performActionForItem(at: 1)
        #expect(state.writes == [11, 99, 99, 99], "拆卸后迟到菜单动作不能写入")
    }

    @Test func absentEmptyReorderedAndDuplicateLabels() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = PickerProbe()
        state.value = 404
        let window = fixture.window(PickerProbeView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try Menus.menu("clipboard.searchMode", in: window)
        #expect(state.writes.isEmpty && state.value == 404)
        #expect(Native.value(node, "accessibilityValue") as? String == "Selection unavailable")
        let oldMenu = try await Menus.openAndEscape(node, in: window)
        #expect(oldMenu.items.allSatisfy { $0.state == .off })
        #expect(!oldMenu.items[0].isEnabled)
        try Menus.dispatch("Case sensitive", in: oldMenu)
        #expect(state.writes == [99] && state.value == 99)
        state.options = [.init(99, "clipboard.searchMode.mixed"), .init(11, "clipboard.searchMode.mixed")]
        try await SystemPageHost.settle(window)
        oldMenu.performActionForItem(at: 0)
        #expect(state.writes == [99], "旧菜单不能按旧位置映射新选项")
        let menu = try await Menus.openAndEscape(node, in: window)
        #expect(menu.items.map(\.state) == [.on, .off])
        try Menus.dispatch("Fuzzy", occurrence: 1, in: menu)
        #expect(state.value == 11 && state.writes == [99, 11])
        state.options = []
        try await SystemPageHost.settle(window)
        #expect(Native.value(node, "accessibilityValue") as? String == "No options")
        #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
        try await Native.click(node, in: window)
        #expect(state.value == 11 && state.writes == [99, 11])
    }

    @Test(arguments: ClipboardOptionsConsumerTests.environments)
    func longLabelsAndGallery(environment: (String, ColorScheme)) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = PickerProbe()
        let window = fixture.window(DaybookPicker("dev.controls.picker.long", selection: state.binding,
            options: [.init(11, "dev.controls.picker.long"), .init(99, "clipboard.searchMode.exact")])
                .padding(DaybookSpacing.sm).background(DaybookPalette.fill.page),
            locale: environment.0, scheme: environment.1, size: NSSize(width: 320, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try Menus.menu("dev.controls.picker.long", locale: environment.0, in: window)
        try Native.assertBounds([node], in: window)
        let menu = try await Menus.openAndEscape(node, in: window)
        #expect(menu.items[0].title == Menus.localized("dev.controls.picker.long", environment.0))
        try Native.snapshot(window, name: "picker-long-\(environment.0)-\(environment.1)")
        let gallery = fixture.window(DaybookControlsPreview(localeID: environment.0,
            dark: environment.1 == .dark, longLabels: true), locale: environment.0, scheme: environment.1, size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(gallery) }
        try await NativeSyntaxUI.prepareFocus(in: gallery)
        try await SystemPageHost.settle(gallery)
        let pickers = Menus.menus(in: gallery)
        #expect(pickers.count >= 4, "原控制面板语言 Picker 仍在")
        let search = try Menus.menu("clipboard.searchMode", locale: environment.0, in: gallery)
        let old = Native.value(search, "accessibilityValue") as? String
        try await Native.click(Native.button("preview.picker.external", locale: environment.0, in: gallery), in: gallery)
        #expect(Native.value(search, "accessibilityValue") as? String != old)
        try Native.snapshot(gallery, name: "picker-gallery-\(environment.0)-\(environment.1)")
    }
}

@MainActor @Observable
final class PickerProbe {
    var value = 11
    var writes: [Int] = []
    var reject = false
    var disabled = false
    var options: [DaybookPickerOption<Int>] = [.init(11, "clipboard.searchMode.mixed"), .init(99, "clipboard.searchMode.exact")]
    var binding: Binding<Int> {
        Binding(get: { self.value }, set: { self.writes.append($0); if !self.reject { self.value = $0 } })
    }
}

private struct PickerProbeView: View {
    @Bindable var state: PickerProbe
    var body: some View {
        DaybookPicker("clipboard.searchMode", selection: state.binding, options: state.options)
            .disabled(state.disabled)
    }
}
