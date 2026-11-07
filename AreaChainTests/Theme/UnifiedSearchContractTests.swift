import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchContractTests {
    @Test func synchronizeRejectsStaleLeaseAndUpdatesBuffer() throws {
        let model = UnifiedSearchTestModel(text: "/theme")
        let field = NSTextField(string: "/theme")
        let editor = UnifiedSearchFieldEditor()
        editor.string = "/theme"
        editor.setSelectedRange(NSRange(location: 6, length: 0))
        let state = UnifiedSearchInputState(buffer: model.buffer, actions: model.actions)
        state.begin(field, editor: editor)
        let oldSource = state.buffer
        model.replace("/theme dark")
        state.synchronize(model.buffer, field: field)
        model.actions.intent(.submit, oldSource)
        #expect(model.intents.isEmpty)
        state.synchronize(oldSource, field: field)
        #expect(state.buffer == model.buffer)
    }

    @Test func highlightingPreservesTextSelectionAndUndo() throws {
        let editor = UnifiedSearchFieldEditor()
        editor.allowsUndo = true
        let text = "/theme dark"
        editor.insertText(text, replacementRange: NSRange(location: 0, length: 0))
        let range = NSRange(location: 2, length: 4)
        editor.setSelectedRange(range)
        let highlight = UnifiedSearchHighlight()
        highlight.apply(to: editor, text: editor.string)
        highlight.apply(to: editor, text: editor.string)
        #expect(editor.selectedRange() == range)
        #expect(editor.string == text)
        #expect(editor.undoManager?.canUndo == true)
        let storage = try #require(editor.textStorage)
        #expect(storage.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor == DaybookPalette.Syntax.timeNS)
        let ordinary = SyntaxHighlighter.attributedString(for: text, font: .systemFont(ofSize: DaybookType.bodySize))
        #expect(ordinary.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor != DaybookPalette.Syntax.timeNS)
        editor.undoManager?.undo()
        #expect(editor.string.isEmpty)
    }
}
