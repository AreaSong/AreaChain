import AppKit
import SwiftUI

/// 搜索框内嵌的已生效筛选胶囊
struct SearchFilterToken: Identifiable, Equatable {
    var id: String
    var title: String
    var icon: String? = nil
    var dotColor: Color? = nil
    var onRemove: () -> Void

    static func == (lhs: SearchFilterToken, rhs: SearchFilterToken) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title
    }
}

struct MenuBarSearchField: View {
    var tab: BoardTab = .tasks
    @Bindable var toolbar: MenuBarToolbarState
    var availableTags: [String]
    var tokens: [SearchFilterToken] = []

    @Environment(\.locale) private var locale
    @State private var hostWindow: NSWindow?

    private var searchPlaceholder: String {
        guard tokens.isEmpty else {
            return L10n.string("footer.search.placeholder.short", locale: locale)
        }
        return tab == .diary
            ? L10n.string("diary.search.placeholder", locale: locale)
            : L10n.string("footer.search.placeholder", locale: locale)
    }

    var body: some View {
        DaybookInputShell(kind: .search, focused: toolbar.searchIsFocused) {
            DaybookIconButton(systemName: "magnifyingglass", label: "footer.search.label", size: .inline) {
                toolbar.focusSearch()
            }
            .keyboardShortcut("f", modifiers: .command)

            if !tokens.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(tokens) { token in
                            DaybookChip(tint: DaybookTheme.stamp, isSelected: true) {
                                HStack(spacing: 2) {
                                    if let dotColor = token.dotColor {
                                        Circle().fill(dotColor).frame(width: 4.5, height: 4.5)
                                    } else if let icon = token.icon {
                                        Image(systemName: icon)
                                    }
                                    Text(token.title)
                                        .lineLimit(1)
                                    Button(action: token.onRemove) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 6.5, weight: .bold))
                                            .frame(width: 9, height: 9)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain) // control: 芯片内的移除角标
                                }
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        } field: {
            DaybookTextField(
                text: $toolbar.searchText,
                placeholder: searchPlaceholder,
                fontSize: 11,
                focus: $toolbar.searchIsFocused,
                autocomplete: toolbar.autocomplete,
                availableTags: availableTags,
                onSubmit: {},
                onCommandReturn: {},
                allowsShiftNewline: false,
                onEscape: escapeSearch
            )
            .accessibilityLabel("footer.search.label")
            .accessibilityIdentifier("menubar.search.input")
        } trailing: {
            if !toolbar.searchText.isEmpty {
                DaybookIconButton(systemName: "xmark.circle.fill", label: "footer.search.clear", size: .inline) {
                    toolbar.clearSearch()
                    toolbar.focusSearch()
                }
            }
        }
        .frame(minWidth: 110, maxWidth: .infinity)
        .syntaxSuggestions(toolbar.autocomplete, prefersAbove: true, enabled: toolbar.searchIsFocused && !toolbar.isFiltering)
        .background(KeyWindowHost { hostWindow = $0 })
        .onDisappear(perform: resignSearch)
        .help("footer.search.help")
    }

    private func escapeSearch() {
        if toolbar.isSearching {
            toolbar.clearSearch()
        } else {
            resignSearch()
        }
    }

    private func resignSearch() {
        if toolbar.searchIsFocused, hostWindow?.firstResponder is NSTextView {
            hostWindow?.makeFirstResponder(nil)
        }
        toolbar.searchIsFocused = false
        toolbar.autocomplete.dismiss()
    }
}
