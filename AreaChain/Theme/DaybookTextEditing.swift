import AppKit

/// 换行用途独立于 Shift+Return 开关；未选择搜索政策的调用方保留捕获提交规则。
@MainActor
enum DaybookNewlinePolicy {
    case capture
    case searchWhitespace

    func submittedText(_ input: String, allowsShiftNewline: Bool) -> String {
        switch self {
        case .capture:
            return allowsShiftNewline ? input : DaybookTextField.sanitizeSingleLineText(input)
        case .searchWhitespace:
            // 按标量处理，CRLF 是两个空格；不修剪或折叠其他空白。
            return String(String.UnicodeScalarView(input.unicodeScalars.map {
                CharacterSet.newlines.contains($0) ? " " : $0
            }))
        }
    }
}

/// 普通字段沿用原生编辑器和撤销事务；不参与统一搜索的许可或缓冲管理。
@MainActor
enum DaybookTextEditing {
    static func isProtected(_ editor: NSTextView) -> Bool {
        editor.hasMarkedText() || editor.undoManager?.isUndoing == true || editor.undoManager?.isRedoing == true
    }

    static func replaceForSubmission(_ value: String, in editor: NSTextView) -> Bool {
        guard !isProtected(editor) else { return false }
        let original = editor.string
        guard original != value else { return true }
        let selection = mappedSelection(editor.selectedRange(), from: original, to: value)
        // 提交转换本身是一次原生编辑，不在 didChange 回调里追加第二次字符串赋值。
        editor.breakUndoCoalescing()
        editor.insertText(value, replacementRange: NSRange(location: 0, length: original.utf16.count))
        editor.setSelectedRange(selection)
        editor.breakUndoCoalescing()
        return editor.string == value
    }

    private static func mappedSelection(_ selection: NSRange, from original: String, to value: String) -> NSRange {
        let old = Array(original.utf16)
        let new = Array(value.utf16)
        // 搜索空白替换等长，选区的两个 UTF-16 端点原样保留。
        if old.count == new.count { return selection }
        let prefix = zip(old, new).prefix { $0 == $1 }.count
        let suffix = zip(old.dropFirst(prefix).reversed(), new.dropFirst(prefix).reversed()).prefix { $0 == $1 }.count
        func mapped(_ offset: Int) -> Int {
            if offset <= prefix { return offset }
            if offset >= old.count - suffix { return offset + new.count - old.count }
            return min(new.count - suffix, offset)
        }
        let start = mapped(selection.location)
        return NSRange(location: start, length: max(0, mapped(NSMaxRange(selection)) - start))
    }
}

extension DaybookTextField.Coordinator {
    func prepareSubmission(editor: NSTextView) -> Bool {
        let value = parent.newlinePolicy.submittedText(editor.string, allowsShiftNewline: parent.allowsShiftNewline)
        guard DaybookTextEditing.replaceForSubmission(value, in: editor) else { return false }
        parent.text = editor.string
        return true
    }

    func commandReturn(in field: NSTextField) {
        guard parent.onCommandReturn != nil || parent.newlinePolicy == .searchWhitespace else { return }
        if let editor = field.currentEditor() as? NSTextView {
            guard prepareSubmission(editor: editor) else { return }
        } else {
            let value = parent.newlinePolicy.submittedText(field.stringValue, allowsShiftNewline: parent.allowsShiftNewline)
            field.stringValue = value
            parent.text = value
        }
        if let extra = parent.onCommandReturn {
            parent.autocomplete?.dismiss()
            extra()
        }
    }
}
