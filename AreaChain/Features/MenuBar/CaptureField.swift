import SwiftData
import SwiftUI

struct CaptureField: View {
    @Environment(\.locale) private var locale
    @Query(sort: \TagItem.sortOrder) private var allTags: [TagItem]
    @Binding var text: String
    var focus: Binding<Bool>
    var onTodo: () -> Void
    var onDiary: () -> Void
    var allowsDiaryShortcut = true

    @State private var autocomplete = SyntaxAutocompleteState(context: .capture, allowsLivePreview: true)

    private var availableTags: [String] {
        allTags.filter { $0.deletedAt == nil }.map(\.name)
    }

    private var parsed: ParsedCapture {
        NaturalLanguageParser.parseTaskCapture(text)
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        inputRow
        .syntaxSuggestions(autocomplete)
        .animation(DaybookMotion.interactive, value: focus.wrappedValue)
    }

    private var inputRow: some View {
        let focused = focus.wrappedValue
        let plusColor = focused ? DaybookTheme.ink : DaybookPalette.text.tertiary

        return DaybookInputShell(kind: .composer, focused: focused) {
            Image(systemName: "plus")
                .font(DaybookType.caption.weight(.semibold))
                .foregroundStyle(plusColor)
                .frame(width: 14)
        } field: {
            DaybookTextField(
                text: $text,
                placeholder: L10n.string("capture.placeholder.today", locale: locale),
                focus: focus,
                autocomplete: autocomplete,
                availableTags: availableTags,
                highlightsSyntax: true,
                onSubmit: onTodo,
                onCommandReturn: { if allowsDiaryShortcut { onDiary() } },
                allowsShiftNewline: false
            )
            .accessibilityLabel("capture.placeholder.today")
        } trailing: {
            diaryShortcutButton
        }
    }

    private var diaryShortcutButton: some View {
        CommandReturnButton(enabled: canSubmit, label: "capture.diary", action: onDiary)
            .keyboardShortcut(allowsDiaryShortcut ? KeyboardShortcut(.return, modifiers: [.command]) : nil)
    }
}
