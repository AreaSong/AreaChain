import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchInputTests {
    @Test func cliTabCompletionAndKeyboardOwnership() async throws {
        StandardActionCatalog.bootstrapIfNeeded()
        let host = UnifiedSearchTestHost()
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.insertText("/them", replacementRange: editor.selectedRange())
        try await host.settle()
        let before = host.model.edits.count
        try await host.key(48, "\t")
        #expect(host.model.buffer.text.hasPrefix("/theme"))
        #expect(host.model.edits.count == before + 1)
        #expect(host.window.firstResponder === editor)
        try await host.key(36, "\r", flags: .command)
        #expect(host.model.intents == [.submit])
        #expect(host.model.intentSources.last == host.model.buffer)
        try await host.key(53, "\u{1b}")
        #expect(host.model.intents == [.submit, .escape])
        try await host.key(125, "\u{f701}")
        #expect(host.model.intents.last == .results(1))
    }

    @Test func markedTextBlocksCompletionAndSubmit() async throws {
        let host = UnifiedSearchTestHost(text: "/theme dark")
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        let state = try host.state
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        editor.setMarkedText("中文", selectedRange: NSRange(location: 2, length: 0), replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(editor.hasMarkedText())
        #expect(!state.suggestions.isActive)
        #expect(!state.command(#selector(NSResponder.insertNewline(_:)), editor: editor))
        state.submit()
        #expect(host.model.intents.isEmpty)
        editor.insertText("中文", replacementRange: editor.markedRange())
        try await host.settle()
        #expect(!editor.hasMarkedText())
        #expect(host.model.buffer.text == "中文")
    }

    @Test func privacyClearsOnlyThisEditor() async throws {
        let host = UnifiedSearchTestHost(text: "/theme")
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.insertText("SYNTHETIC_PRIVATE_MARKER", replacementRange: editor.selectedRange())
        try await host.settle()
        let unrelated = NSObject()
        host.window.undoManager?.registerUndo(withTarget: unrelated) { _ in }
        #expect(host.window.undoManager !== editor.undoManager)
        host.model.replace("", privacy: true)
        try await host.settle()
        #expect(editor.string.isEmpty && !editor.hasMarkedText())
        #expect(editor.undoManager?.canUndo == false && editor.undoManager?.canRedo == false)
        #expect(host.window.undoManager?.canUndo == true)
        editor.undoManager?.undo()
        #expect(editor.string.isEmpty)
    }

    @Test func ordinaryBlurRetainsUndoButPrivacyClearsComposition() async throws {
        let host = UnifiedSearchTestHost()
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.insertText("SYNTHETIC_DRAFT", replacementRange: editor.selectedRange())
        try await host.settle()
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(host.model.buffer.text == "SYNTHETIC_DRAFT")
        #expect(editor.undoManager?.canUndo == true)
        host.model.focused = true
        try await host.settle()
        let active = try host.editor
        active.setSelectedRange(NSRange(location: active.string.utf16.count, length: 0))
        active.setMarkedText("组合", selectedRange: NSRange(location: 2, length: 0), replacementRange: active.selectedRange())
        try await host.settle()
        #expect(active.hasMarkedText())
        host.model.replace("", privacy: true)
        try await host.settle()
        #expect(active.string.isEmpty && !active.hasMarkedText())
        #expect(active.undoManager?.canUndo == false && active.undoManager?.canRedo == false)
    }
}
