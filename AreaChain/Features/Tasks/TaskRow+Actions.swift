import AppKit
import SwiftUI

extension TaskRow {
    // MARK: - Actions & Editing

    var editor: some View {
        SyntaxTextField(
            text: $draft,
            placeholder: L10n.string("row.edit.field", locale: locale),
            focused: $editorFocused,
            allowsShiftNewline: true,
            onSubmit: saveEdit,
            onEscape: cancelEdit
        )
        .onAppear { DispatchQueue.main.async { editorFocused = true } }
    }

    var timePicker: some View {
        DatePicker(
            "row.time",
            selection: Binding(
                get: {
                    RemindMinutes.date(minutes: state.remindMinutes ?? RemindMinutes.from(date: .now)) ?? .now
                },
                set: { dispatch(.setRemindMinutes(RemindMinutes.from(date: $0))) }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .padding(12)
        .frame(minWidth: 180)
    }

    func beginEdit() {
        draft = state.title
        editorFocused = false
        editing = true
    }

    func cancelEdit() {
        draft = state.title
        editing = false
        editorFocused = false
        dispatch(.endEditing)
    }

    func saveEdit() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !next.isEmpty {
            if let onSaveTitle {
                guard onSaveTitle(next) else { return }
            } else {
                dispatch(.editTitle(next))
            }
        } else {
            draft = state.title
        }
        editing = false
        editorFocused = false
        dispatch(.endEditing)
    }

    func copyTask() {
        var content = state.title
        if let note = fullNoteText, !note.isEmpty {
            content += "\n" + note
        }
        copyToClipboard(content)
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            hasCopied = true
        }
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
