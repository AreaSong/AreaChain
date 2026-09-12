import SwiftUI

@Observable
@MainActor
final class MenuBarToolbarState {
    var searchText = ""
    var searchIsFocused = false
    private(set) var isFiltering = false
    private(set) var allowsFilterHover = true
    let autocomplete = SyntaxAutocompleteState(context: .search)

    var isSearching: Bool { !BoardSearch.normalized(searchText).isEmpty }

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

    func focusSearch() {
        closeFilters()
        searchIsFocused = true
    }

    func clearSearch() {
        searchText = ""
        autocomplete.dismiss()
    }
}
