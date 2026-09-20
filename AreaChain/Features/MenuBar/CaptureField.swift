import SwiftData
import SwiftUI

@Observable
@MainActor
final class CaptureSession {
    static let shared = CaptureSession()
    var draft = ""
}

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
        .daybookHideInputChrome()
    }

    private var inputRow: some View {
        let focused = focus.wrappedValue
        let plusColor = focused ? DaybookTheme.ink : DaybookTheme.muted.opacity(0.8)
        let strokeColor = focused ? DaybookTheme.ink.opacity(0.35) : DaybookTheme.rule.opacity(0.4)

        return HStack(alignment: .center, spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(plusColor)
                .frame(width: 14)

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

            diaryShortcutButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(focused ? DaybookTheme.surface : DaybookTheme.ink.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(strokeColor, lineWidth: focused ? 0.9 : 0.6)
        )
    }

    private var diaryShortcutButton: some View {
        CommandReturnButton(enabled: canSubmit, label: "capture.diary", action: onDiary)
            .keyboardShortcut(allowsDiaryShortcut ? KeyboardShortcut(.return, modifiers: [.command]) : nil)
    }
}
