import SwiftData
import SwiftUI

struct SyntaxTextEditor: View {
    @Binding var text: String
    @Binding var focused: Bool
    var placeholder: String
    var fontSize: CGFloat = 13
    var context: SyntaxInputContext
    var onSubmit: (() -> Void)?

    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @State private var autocomplete: SyntaxAutocompleteState

    init(
        text: Binding<String>, focused: Binding<Bool>, placeholder: String,
        fontSize: CGFloat = 13, context: SyntaxInputContext = .tags, onSubmit: (() -> Void)? = nil
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
                    .font(.system(size: fontSize))
                    .foregroundStyle(DaybookTheme.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .allowsHitTesting(false)
            }
        }
        .syntaxSuggestions(autocomplete)
    }
}
