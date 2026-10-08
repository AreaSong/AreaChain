import AppKit
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

    @Bindable private var shortcuts = ShortcutStore.shared
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
        let plusColor = focused ? DaybookPalette.text.primary : DaybookPalette.text.tertiary

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
                onCommandReturn: { if allowsDiaryShortcut { submitDiary() } },
                commandChord: shortcuts.armedChord(for: .commitDiary),
                allowsShiftNewline: false
            )
            .accessibilityLabel("capture.placeholder.today")
        } trailing: {
            diaryShortcutButton
        }
    }

    private var diarySymbol: String? {
        let binding = shortcuts.binding(for: .commitDiary)
        guard binding.chord != ShortcutAction.commitDiary.defaultChord else { return nil }
        return binding.chord.displayName(locale: locale)
    }

    private var diaryShortcutButton: some View {
        CommandReturnButton(
            enabled: canSubmit,
            label: "capture.diary",
            symbolText: diarySymbol,
            action: submitDiary
        )
            .appShortcut(.commitDiary, enabled: allowsDiaryShortcut)
    }

    private func submitDiary() {
        guard canSubmit else { return }
        // 按钮快捷键可能先于字段收到事件；只检查本输入仍在使用的原生编辑器。
        if let editor = autocomplete.editor,
           let field = editor.delegate as? NSTextField,
           field.currentEditor() === editor,
           field.window?.firstResponder === editor,
           DaybookTextEditing.isProtected(editor) { return }
        onDiary()
    }
}
