import AppKit
import Testing
@testable import AreaChain

@MainActor
struct MenuBarSearchShortcutTests {
    @Test func searchFollowsTheBindingInsteadOfAHardCodedCommandF() throws {
        let toolbar = MenuBarToolbarState()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let popover = MenuBarPopoverView(toolbar: toolbar, composer: BoardComposerSession(vault: vault),
                                        filterSession: BoardFilterSession())
        let defaultSearch = ShortcutBinding(chord: ShortcutAction.search.defaultChord, isArmed: true)
        let commandF = try keyEvent(characters: "f", modifiers: .command, keyCode: 3)
        let shifted = try keyEvent(characters: "f", modifiers: [.command, .shift], keyCode: 3)
        let optionS = try keyEvent(characters: "s", modifiers: .option, keyCode: UInt16(ShortcutKey.s))

        let rebound = ShortcutBinding(
            chord: ShortcutChord(keyCode: ShortcutKey.s, modifiers: ShortcutModifier.option),
            isArmed: true
        )
        #expect(popover.handleTabKeyDown(commandF, search: rebound) != nil)
        #expect(!toolbar.searchIsFocused)
        #expect(popover.handleTabKeyDown(optionS, search: rebound) == nil)
        #expect(toolbar.searchIsFocused)

        toolbar.searchIsFocused = false
        let disarmed = ShortcutBinding(chord: ShortcutAction.search.defaultChord, isArmed: false)
        #expect(popover.handleTabKeyDown(commandF, search: disarmed) != nil)
        #expect(!toolbar.searchIsFocused)

        #expect(popover.handleTabKeyDown(shifted, search: defaultSearch) != nil)
        #expect(!toolbar.searchIsFocused)
        #expect(popover.handleTabKeyDown(commandF, search: defaultSearch) == nil)
        #expect(toolbar.searchIsFocused)
    }

    private func keyEvent(characters: String, modifiers: NSEvent.ModifierFlags, keyCode: UInt16) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0,
            context: nil, characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: keyCode
        ))
    }
}
