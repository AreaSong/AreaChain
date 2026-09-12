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
    }
}
