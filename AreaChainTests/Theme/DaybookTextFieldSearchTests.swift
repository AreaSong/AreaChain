import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct DaybookTextFieldSearchTests {
    @Test func commandReturnOnlyReachesTheFocusedInput() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
        defer { window.orderOut(nil) }
        var captureCalled = false
        var searchCalled = false
        let capture = DaybookAppKitTextField(string: "未提交的待办草稿")
        let search = DaybookAppKitTextField(string: "")
        capture.frame = NSRect(x: 8, y: 60, width: 280, height: 28)
        search.frame = NSRect(x: 8, y: 12, width: 280, height: 28)
        capture.onCommandReturn = { captureCalled = true }
        search.onCommandReturn = { searchCalled = true }
        window.contentView?.addSubview(capture)
        window.contentView?.addSubview(search)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(search)
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "\r",
            charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
        ))
        #expect(!capture.performKeyEquivalent(with: event))
        #expect(window.performKeyEquivalent(with: event))
        #expect(searchCalled && !captureCalled)
    }

    @Test func mouseCompletionUpdatesLiveEditorAndCaret() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 80), styleMask: [.titled], backing: .buffered, defer: false)
        defer { window.orderOut(nil) }
        let field = DaybookAppKitTextField(string: "会议 #工")
        field.frame = NSRect(x: 8, y: 8, width: 280, height: 28)
        window.contentView?.addSubview(field)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.setSelectedRange(NSRange(location: 5, length: 0))

        DaybookTextField.synchronizeText("会议 #工作 ", in: field)
        #expect(editor.string == "会议 #工作 ")
        #expect(editor.selectedRange().location == 7)
        DaybookTextField.synchronizeText("", in: field)
        #expect(editor.string.isEmpty)
        #expect(editor.selectedRange().location == 0)
    }

    @Test func returnDuringChineseCompositionDoesNotCommitAutocomplete() {
        var text = "#工"
        var submitted = false
        let autocomplete = SyntaxAutocompleteState(context: .search)
        autocomplete.update(text: text, cursorLocation: 2, availableTags: ["工作"])
        var focused = false
        let field = DaybookTextField(
            text: Binding(get: { text }, set: { text = $0 }), placeholder: "test",
            focus: Binding(get: { focused }, set: { focused = $0 }), autocomplete: autocomplete, onSubmit: { submitted = true }
        )
        let editor = NSTextView()
        editor.setMarkedText("#工", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(editor.hasMarkedText())
        let handled = field.makeCoordinator().control(
            NSTextField(), textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))
        )
        #expect(!handled && !submitted)
        #expect(text == "#工")
    }

    @Test func escapeDismissesCandidatesBeforeClearingSearch() {
        var text = "#工"
        var escaped = false
        let autocomplete = SyntaxAutocompleteState(context: .search)
        autocomplete.update(text: text, cursorLocation: 2, availableTags: ["工作"])
        var focused = false
        let field = DaybookTextField(
            text: Binding(get: { text }, set: { text = $0 }), placeholder: "test",
            focus: Binding(get: { focused }, set: { focused = $0 }), autocomplete: autocomplete, onSubmit: {}, onEscape: { escaped = true }
        )
        let coordinator = field.makeCoordinator()
        let control = NSTextField()
        let editor = NSTextView()
        #expect(coordinator.control(control, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        #expect(!escaped && !autocomplete.isActive)
        #expect(coordinator.control(control, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        #expect(escaped)
    }
}
