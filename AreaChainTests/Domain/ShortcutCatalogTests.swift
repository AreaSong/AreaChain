import Foundation
import Testing
@testable import AreaChain

struct ShortcutCatalogTests {
    @Test func defaultsAreUniqueAndBindable() {
        let chords = ShortcutAction.allCases.map(\.defaultChord)
        #expect(Set(chords).count == chords.count)
        for chord in chords {
            #expect(chord.isBindable)
        }
        #expect(ShortcutAction.toggleOverlay.defaultChord.displayName == "⌘⇧A")
        #expect(ShortcutAction.pasteToday.defaultChord.displayName == "⌘⇧V")
        #expect(ShortcutAction.search.defaultChord.displayName == "⌘F")
        #expect(ShortcutAction.openSettings.defaultChord.displayName == "⌘,")
        #expect(ShortcutAction.commitDiary.defaultChord.keyCode == ShortcutKey.returnKey)
    }

    @Test func loadOrderKeepsOverlayWhenPasteWasSavedOnTheSameChord() {
        let chord = ShortcutAction.toggleOverlay.defaultChord
        let resolved = ShortcutCatalog.resolve(stored: [
            .toggleOverlay: chord,
            .pasteToday: chord
        ])
        #expect(resolved[.toggleOverlay]?.isArmed == true)
        #expect(resolved[.pasteToday]?.isArmed == false)
        #expect(resolved[.pasteToday]?.chord == chord)
    }

    @Test func latestAssignmentWinsAndDisarmsThePreviousOwner() {
        let chord = ShortcutAction.toggleOverlay.defaultChord
        let resolved = ShortcutCatalog.resolve(
            stored: [
                .toggleOverlay: chord,
                .search: chord
            ],
            preferred: .search
        )
        #expect(resolved[.search]?.isArmed == true)
        #expect(resolved[.toggleOverlay]?.isArmed == false)
        #expect(resolved[.pasteToday]?.isArmed == true)
    }

    @Test func unusableStoredChordFallsBackToItsDefault() {
        let shiftOnly = ShortcutChord(keyCode: ShortcutKey.a, modifiers: ShortcutModifier.shift)
        let resolved = ShortcutCatalog.resolve(stored: [.search: shiftOnly])
        #expect(resolved[.search]?.chord == ShortcutAction.search.defaultChord)
        #expect(resolved[.search]?.isArmed == true)
    }

    @Test func resetReclaimsTheDefaultAndRearmsThePreviousOwner() {
        let overlay = ShortcutAction.toggleOverlay.defaultChord
        var stored: [ShortcutAction: ShortcutChord] = [.search: overlay]
        var resolved = ShortcutCatalog.resolve(stored: stored, preferred: .search)
        #expect(resolved[.toggleOverlay]?.isArmed == false)
        stored[.search] = ShortcutAction.search.defaultChord
        resolved = ShortcutCatalog.resolve(stored: stored, preferred: .search)
        #expect(resolved[.search]?.chord == ShortcutAction.search.defaultChord)
        #expect(resolved[.search]?.isArmed == true)
        #expect(resolved[.toggleOverlay]?.isArmed == true)
    }
}
