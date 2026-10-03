import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookSegmentedControlTests {
    typealias Native = SettingsButtonTestSupport

    @Test func identityReorderExternalRejectedAndDisabled() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SegmentProbe()
        let window = fixture.window(SegmentProbeView(state: state), size: NSSize(width: 380, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        #expect(state.writes.isEmpty)
        try expectSelection([true, false], in: window)
        try await Native.click(nodes(window)[1], in: window)
        #expect(state.value == .second && state.writes == [.second])
        try expectSelection([false, true], in: window)
        try await Native.click(nodes(window)[1], in: window)
        #expect(state.writes == [.second, .second])
        state.options.reverse()
        state.locale = "zh-Hans"
        try await SystemPageHost.settle(window)
        try expectSelection([true, false], in: window)
        #expect(state.writes.count == 2)
        state.value = .first
        try await SystemPageHost.settle(window)
        try expectSelection([false, true], in: window)
        state.reject = true
        try press(nodes(window)[0])
        try await SystemPageHost.settle(window)
        #expect(state.value == .first && state.writes.count == 3)
        try expectSelection([false, true], in: window)
        state.disabled = true
        try await SystemPageHost.settle(window)
        try await Native.click(nodes(window)[0], in: window)
        try press(nodes(window)[0])
        try await SystemPageHost.settle(window)
        #expect(state.writes.count == 3)
        state.value = .missing
        try await SystemPageHost.settle(window)
        try expectSelection([false, false], in: window)
        state.options = []
        try await SystemPageHost.settle(window)
        #expect(nodes(window).isEmpty && state.writes.count == 3 && state.value == .missing)
    }

    @Test func independentStrongTypesRapidSwitchRebuildAndUnmount() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SegmentProbe()
        let window = fixture.window(SegmentProbeView(state: state, secondInstance: true))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for _ in 0..<8 {
            try press(nodes(window)[1])
            try await Task.sleep(for: .milliseconds(15))
            try press(nodes(window)[0])
            try await Task.sleep(for: .milliseconds(15))
        }
        #expect(state.writes.count == 16 && state.value == .first && state.other == 7)
        try press(nodes(window)[3])
        try await SystemPageHost.settle(window)
        #expect(state.other == 9 && state.otherWrites == [9] && state.writes.count == 16)
        state.generation += 1
        try await SystemPageHost.settle(window)
        try expectSelection([true, false, false, true], in: window)
        state.mounted = false
        try await SystemPageHost.settle(window)
        try await Task.sleep(for: .milliseconds(500))
        #expect(nodes(window).isEmpty && state.writes.count == 16 && state.otherWrites == [9])
        state.mounted = true
        try await SystemPageHost.settle(window)
        try expectSelection([true, false, false, true], in: window)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func localizedHelpAndCompactLongLabels(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SegmentProbe()
        state.locale = locale
        state.options = [.init(.first, "tab.tasks", help: "segmented.bar.tasks.help"),
                         .init(.second, "tab.diary", help: "segmented.bar.diary.help")]
        let window = fixture.window(SegmentProbeView(state: state), scheme: scheme,
                                    size: NSSize(width: 200, height: 120))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let buttons = nodes(window)
        #expect(buttons.count == 2)
        for (index, key) in ["tasks", "diary"].enumerated() {
            #expect(Native.value(buttons[index], "accessibilityLabel") as? String ==
                    localized("tab." + key, locale: locale))
            #expect(Native.value(buttons[index], "accessibilityHelp") as? String ==
                    localized("segmented.bar." + key + ".help", locale: locale))
        }
        try Native.assertBounds(buttons, in: window)
        try Native.snapshot(window, name: "segment-\(locale)-\(scheme)")
        state.options = [.init(.first, "dev.controls.picker.long"), .init(.second, "dev.controls.toggle.longLabel")]
        try await SystemPageHost.settle(window)
        try Native.assertBounds(nodes(window), in: window)
        #expect(state.writes.isEmpty)
        try Native.snapshot(window, name: "segment-long-\(locale)-\(scheme)")
    }

    @Test func motionPolicyPreservesBaseline() {
        #expect(DaybookMotion.segmented(true) == nil)
        #expect(DaybookMotion.segmented(false) == .spring(response: 0.28, dampingFraction: 0.75))
    }

    private func localized(_ key: String, locale: String) -> String {
        L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
    }

    func nodes(_ window: NSWindow) -> [NSObject] {
        Native.buttons(in: window).sorted {
            let left = (try? Native.frame($0, in: window)) ?? .zero
            let right = (try? Native.frame($1, in: window)) ?? .zero
            return abs(left.midY - right.midY) > 2 ? left.midY > right.midY : left.minX < right.minX
        }
    }

    func expectSelection(_ selected: [Bool], in window: NSWindow) throws {
        let buttons = nodes(window)
        try #require(buttons.count == selected.count)
        for (node, expected) in zip(buttons, selected) {
            #expect((node.value(forKey: "accessibilitySelected") as? NSNumber)?.boolValue == expected)
        }
    }

    func press(_ node: NSObject) throws {
        let action = NSSelectorFromString("accessibilityPerformPress")
        try #require(node.responds(to: action))
        _ = node.perform(action)
    }
}

@MainActor @Observable
final class SegmentProbe {
    enum Value: Hashable { case first, second, missing }
    var value = Value.first
    var other = 7
    var writes: [Value] = []
    var otherWrites: [Int] = []
    var reject = false
    var disabled = false
    var mounted = true
    var generation = 0
    var locale = "en"
    var options: [DaybookSegmentOption<Value>] = [.init(.first, "common.save"), .init(.second, "common.save")]
    var binding: Binding<Value> {
        Binding(get: { self.value }, set: { self.writes.append($0); if !self.reject { self.value = $0 } })
    }
}

private struct SegmentProbeView: View {
    @Bindable var state: SegmentProbe
    var secondInstance = false
    var body: some View {
        VStack {
            if state.mounted {
                DaybookSegmentedControl(selection: state.binding, options: state.options)
                    .id(state.generation)
                if secondInstance {
                    DaybookSegmentedControl(selection: Binding(get: { state.other }, set: {
                        state.otherWrites.append($0); state.other = $0
                    }), options: [.init(7, "common.save"), .init(9, "common.save")])
                }
            }
        }
        .padding(12)
        .background(DaybookPalette.fill.page)
        .disabled(state.disabled)
        .environment(\.locale, Locale(identifier: state.locale))
        // 既有宿主默认禁止动效；本测试保留生产动画事务和实际等待。
        .transaction { $0.disablesAnimations = false }
    }
}
