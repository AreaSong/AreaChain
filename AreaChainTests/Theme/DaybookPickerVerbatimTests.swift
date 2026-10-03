import AppKit
import SwiftUI
import Testing
@testable import AreaChain

extension DaybookPickerTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func verbatimLabelsKeepUUIDAndExactText(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = VerbatimPickerProbe(locale: locale)
        let window = fixture.window(VerbatimPickerView(state: state), scheme: scheme,
                                    size: NSSize(width: 360, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try Menus.menu("tags.merge.pickTarget", locale: locale, in: window)
        let menu = try await Menus.openAndEscape(node, in: window)
        #expect(state.writes.isEmpty)
        #expect(menu.items.map(\.title) == state.names + [Menus.localized("common.save", locale)])
        for index in state.names.indices {
            menu.performActionForItem(at: index)
            #expect(state.value == state.ids[index])
            #expect(state.writes.count == index + 1)
            #expect(menu.items.map(\.state) == menu.items.indices.map { $0 == index ? .on : .off })
            let shown = try #require(Native.value(node, "accessibilityValue") as? String)
            #expect(Array(shown.utf8) == Array(state.names[index].utf8))
            #expect(Array(menu.items[index].title.utf8) == Array(state.names[index].utf8))
        }
        // 第四、第五项同名，但选中身份不能退化成标题或位置。
        #expect(state.writes == state.ids.dropLast())
        state.value = state.ids[3]
        try await SystemPageHost.settle(window)
        #expect(menu.items[3].state == .on && menu.items[4].state == .off)
        try Native.assertBounds([node], in: window)
        try Native.snapshot(window, name: "picker-verbatim-\(locale)-\(scheme)")
    }

    @Test func verbatimRenameReorderLanguageAndStaleMenus() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = VerbatimPickerProbe(locale: "en")
        let window = fixture.window(VerbatimPickerView(state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try Menus.menu("tags.merge.pickTarget", in: window)
        let old = try await Menus.openAndEscape(node, in: window)
        state.value = state.ids[1]
        state.options = [.init(state.ids[1], verbatim: "改名 Renamed e\u{301} 🏷️"),
                         .init(state.ids[0], verbatim: "common.save")]
        try await SystemPageHost.settle(window)
        old.performActionForItem(at: 1)
        #expect(state.writes.isEmpty && state.value == state.ids[1])
        let renamed = try await Menus.openAndEscape(node, in: window)
        #expect(renamed.items.map(\.state) == [.on, .off])
        #expect(Array(renamed.items[0].title.utf8) == Array("改名 Renamed e\u{301} 🏷️".utf8))
        state.value = state.ids[0]
        for language in ["zh-Hans", "en"] {
            state.locale = language
            try await SystemPageHost.settle(window)
            let localized = try Menus.menu("tags.merge.pickTarget", locale: language, in: window)
            #expect(Native.value(localized, "accessibilityValue") as? String == "common.save")
            #expect(state.value == state.ids[0] && state.writes.isEmpty)
        }
        state.value = UUID()
        let missing = state.value
        try await SystemPageHost.settle(window)
        #expect(Native.value(node, "accessibilityValue") as? String == "Selection unavailable")
        state.options = []
        state.locale = "zh-Hans"
        try await SystemPageHost.settle(window)
        #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("picker.empty", "zh-Hans"))
        #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
        renamed.performActionForItem(at: 0)
        #expect(state.writes.isEmpty && state.value == missing)
        state.options = [.init(UUID(), verbatim: "common.save")]
        try await SystemPageHost.settle(window)
        #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("picker.unavailable", "zh-Hans"))
        old.performActionForItem(at: 0)
        #expect(state.writes.isEmpty && state.value == missing)
    }
}

@MainActor @Observable
private final class VerbatimPickerProbe {
    let ids = (0..<6).map { _ in UUID() }
    let names = ["common.save", "中文标签", "English # & < > \" \\ 🏷️ e\u{301}",
                 String(repeating: "合成长名称 Long synthetic name · ", count: 5),
                 String(repeating: "合成长名称 Long synthetic name · ", count: 5)]
    var value: UUID
    var writes: [UUID] = []
    var options: [DaybookPickerOption<UUID>] = []
    var locale: String

    init(locale: String) {
        self.locale = locale
        value = ids[0]
        options = zip(ids, names).map { .init($0, verbatim: $1) } + [.init(ids[5], "common.save")]
    }

    var binding: Binding<UUID> {
        Binding(get: { self.value }, set: { self.writes.append($0); self.value = $0 })
    }
}

private struct VerbatimPickerView: View {
    @Bindable var state: VerbatimPickerProbe
    var body: some View {
        DaybookPicker("tags.merge.pickTarget", selection: state.binding, options: state.options)
            .padding(DaybookSpacing.page)
            .environment(\.locale, Locale(identifier: state.locale))
    }
}
