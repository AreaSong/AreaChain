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
        DaybookTimePicker(
            "row.time",
            minutes: Binding(
                get: { state.remindMinutes },
                set: { dispatch(.setRemindMinutes($0)) }
            )
        )
        .environment(\.locale, locale)
        .padding(DaybookMetrics.TimePicker.popoverPadding)
        .frame(minWidth: DaybookMetrics.TimePicker.popoverMinimumWidth)
    }

    func beginEdit() {
        draft = state.title
        editorFocused = false
        editing = true
    }

    func cancelEdit() {
        draft = state.title
        if hostContext != nil { editDrafts.titles.removeValue(forKey: navigationDraftKey) }
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
        if hostContext != nil { editDrafts.titles.removeValue(forKey: navigationDraftKey) }
        editing = false
        editorFocused = false
        dispatch(.endEditing)
    }

    func copyTask() {
        guard copy(.record) else { return }
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            hasCopied = true
        }
    }

    /// 与 todo.copy 共用内容规则和写入接口；写入失败时不显示已复制。
    @discardableResult func copy(_ section: TaskCopySection) -> Bool {
        guard let text = TaskCopyContent.text(section, title: state.title, notes: fullNoteText) else { return false }
        return copyToClipboard(text)
    }

    @discardableResult func copyToClipboard(_ text: String) -> Bool {
        do {
            try (clipboardWriter ?? SystemClipboardTextWriter.shared).write(text)
            return true
        } catch { return false }
    }
}

private struct ClipboardTextWriterKey: EnvironmentKey {
    static let defaultValue: (any ClipboardTextWriting)? = nil
}

extension EnvironmentValues {
    /// 只供测试替换为 fake；未注入时生产仍写系统通用剪贴板。
    var clipboardTextWriter: (any ClipboardTextWriting)? {
        get { self[ClipboardTextWriterKey.self] }
        set { self[ClipboardTextWriterKey.self] = newValue }
    }
}
