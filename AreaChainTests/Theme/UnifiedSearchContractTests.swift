import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchContractTests {
    @Test func completionRejectsSameTextNewVersionAndOtherLease() throws {
        let model = UnifiedSearchTestModel(text: "/set")
        let field = NSTextField(string: "/set")
        let editor = UnifiedSearchFieldEditor()
        editor.string = "/set"
        editor.setSelectedRange(NSRange(location: 4, length: 0))
        let state = UnifiedSearchInputState(buffer: model.buffer, actions: model.actions)
        state.begin(field, editor: editor)
        let old = try #require(state.completion)
        let candidate = try #require(old.result.candidates.first)
        model.replace("/set")
        state.synchronize(model.buffer, field: field)
        #expect(!state.publish(old))
        #expect(!state.accept(candidate, source: old))
        let current = try #require(state.completion)
        let other = UnifiedSearchTestModel(host: "another", text: "/set")
        #expect(!state.publish(.init(source: other.buffer, selection: current.selection, result: current.result)))
        model.actions.intent(.submit, old.source)
        #expect(model.intents.isEmpty)
        state.synchronize(old.source, field: field)
        #expect(state.buffer == model.buffer)
    }

    @Test func fullDiscoveryAndExplicitSelectorRemainSeparate() throws {
        let parser = CommandPathParser()
        let result = parser.parse(.init(text: "/set", contentScopes: [.diaries]))
        #expect(result.candidates.contains { $0.command.id.rawValue == "setting.language" })
        let config = try #require(CommandDiscoveryConfiguration.selector(
            allowing: [.init(rawValue: "setting.language")], explanationKey: "synthetic.selector"))
        let limited = parser.parse(.init(text: "/", configuration: config))
        #expect(!limited.candidates.contains { $0.command.id.rawValue == "todo.create" })
    }

    @Test func highlightingPreservesTextSelectionAndUndo() throws {
        let editor = UnifiedSearchFieldEditor()
        editor.allowsUndo = true
        editor.insertText("/setting/language/chinese", replacementRange: NSRange(location: 0, length: 0))
        let range = NSRange(location: 3, length: 5)
        editor.setSelectedRange(range)
        let result = CommandPathParser().parse(.init(text: editor.string))
        let highlight = UnifiedSearchHighlight()
        highlight.apply(to: editor, result: result)
        highlight.apply(to: editor, result: result)
        #expect(editor.selectedRange() == range)
        #expect(editor.string == result.input)
        #expect(editor.undoManager?.canUndo == true)
        let storage = try #require(editor.textStorage)
        #expect(storage.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor == DaybookPalette.Syntax.timeNS)
        #expect(storage.attribute(.foregroundColor, at: 20, effectiveRange: nil) as? NSColor == DaybookPalette.Syntax.tagNS)
        let ordinary = SyntaxHighlighter.attributedString(for: result.input, font: .systemFont(ofSize: DaybookType.bodySize))
        #expect(ordinary.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor != DaybookPalette.Syntax.timeNS)
        editor.undoManager?.undo()
        #expect(editor.string.isEmpty)
    }
}
