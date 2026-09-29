import Carbon
import Foundation
import Testing
@testable import AreaChain

@MainActor
struct HotKeyCenterTests {
    @Test func conflictingPasteShortcutIsReallyUnregisteredAndCanBeRearmed() throws {
        let name = "areachain.hotkey.center.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var registered: [UInt32: HotKeySpec] = [:]
        let backend = HotKeyRegistration(register: { spec, id in
            registered[id] = spec
            return true
        }, unregister: { registered.removeValue(forKey: $0) })
        let center = HotKeyCenter(defaults: defaults, registration: backend)
        center.start()
        #expect(center.pasteIsArmed && center.toggleIsArmed)
        center.applyPaste(.fallback)
        #expect(!center.pasteIsArmed)
        #expect(registered[HotKeyCenter.pasteID] == nil)
        #expect(HotKeySpec.loadPaste(from: defaults) == .fallback)
        let changed = HotKeySpec(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey | shiftKey))
        center.apply(changed)
        #expect(center.pasteIsArmed)
        #expect(registered[HotKeyCenter.pasteID] == .fallback)
    }

    @Test func registrationFailuresAndDisabledCallbacksNeverPretendToBeArmed() throws {
        let name = "areachain.hotkey.failure.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let center = HotKeyCenter(defaults: defaults, registration: HotKeyRegistration(register: { _, _ in false }, unregister: { _ in }))
        center.start()
        #expect(!center.toggleIsArmed && !center.pasteIsArmed)
        var captures = 0
        let observer = NotificationCenter.default.addObserver(forName: .pasteClipboardCapture, object: nil, queue: .main) { _ in captures += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        center.dispatchHotKey(HotKeyCenter.pasteID)
        #expect(captures == 0)
        center.dispatchHotKey(HotKeyCenter.workspaceID)
        #expect(captures == 0)
    }

    @Test func workspaceHotKeyPostsRevealWhenArmed() throws {
        let name = "areachain.hotkey.workspace.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let center = HotKeyCenter(defaults: defaults, registration: HotKeyRegistration(register: { _, _ in true }, unregister: { _ in }))
        let chord = ShortcutChord(keyCode: ShortcutKey.zero, modifiers: ShortcutModifier.command | ShortcutModifier.option)
        center.applyResolved(
            toggle: .unset, armToggle: false,
            paste: .unset, armPaste: false,
            workspace: chord, armWorkspace: true
        )
        var reveals = 0
        let observer = NotificationCenter.default.addObserver(forName: .revealWorkspace, object: nil, queue: nil) { _ in reveals += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        center.dispatchHotKey(HotKeyCenter.workspaceID)
        #expect(reveals == 1)
        #expect(center.workspaceIsArmed)
        #expect(!center.toggleIsArmed && !center.pasteIsArmed)
    }
}
