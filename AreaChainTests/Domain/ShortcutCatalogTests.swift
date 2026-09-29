import Foundation
import Testing
@testable import AreaChain

struct ShortcutCatalogTests {
    private static let commandShiftA = ShortcutChord(
        keyCode: ShortcutKey.a,
        modifiers: ShortcutModifier.command | ShortcutModifier.shift
    )

    @Test func commandDefaultsAreUniqueAndGlobalHotKeysStartUnset() {
        let commands = ShortcutAction.allCases.filter { !$0.usesSystemHotKey }
        let chords = commands.map(\.defaultChord)
        #expect(Set(chords).count == chords.count)
        for chord in chords {
            #expect(chord.isBindable)
        }
        for action in ShortcutAction.allCases where action.usesSystemHotKey {
            #expect(action.defaultChord.isUnset)
            #expect(!action.defaultChord.isBindable)
        }
        #expect(ShortcutAction.search.defaultChord.displayName == "⌘F")
        #expect(ShortcutAction.openWorkspace.defaultChord.displayName == "⌘0")
        #expect(ShortcutAction.openSettings.defaultChord.displayName == "⌘,")
        #expect(ShortcutAction.commitDiary.defaultChord.keyCode == ShortcutKey.returnKey)
    }

    @Test func loadOrderKeepsOverlayWhenPasteWasSavedOnTheSameChord() {
        let chord = Self.commandShiftA
        let resolved = ShortcutCatalog.resolve(stored: [
            .toggleOverlay: chord,
            .pasteToday: chord
        ])
        #expect(resolved[.toggleOverlay]?.isArmed == true)
        #expect(resolved[.pasteToday]?.isArmed == false)
        #expect(resolved[.pasteToday]?.chord == chord)
        #expect(resolved[.openWorkspaceHotKey]?.chord.isUnset == true)
        #expect(resolved[.openWorkspaceHotKey]?.isArmed == false)
    }

    @Test func systemHotKeyDoesNotDisarmTheSameInAppShortcut() {
        let chord = ShortcutAction.search.defaultChord
        let resolved = ShortcutCatalog.resolve(
            stored: [
                .toggleOverlay: chord,
                .search: chord
            ],
            preferred: .toggleOverlay
        )
        #expect(resolved[.toggleOverlay]?.isArmed == true)
        #expect(resolved[.search]?.isArmed == true)
        #expect(resolved[.search]?.chord == chord)
    }

    @Test func latestGlobalAssignmentWinsAndDisarmsThePreviousGlobalOwner() {
        let chord = Self.commandShiftA
        let resolved = ShortcutCatalog.resolve(
            stored: [
                .toggleOverlay: chord,
                .pasteToday: chord
            ],
            preferred: .pasteToday
        )
        #expect(resolved[.pasteToday]?.isArmed == true)
        #expect(resolved[.toggleOverlay]?.isArmed == false)
        #expect(resolved[.toggleOverlay]?.chord == chord)
    }

    @Test func unusableStoredChordFallsBackToItsDefault() {
        let shiftOnly = ShortcutChord(keyCode: ShortcutKey.a, modifiers: ShortcutModifier.shift)
        let resolved = ShortcutCatalog.resolve(stored: [
            .search: shiftOnly,
            .toggleOverlay: shiftOnly
        ])
        #expect(resolved[.search]?.chord == ShortcutAction.search.defaultChord)
        #expect(resolved[.search]?.isArmed == true)
        #expect(resolved[.toggleOverlay]?.chord.isUnset == true)
        #expect(resolved[.toggleOverlay]?.isArmed == false)
    }

    @Test func resetReclaimsTheGlobalChordAndRearmsThePreviousOwner() {
        let chord = Self.commandShiftA
        var stored: [ShortcutAction: ShortcutChord] = [
            .toggleOverlay: chord,
            .pasteToday: chord
        ]
        var resolved = ShortcutCatalog.resolve(stored: stored, preferred: .pasteToday)
        #expect(resolved[.toggleOverlay]?.isArmed == false)
        stored[.pasteToday] = .unset
        resolved = ShortcutCatalog.resolve(stored: stored, preferred: .pasteToday)
        #expect(resolved[.pasteToday]?.chord.isUnset == true)
        #expect(resolved[.pasteToday]?.isArmed == false)
        #expect(resolved[.toggleOverlay]?.isArmed == true)
    }

    @Test func unsetChordsDoNotClaimEachOther() {
        let resolved = ShortcutCatalog.resolve(stored: [:])
        let globals = ShortcutAction.allCases.filter(\.usesSystemHotKey)
        #expect(globals.count == 4)
        for action in globals {
            #expect(resolved[action]?.chord.isUnset == true)
            #expect(resolved[action]?.isArmed == false)
        }
    }
}
