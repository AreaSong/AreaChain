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
        HStack(spacing: 4) {
            Button { toolbar.focusSearch() } label: {
                Image(systemName: "magnifyingglass")
                    .font(DaybookType.caption)
                    .foregroundStyle(toolbar.searchIsFocused ? DaybookTheme.ink : DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .accessibilityLabel("footer.search.label")

            if !tokens.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(tokens) { token in
                            HStack(spacing: 2) {
                                if let dotColor = token.dotColor {
                                    Circle().fill(dotColor).frame(width: 4.5, height: 4.5)
                                } else if let icon = token.icon {
                                    Image(systemName: icon).font(.system(size: 7.5, weight: .bold))
                                }
                                Text(token.title)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .lineLimit(1)
                                Button(action: token.onRemove) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 6.5, weight: .bold))
                                        .frame(width: 9, height: 9)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.leading, 4)
                            .padding(.trailing, 2.5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
                            .overlay(Capsule().strokeBorder(DaybookTheme.stamp.opacity(0.35), lineWidth: 0.6))
                            .foregroundStyle(DaybookTheme.stamp)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

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

            if !toolbar.searchText.isEmpty {
                Button { toolbar.clearSearch(); toolbar.focusSearch() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("footer.search.clear")
                .help("footer.search.clear")
            }
        }
        .padding(.horizontal, 7)
        .frame(minWidth: 110, maxWidth: .infinity)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small)
                .fill(toolbar.searchIsFocused ? DaybookTheme.surface : DaybookTheme.hoverFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DaybookRadius.small)
                .strokeBorder(
                    toolbar.searchIsFocused ? DaybookTheme.ink.opacity(0.35) : DaybookTheme.rule.opacity(0.55),
                    lineWidth: toolbar.searchIsFocused ? 0.9 : 0.6
                )
        }
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
