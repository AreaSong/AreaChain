import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct MenuBarToolbarStateTests {
    @Test func selectingFilterDoesNotImmediatelyReopenUnderThePointer() {
        let toolbar = MenuBarToolbarState()
        toolbar.showFiltersFromHover()
        #expect(toolbar.isFiltering)
        toolbar.closeFilters()
        toolbar.showFiltersFromHover()
        #expect(!toolbar.isFiltering)
        toolbar.pointerLeftToolbar()
        toolbar.showFiltersFromHover()
        #expect(toolbar.isFiltering)
        toolbar.focusSearch()
        toolbar.pointerLeftToolbar()
        toolbar.showFiltersFromHover()
        #expect(!toolbar.isFiltering)
    }

    @Test func swiftUIKeyHandlersAlsoRespectToolbarMode() {
        let toolbar = MenuBarToolbarState()
        var selectedID: UUID? = UUID()
        var actions = 0
        let modifier = DayBoardKeyNavigationModifier(
            interaction: DayBoardInteraction(
                focusedTaskID: Binding(get: { selectedID }, set: { selectedID = $0 }),
                isKeyboardEnabled: { !toolbar.searchIsFocused && !toolbar.isFiltering }
            ),
            onNavigate: { _ in actions += 1 }, onToggle: { _ in actions += 1 },
            onDelete: { _ in actions += 1 }, onInspect: { _ in actions += 1 }
        )
        #expect(modifier.handle(.space) == .handled)
        #expect(actions == 1)
        toolbar.showFiltersFromHover()
        for key in [KeyEquivalent.space, .delete, .return, .upArrow, .downArrow] {
            #expect(modifier.handle(key) == .ignored)
        }
        toolbar.focusSearch()
        #expect(modifier.handle(.space) == .ignored)
        #expect(actions == 1)
    }

    @Test func changingToolbarContentsPreservesSearchAndDismissesCompletion() {
        let toolbar = MenuBarToolbarState()
        toolbar.searchText = "会议 #工"
        toolbar.focusSearch()
        toolbar.autocomplete.update(text: toolbar.searchText, cursorLocation: 5, availableTags: ["工作"])
        #expect(toolbar.autocomplete.isActive)

        for _ in 0..<20 {
            toolbar.showFilters()
            #expect(toolbar.isFiltering)
            #expect(!toolbar.searchIsFocused)
            #expect(!toolbar.autocomplete.isActive)
            #expect(toolbar.searchText == "会议 #工")
            toolbar.closeFilters()
            #expect(!toolbar.isFiltering)
        }
        #expect(toolbar.isSearching)
        toolbar.focusSearch()
        #expect(toolbar.searchIsFocused)
    }

    @Test func clearingSearchDoesNotExitFilterMode() {
        let toolbar = MenuBarToolbarState()
        toolbar.searchText = "#工作 !p1"
        toolbar.showFilters()
        toolbar.clearSearch()
        #expect(toolbar.searchText.isEmpty)
        #expect(toolbar.isFiltering)
        #expect(!toolbar.isSearching)
        toolbar.focusSearch()
        #expect(!toolbar.isFiltering && toolbar.searchIsFocused)
    }

    @Test func searchCompletionUsesSearchCapabilitiesAndResetsUnsupportedTriggers() {
        let toolbar = MenuBarToolbarState()
        toolbar.autocomplete.update(text: "#", cursorLocation: 1, availableTags: ["工作"])
        #expect(toolbar.autocomplete.candidates.first?.subtitle == "syntax.search.tag")
        toolbar.autocomplete.update(text: "@", cursorLocation: 1)
        #expect(!toolbar.autocomplete.isActive)
        #expect(toolbar.autocomplete.candidates.isEmpty)
        toolbar.autocomplete.update(text: "!", cursorLocation: 1)
        toolbar.autocomplete.selectPrevious()
        #expect(toolbar.autocomplete.selectedCandidate()?.insertText == "!p4 ")
    }

    @Test func searchAndFilterFocusDisableTheUnderlyingListInteraction() {
        let toolbar = MenuBarToolbarState()
        let list = DayBoardList(
            dayKey: "2026-09-12", routines: [], checks: [], todos: [],
            config: DayBoardListConfig(interaction: DayBoardInteraction(
                isKeyboardEnabled: { !toolbar.searchIsFocused && !toolbar.isFiltering }
            ))
        )
        #expect(list.config.interaction.isKeyboardEnabled())
        toolbar.focusSearch()
        #expect(!list.config.interaction.isKeyboardEnabled())
        toolbar.showFilters()
        #expect(!list.config.interaction.isKeyboardEnabled())
        toolbar.closeFilters()
        #expect(list.config.interaction.isKeyboardEnabled())
    }
}
