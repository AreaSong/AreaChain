import Carbon
import Foundation
import Testing
@testable import AreaChain

@MainActor
struct ShortcutStoreTests {
    @Test func legacyOverlayKeySurvivesAndConflictsDisarmTheGlobalRegistration() throws {
        let name = "areachain.shortcut.store.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let custom = ShortcutChord(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | optionKey))
        custom.save(to: defaults)
        defaults.set(Int(custom.keyCode), forKey: ShortcutChord.pasteKeyCodeDefaultsKey)
        defaults.set(Int(custom.modifiers), forKey: ShortcutChord.pasteModifiersDefaultsKey)

        var registered: [UInt32: ShortcutChord] = [:]
        let center = HotKeyCenter(defaults: defaults, registration: HotKeyRegistration(
            register: { spec, id in
                registered[id] = spec
                return true
            },
            unregister: { registered.removeValue(forKey: $0) }
        ))
        let store = ShortcutStore(defaults: defaults, center: center)
        store.start()

        #expect(store.binding(for: .toggleOverlay).chord == custom)
        #expect(store.binding(for: .toggleOverlay).isArmed)
        #expect(!store.binding(for: .pasteToday).isArmed)
        #expect(registered[HotKeyCenter.toggleID] == custom)
        #expect(registered[HotKeyCenter.pasteID] == nil)

        let searchChord = ShortcutChord(keyCode: 0x0B, modifiers: ShortcutModifier.command | ShortcutModifier.shift)
        store.assign(searchChord, to: .search)
        #expect(store.binding(for: .search).isArmed)
        #expect(store.binding(for: .search).chord == searchChord)
        #expect(store.binding(for: .toggleOverlay).isArmed)
        #expect(registered[HotKeyCenter.toggleID] == custom)

        store.assign(custom, to: .pasteToday)
        #expect(store.binding(for: .pasteToday).isArmed)
        #expect(!store.binding(for: .toggleOverlay).isArmed)
        #expect(registered[HotKeyCenter.toggleID] == nil)
        #expect(registered[HotKeyCenter.pasteID] == custom)

        store.reset(.pasteToday)
        #expect(store.binding(for: .pasteToday).chord.isUnset)
        #expect(store.binding(for: .toggleOverlay).isArmed)
        #expect(registered[HotKeyCenter.toggleID] == custom)
        #expect(registered[HotKeyCenter.pasteID] == nil)
        #expect(defaults.object(forKey: ShortcutChord.pasteKeyCodeDefaultsKey) == nil)
    }

    @Test func missingGlobalHotKeysStayUnsetUntilRecorded() throws {
        let name = "areachain.shortcut.store.unset.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var registered: [UInt32: ShortcutChord] = [:]
        let center = HotKeyCenter(defaults: defaults, registration: HotKeyRegistration(
            register: { spec, id in
                registered[id] = spec
                return true
            },
            unregister: { registered.removeValue(forKey: $0) }
        ))
        let store = ShortcutStore(defaults: defaults, center: center)
        store.start()

        #expect(store.binding(for: .toggleOverlay).chord.isUnset)
        #expect(store.binding(for: .pasteToday).chord.isUnset)
        #expect(store.binding(for: .openWorkspaceHotKey).chord.isUnset)
        #expect(store.binding(for: .clipboardHistory).chord.isUnset)
        #expect(!store.binding(for: .toggleOverlay).isArmed)
        #expect(store.binding(for: .openWorkspace).chord == ShortcutAction.openWorkspace.defaultChord)
        #expect(store.binding(for: .openWorkspace).isArmed)
        #expect(registered.isEmpty)

        let workspace = ShortcutChord(keyCode: ShortcutKey.zero, modifiers: ShortcutModifier.command | ShortcutModifier.option)
        store.assign(workspace, to: .openWorkspaceHotKey)
        #expect(store.binding(for: .openWorkspaceHotKey).isArmed)
        #expect(registered[HotKeyCenter.workspaceID] == workspace)
        #expect(store.binding(for: .openWorkspace).isArmed)

        store.reset(.openWorkspaceHotKey)
        #expect(store.binding(for: .openWorkspaceHotKey).chord.isUnset)
        #expect(registered[HotKeyCenter.workspaceID] == nil)
        #expect(defaults.object(forKey: ShortcutChord.workspaceKeyCodeDefaultsKey) == nil)
    }

    @Test func failedGlobalRegistrationStaysDisarmedWithoutForgettingTheChord() throws {
        let name = "areachain.shortcut.store.failure.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let center = HotKeyCenter(defaults: defaults, registration: HotKeyRegistration(register: { _, _ in false }, unregister: { _ in }))
        let store = ShortcutStore(defaults: defaults, center: center)
        store.start()
        let chord = ShortcutChord(keyCode: 0x28, modifiers: ShortcutModifier.command)
        store.assign(chord, to: .toggleOverlay)
        #expect(store.binding(for: .toggleOverlay).chord == chord)
        #expect(!store.binding(for: .toggleOverlay).isArmed)
    }
}
