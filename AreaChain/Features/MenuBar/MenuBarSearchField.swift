import AppKit
import SwiftUI

struct MenuBarSearchField: View {
    @Bindable var toolbar: MenuBarToolbarState
    var availableTags: [String]

    @Environment(\.locale) private var locale
    @State private var hostWindow: NSWindow?

    var body: some View {
        HStack(spacing: 5) {
            Button { toolbar.focusSearch() } label: {
                Image(systemName: "magnifyingglass")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .accessibilityLabel("footer.search.label")

            DaybookTextField(
                text: $toolbar.searchText,
                placeholder: L10n.string("footer.search.placeholder", locale: locale),
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
        .background(RoundedRectangle(cornerRadius: DaybookRadius.small).fill(DaybookTheme.hoverFill))
        .overlay {
            RoundedRectangle(cornerRadius: DaybookRadius.small)
                .strokeBorder(toolbar.searchIsFocused ? DaybookTheme.stamp : DaybookTheme.rule.opacity(0.55), lineWidth: 1)
        }
        .anchorPreference(key: MenuBarSearchAnchorKey.self, value: .bounds) { $0 }
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

struct MenuBarSearchAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct MenuBarSearchSuggestions: View {
    @Bindable var toolbar: MenuBarToolbarState

    var body: some View {
        if let trigger = toolbar.autocomplete.trigger {
            SyntaxAutocompletePopup(state: toolbar.autocomplete, growsUpward: true) { candidate in
                let (text, _) = SyntaxAutocompleteEngine.applyCandidate(
                    candidate, to: toolbar.searchText, range: trigger.range
                )
                toolbar.searchText = text
                toolbar.autocomplete.dismiss()
            }
        }
    }
}
