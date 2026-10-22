import SwiftUI

@Observable
@MainActor
final class MenuBarToolbarState {
    var searchText = ""
    var searchIsFocused = false
    var resultIndex: Int?
    private(set) var isFiltering = false
    private(set) var allowsFilterHover = true
    let autocomplete = SyntaxAutocompleteState(context: .search)
    /// 合并批 M-6：新版搜索在用且有查询／指令时为真；由 MenuBarUnifiedSearchBridge 维护，旧搜索时恒为 false。
    var unifiedActive = false

    var isSearching: Bool { unifiedActive || !BoardSearch.normalized(searchText).isEmpty }

    func showFilters() {
        searchIsFocused = false
        autocomplete.dismiss()
        isFiltering = true
    }

    func closeFilters() {
        if isFiltering { allowsFilterHover = false }
        isFiltering = false
    }

    func showFiltersFromHover() {
        guard allowsFilterHover, !searchIsFocused else { return }
        showFilters()
    }

    func pointerLeftToolbar() {
        allowsFilterHover = true
    }

    func toggleFilters() {
        if isFiltering {
            closeFilters()
        } else {
            showFilters()
        }
    }

    func focusSearch() {
        closeFilters()
        searchIsFocused = true
    }

    func clearSearch() {
        searchText = ""
        resultIndex = nil
        autocomplete.dismiss()
    }
}
