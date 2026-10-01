import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct ShortcutsPageTests {
    private static var retained: [ModelContainer] = []

    @Test func shortcutsPageListsEveryRebindableAction() async throws {
        let name = "areachain.shortcut.page.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let center = HotKeyCenter(defaults: defaults, registration: HotKeyRegistration(register: { _, _ in true }, unregister: { _ in }))
        let store = ShortcutStore(defaults: defaults, center: center)
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retained.append(container)
        let window = SystemPageHost.window(
            ShortcutsSettingsView(store: store),
            container: container,
            scheme: .light,
            locale: "zh-Hans",
            size: DaybookMetrics.Window.workspaceMinSize
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let ids = SystemPageHost.identifiers(in: window)
        #expect(ids.contains("shortcuts.page"))
        #expect(ids.contains("shortcuts.scope"))
        #expect(ids.contains("shortcuts.resetAll"))
        for action in ShortcutAction.allCases {
            #expect(ids.contains("shortcut.\(action.rawValue)"))
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func recorderCancelsCommitsAndResetsOnlyItsItem(locale: String, scheme: ColorScheme) async throws {
        let f = try SettingsButtonTestSupport()
        defer { f.cleanup() }
        let trace = RegistrationTrace()
        let store = makeStore(f, trace: trace)
        let other = ShortcutChord(keyCode: 0x28, modifiers: ShortcutModifier.command | ShortcutModifier.option)
        store.assign(other, to: .pasteToday)
        let window = f.window(Form { ShortcutRecorder(action: .toggleOverlay, store: store) }.formStyle(.grouped),
                              locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try SettingsButtonTestSupport.snapshot(window, name: "shortcut-unset-\(locale)-\(scheme)")
        try await record(in: window)
        try await record(in: window)
        _ = try SettingsButtonTestSupport.button("hotkey.listen", locale: locale, in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "shortcut-listening-\(locale)-\(scheme)")
        try await SettingsButtonTestSupport.key(UInt16(ShortcutKey.escape), in: window)
        #expect(!isListening(locale: locale, in: window))
        #expect(store.binding(for: .toggleOverlay).chord.isUnset)
        #expect(store.binding(for: .pasteToday).chord == other)
        try await record(in: window)
        let calls = trace.registerCalls
        try await SettingsButtonTestSupport.key(0x0B, flags: [.command, .option, .shift, .control], in: window)
        let chord = ShortcutChord(keyCode: 0x0B, modifiers: ShortcutModifier.command | ShortcutModifier.option
                                  | ShortcutModifier.shift | ShortcutModifier.control)
        #expect(store.binding(for: .toggleOverlay).chord == chord)
        #expect(!isListening(locale: locale, in: window))
        #expect(store.binding(for: .pasteToday).chord == other)
        #expect(trace.registered[HotKeyCenter.toggleID] == chord)
        #expect(trace.registerCalls == calls + 2)
        try SettingsButtonTestSupport.assertBounds(SettingsButtonTestSupport.buttons(in: window), in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "shortcut-set-\(locale)-\(scheme)")
        try await record(in: window)
        try SettingsButtonTestSupport.assertBounds(SettingsButtonTestSupport.buttons(in: window), in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "shortcut-rerecord-\(locale)-\(scheme)")
        try await SettingsButtonTestSupport.key(UInt16(ShortcutKey.escape), in: window)
        #expect(store.binding(for: .toggleOverlay).chord == chord)
        let reset = try SettingsButtonTestSupport.button("shortcut.reset", locale: locale, in: window)
        try await SettingsButtonTestSupport.click(reset, in: window)
        #expect(store.binding(for: .toggleOverlay).chord.isUnset)
        #expect(store.binding(for: .pasteToday).chord == other)
        #expect(trace.registered[HotKeyCenter.toggleID] == nil)
        #expect(trace.unregistered.contains(HotKeyCenter.toggleID))
    }

    @Test func removingListeningRecorderReleasesMonitor() async throws {
        let f = try SettingsButtonTestSupport()
        defer { f.cleanup() }
        let trace = RegistrationTrace()
        let store = makeStore(f, trace: trace)
        let window = f.window(ShortcutRecorder(action: .toggleOverlay, store: store).padding())
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await record(in: window)
        window.contentView = NSHostingView(rootView: Text("Synthetic replacement"))
        try await SystemPageHost.settle(window)
        let calls = trace.registerCalls
        // 若 onDisappear 未卸载监听器，此组合会写回原 store 并触发 fake 注册。
        try await SettingsButtonTestSupport.key(0x0B, flags: [.command, .option], in: window)
        #expect(store.binding(for: .toggleOverlay).chord.isUnset)
        #expect(trace.registerCalls == calls)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func failedRecordingKeepsResetAndLabelVisible(locale: String, scheme: ColorScheme) async throws {
        let f = try SettingsButtonTestSupport()
        defer { f.cleanup() }
        let trace = RegistrationTrace()
        trace.succeeds = false
        let store = makeStore(f, trace: trace)
        let window = f.window(Form { ShortcutRecorder(action: .toggleOverlay, store: store) }.formStyle(.grouped),
                              locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await record(in: window)
        try await SettingsButtonTestSupport.key(0x0B, flags: [.command, .option, .shift, .control], in: window)
        #expect(!store.binding(for: .toggleOverlay).isArmed)
        #expect(!store.binding(for: .toggleOverlay).chord.isUnset)
        #expect(!isListening(locale: locale, in: window))
        _ = try SettingsButtonTestSupport.button("shortcut.reset", locale: locale, in: window)
        try SettingsButtonTestSupport.assertBounds(SettingsButtonTestSupport.buttons(in: window), in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "shortcut-failed-\(locale)-\(scheme)")
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func resetAllUsesProductionPageAndClearsOnlyIsolatedBindings(locale: String, scheme: ColorScheme) async throws {
        let f = try SettingsButtonTestSupport()
        defer { f.cleanup() }
        let trace = RegistrationTrace()
        let store = makeStore(f, trace: trace)
        let custom = ShortcutChord(keyCode: 0x0B, modifiers: ShortcutModifier.command | ShortcutModifier.option)
        store.assign(custom, to: .toggleOverlay)
        store.assign(custom, to: .search)
        f.defaults.set("preserved", forKey: "synthetic.unrelated")
        let window = f.window(ShortcutsSettingsView(store: store), locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try SettingsButtonTestSupport.snapshot(window, name: "shortcuts-page-\(locale)-\(scheme)")
        let reset = try SettingsButtonTestSupport.button("shortcut.resetAll", locale: locale, in: window)
        try await SettingsButtonTestSupport.reveal(reset, in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "shortcuts-reset-\(locale)-\(scheme)")
        let visible = try SettingsButtonTestSupport.button("shortcut.resetAll", locale: locale, in: window)
        try await SettingsButtonTestSupport.click(visible, in: window)
        for action in ShortcutAction.allCases {
            #expect(store.binding(for: action).chord == action.defaultChord)
        }
        #expect(trace.registered.isEmpty)
        #expect(f.defaults.string(forKey: "synthetic.unrelated") == "preserved")
        let restored = makeStore(f, trace: trace)
        for action in ShortcutAction.allCases {
            #expect(restored.binding(for: action).chord == action.defaultChord)
        }
    }

    private func record(in window: NSWindow) async throws {
        let button = try SettingsButtonTestSupport.button("shortcut.record.toggleOverlay", in: window)
        try await SettingsButtonTestSupport.click(button, in: window)
    }

    private func isListening(locale: String, in window: NSWindow) -> Bool {
        let label = L10n.string("hotkey.listen", locale: Locale(identifier: locale))
        return SettingsButtonTestSupport.buttons(in: window).contains {
            SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == label
                || SettingsButtonTestSupport.value($0, "accessibilityTitle") as? String == label
        }
    }

    private func makeStore(_ f: SettingsButtonTestSupport, trace: RegistrationTrace) -> ShortcutStore {
        let center = HotKeyCenter(defaults: f.defaults, registration: HotKeyRegistration(register: { chord, id in
            trace.registerCalls += 1
            if trace.succeeds { trace.registered[id] = chord }
            return trace.succeeds
        }, unregister: { id in
            trace.unregistered.append(id)
            trace.registered.removeValue(forKey: id)
        }))
        let store = ShortcutStore(defaults: f.defaults, center: center)
        store.start()
        return store
    }

    private final class RegistrationTrace {
        var succeeds = true
        var registerCalls = 0
        var registered: [UInt32: ShortcutChord] = [:]
        var unregistered: [UInt32] = []
    }

}
