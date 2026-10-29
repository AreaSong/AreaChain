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

    @Test func explicitFilterToggleRespectsStateAndSearchFocus() {
        let toolbar = MenuBarToolbarState()
        toolbar.showFilters()
        #expect(toolbar.isFiltering)
        toolbar.closeFilters()
        #expect(!toolbar.isFiltering)
        toolbar.toggleFilters()
        #expect(toolbar.isFiltering)
        toolbar.toggleFilters()
        #expect(!toolbar.isFiltering)
        toolbar.focusSearch()
        #expect(!toolbar.isFiltering)
        #expect(toolbar.searchIsFocused)
        toolbar.showFilters()
        #expect(toolbar.isFiltering)
        #expect(!toolbar.searchIsFocused)
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
        toolbar.showFilters()
        for key in [KeyEquivalent.space, .delete, .return, .upArrow, .downArrow] {
            #expect(modifier.handle(key) == .ignored)
        }
        toolbar.focusSearch()
        #expect(modifier.handle(.space) == .ignored)
        #expect(actions == 1)
    }

    /// 搜索文字由统一搜索控制器持有，工具栏只剩“正在搜索”（桥接维护的 unifiedActive）与焦点。
    @Test func changingToolbarContentsPreservesSearch() {
        let toolbar = MenuBarToolbarState()
        toolbar.unifiedActive = true
        toolbar.focusSearch()

        for _ in 0..<20 {
            toolbar.showFilters()
            #expect(toolbar.isFiltering)
            #expect(!toolbar.searchIsFocused)
            #expect(toolbar.isSearching)
            toolbar.closeFilters()
            #expect(!toolbar.isFiltering)
        }
        #expect(toolbar.isSearching)
        toolbar.focusSearch()
        #expect(toolbar.searchIsFocused)
    }

    @Test func clearingSearchDoesNotExitFilterMode() {
        let toolbar = MenuBarToolbarState()
        toolbar.unifiedActive = true
        toolbar.showFilters()
        toolbar.unifiedActive = false
        #expect(toolbar.isFiltering)
        #expect(!toolbar.isSearching)
        toolbar.focusSearch()
        #expect(!toolbar.isFiltering && toolbar.searchIsFocused)
    }

    /// 搜索语境补全由统一搜索输入（UnifiedSearchInputState.suggestions）使用；旧底栏搜索删除后直接构造同一语境验证。
    @Test func searchCompletionUsesSearchCapabilitiesAndResetsUnsupportedTriggers() {
        let autocomplete = SyntaxAutocompleteState(context: .search)
        autocomplete.update(text: "#", cursorLocation: 1, availableTags: ["工作"])
        #expect(autocomplete.candidates.first?.subtitle == "syntax.search.tag")
        autocomplete.update(text: "@", cursorLocation: 1)
        #expect(autocomplete.isActive)
        #expect(autocomplete.candidates.allSatisfy { !$0.isCreation && $0.kind == .time })
        autocomplete.update(text: "!", cursorLocation: 1)
        autocomplete.selectPrevious()
        #expect(autocomplete.selectedCandidate()?.insertText == "!p4 ")
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

    @Test func failedCalendarDropKeepsTheSelectedDay() {
        #expect(CalendarDayDrop.nextSelectedDay(current: "2026-09-13", target: "2026-09-20", saved: false) == "2026-09-13")
        #expect(CalendarDayDrop.nextSelectedDay(current: "2026-09-13", target: "2026-09-20", saved: true) == "2026-09-20")
    }
}
