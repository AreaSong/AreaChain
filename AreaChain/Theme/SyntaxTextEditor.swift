import AppKit
import SwiftData
import SwiftUI

struct SyntaxTextEditor: View {
    @Binding var text: String
    @Binding var focused: Bool
    var placeholder: String
    var fontSize: CGFloat = DaybookType.bodySize
    var context: SyntaxInputContext
    var externalAutocomplete: SyntaxAutocompleteState?
    var availableTags: [String]?
    var onSubmit: (() -> Void)?
    var commandChord: ShortcutChord?
    var onPasteImage: ((NSPasteboard) -> Bool)?

    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @State private var autocomplete: SyntaxAutocompleteState
    @State private var hasMarkedText = false

    private var activeAutocomplete: SyntaxAutocompleteState {
        externalAutocomplete ?? autocomplete
    }

    init(
        text: Binding<String>, focused: Binding<Bool>, placeholder: String,
        fontSize: CGFloat = DaybookType.bodySize, context: SyntaxInputContext = .tags,
        allowsLivePreview: Bool? = nil,
        externalAutocomplete: SyntaxAutocompleteState? = nil, availableTags: [String]? = nil,
        onSubmit: (() -> Void)? = nil, commandChord: ShortcutChord? = nil,
        onPasteImage: ((NSPasteboard) -> Bool)? = nil
    ) {
        _text = text
        _focused = focused
        self.placeholder = placeholder
        self.fontSize = fontSize
        self.context = context
        self.externalAutocomplete = externalAutocomplete
        self.availableTags = availableTags
        self.onSubmit = onSubmit
        self.commandChord = commandChord
        self.onPasteImage = onPasteImage
        _autocomplete = State(initialValue: SyntaxAutocompleteState(
            context: context,
            allowsLivePreview: allowsLivePreview ?? (context == .capture || context == .diaryCapture)
        ))
    }

    var body: some View {
        DaybookTextEditor(
            text: $text, focused: $focused, placeholder: placeholder, fontSize: fontSize,
            autocomplete: activeAutocomplete,
            availableTags: availableTags ?? tags.filter { $0.deletedAt == nil }.map(\.name),
            onSubmit: onSubmit, commandChord: commandChord,
            onMarkedTextChange: { hasMarkedText = $0 },
            onPasteImage: onPasteImage
        )
        .overlay(alignment: .topLeading) {
            if text.isEmpty && !hasMarkedText {
                Text(placeholder)
                    .font(placeholderFont)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .padding(.horizontal, 9) // token-exempt: 对齐 AppKit NSTextView 文本容器内边距 (4 inset + 5 fragment padding)
                    .padding(.vertical, 4) // token-exempt: 对齐 AppKit NSTextView 垂直容器内边距 (4)
                    .allowsHitTesting(false)
            }
        }
        .syntaxSuggestions(activeAutocomplete, enabled: externalAutocomplete == nil)
    }

    private var placeholderFont: Font {
        if fontSize <= DaybookType.captionSize {
            return DaybookType.caption
        }
        return DaybookType.body
    }
}
