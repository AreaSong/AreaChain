import SwiftData
import SwiftUI

/// 新增与编辑共用的单行语法输入；仅补全草稿，绝不在候选选择时写入标签。
struct SyntaxTextField: View {
    @Binding var text: String
    var placeholder: String
    @Binding var focused: Bool
    var context: SyntaxInputContext = .capture
    var fontSize: CGFloat = 13
    var allowsShiftNewline: Bool = false
    var onSubmit: () -> Void = {}
    var onEscape: (() -> Void)? = nil

    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @State private var autocomplete: SyntaxAutocompleteState

    init(
        text: Binding<String>, placeholder: String, focused: Binding<Bool>,
        context: SyntaxInputContext = .capture, fontSize: CGFloat = 13,
        allowsShiftNewline: Bool = false, onSubmit: @escaping () -> Void = {}, onEscape: (() -> Void)? = nil
    ) {
        _text = text
        self.placeholder = placeholder
        _focused = focused
        self.context = context
        self.fontSize = fontSize
        self.allowsShiftNewline = allowsShiftNewline
        self.onSubmit = onSubmit
        self.onEscape = onEscape
        _autocomplete = State(initialValue: SyntaxAutocompleteState(context: context))
    }

    var body: some View {
        DaybookTextField(
            text: $text, placeholder: placeholder, fontSize: fontSize, focus: $focused,
            autocomplete: autocomplete, availableTags: tags.filter { $0.deletedAt == nil }.map(\.name),
            onSubmit: onSubmit, allowsShiftNewline: allowsShiftNewline, onEscape: onEscape
        )
        .frame(minHeight: fontSize + 6)
        .accessibilityLabel(placeholder)
        .overlay(alignment: .topLeading) {
            if autocomplete.isActive {
                SyntaxAutocompletePopup(state: autocomplete, onCommit: complete)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(y: fontSize + 12)
            }
        }
        .zIndex(autocomplete.isActive ? 100 : 0)
    }

    private func complete(_ candidate: SyntaxCandidate) {
        guard autocomplete.commit(candidate) else { return }
        focused = true
    }
}
