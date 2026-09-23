import SwiftData
import SwiftUI

struct SyntaxTextEditor: View {
    @Binding var text: String
    @Binding var focused: Bool
    var placeholder: String
    var fontSize: CGFloat = DaybookType.bodySize
    var context: SyntaxInputContext
    var onSubmit: (() -> Void)?

    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @State private var autocomplete: SyntaxAutocompleteState

    init(
        text: Binding<String>, focused: Binding<Bool>, placeholder: String,
        fontSize: CGFloat = DaybookType.bodySize, context: SyntaxInputContext = .tags, onSubmit: (() -> Void)? = nil
    ) {
        _text = text
        _focused = focused
        self.placeholder = placeholder
        self.fontSize = fontSize
        self.context = context
        self.onSubmit = onSubmit
        _autocomplete = State(initialValue: SyntaxAutocompleteState(context: context))
    }

    var body: some View {
        DaybookTextEditor(
            text: $text, focused: $focused, placeholder: placeholder, fontSize: fontSize,
            autocomplete: autocomplete, availableTags: tags.filter { $0.deletedAt == nil }.map(\.name),
            onSubmit: onSubmit
        )
        .overlay(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(placeholderFont)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .padding(.horizontal, 9) // token-exempt: 对齐 AppKit NSTextView 文本容器内边距 (4 inset + 5 fragment padding)
                    .padding(.vertical, 5) // token-exempt: 对齐 AppKit NSTextView 垂直容器内边距 (5)
                    .allowsHitTesting(false)
            }
        }
        .syntaxSuggestions(autocomplete)
    }

    private var placeholderFont: Font {
        if fontSize <= DaybookType.captionSize {
            return DaybookType.caption
        }
        return DaybookType.body
    }
}
