import AppKit
import SwiftUI

struct WorkspaceHeaderSearchCapsule: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation
    var tagNames: [String]
    @Bindable private var shortcuts = ShortcutStore.shared
    @State private var hostWindow: NSWindow?
    @State private var autocomplete = SyntaxAutocompleteState(context: .search)

    var body: some View {
        DaybookInputShell(kind: .search, focused: navigation.isSearchFocused) {
            Image(systemName: "magnifyingglass")
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(navigation.isSearchFocused ? DaybookPalette.text.primary : DaybookPalette.text.secondary)
        } field: {
            DaybookTextField(
                text: $navigation.searchQuery,
                placeholder: L10n.string("workspace.search.placeholder", locale: locale),
                fontSize: 12,
                focus: $navigation.isSearchFocused,
                autocomplete: autocomplete,
                availableTags: tagNames,
                onSubmit: {},
                allowsShiftNewline: false,
                newlinePolicy: .searchWhitespace,
                onEscape: { escapeSearch() },
                onMoveDown: moveToResults
            )
            .accessibilityLabel(Text("workspace.search.placeholder"))
            .accessibilityIdentifier("workspace.header.search")
        } trailing: {
            if !navigation.searchQuery.isEmpty {
                DaybookIconButton(systemName: "xmark.circle.fill", label: "footer.search.clear", size: .inline) {
                    navigation.clearSearch()
                    navigation.isSearchFocused = true
                }
            } else if shortcuts.binding(for: .search).isArmed {
                Text(verbatim: shortcuts.binding(for: .search).chord.displayName(locale: locale))
                    .font(.system(size: 9.5, weight: .bold, design: .rounded)) // token-exempt: 快捷键提示用圆体
                    .foregroundStyle(DaybookPalette.text.secondary.opacity(0.6)) // token-exempt: 60% 次要色没有对应令牌
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
            }
        }
        .environment(\.daybookChromelessWhenIdle, navigation.searchQuery.isEmpty)
        .syntaxSuggestions(autocomplete, enabled: navigation.isSearchFocused)
        .background(KeyWindowHost { hostWindow = $0 })
        .onChange(of: navigation.searchQuery) { _, _ in
            navigation.searchResultIndex = nil
        }
        // ⌘F 全局快捷键聚焦
        .background {
            Button("") {
                navigation.isSearchFocused = true
            }
            .appShortcut(.search)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    private func moveToResults() -> Bool {
        guard navigation.isSearching else { return false }
        navigation.searchResultIndex = 0
        navigation.isSearchFocused = false
        hostWindow?.makeFirstResponder(nil)
        return true
    }

    private func escapeSearch() {
        if !BoardSearch.normalized(navigation.searchQuery).isEmpty {
            navigation.searchQuery = ""
            return
        }
        navigation.isSearchFocused = false
        if hostWindow?.firstResponder is NSTextView {
            hostWindow?.makeFirstResponder(nil)
        }
    }
}
