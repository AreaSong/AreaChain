import SwiftUI

@Observable
@MainActor
final class MenuBarToolbarState {
    var searchIsFocused = false
    private(set) var isFiltering = false
    private(set) var allowsFilterHover = true
    /// 统一搜索有查询／指令时为真；由 MenuBarUnifiedSearchBridge 维护，装配失败时恒为 false。
    var unifiedActive = false

    var isSearching: Bool { unifiedActive }

    func showFilters() {
        searchIsFocused = false
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
}
