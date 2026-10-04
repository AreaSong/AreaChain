import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CommandNativeEditingTests {
    @Test func insertionReplacementDeletionPasteAndSelectionHaveExactCheckpoints() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        let editor = f.editor
        let old = try #require(editor.access)
        editor.insertText("中文🙂e\u{301}\n第二行", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try f.expectCurrent("中文🙂e\u{301}\n第二行")
        #expect(throws: (any Error).self) { try f.protected.service.withRestoredContents(old) { _ in } }
        editor.setSelectedRange(NSRange(location: 0, length: 2))
        editor.insertText("替换", replacementRange: NSRange(location: NSNotFound, length: 0))
        editor.setSelectedRange(NSRange(location: 4, length: 0))
        editor.deleteBackward(nil)
        try f.expectCurrent("替换e\u{301}\n第二行")
        editor.deleteForward(nil)
        try f.expectCurrent("替换\n第二行")
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("\n多行\n#合成/不执行", forType: .string)
        #expect(editor.readSelection(from: board, type: .string))
        try f.expectCurrent("替换\n多行\n#合成/不执行\n第二行")
        let count = editor.checkpointCount
        editor.didChangeText()
        #expect(editor.checkpointCount == count)
        #expect(try f.protected.host.state().execution == nil)
    }

    @Test func ownedUndoRedoReprotectAndLockCannotRestoreText() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        let other = UndoManager()
        let target = UndoTarget()
        other.registerUndo(withTarget: target) { $0.value += 1 }
        f.editor.insertText("A", replacementRange: NSRange(location: 0, length: f.editor.string.utf16.count))
        f.editor.insertText("B", replacementRange: NSRange(location: 1, length: 0))
        let reference = try f.protected.draft().protectedReference
        f.editor.undoManager?.undo()
        try f.expectCurrent("A")
        #expect(try f.protected.draft().protectedReference != reference)
        f.editor.undoManager?.redo()
        try f.expectCurrent("AB")
        f.protected.vault.lock()
        #expect(f.editor.string.isEmpty && f.editor.access == nil)
        #expect(f.editor.undoManager?.canUndo == false && f.editor.undoManager?.canRedo == false)
        #expect(other.canUndo)
        other.undo()
        #expect(target.value == 1)
        try f.protected.unlock()
        #expect(f.editor.string.isEmpty)
        try f.editor.begin(using: f.protected.restore())
        try f.expectCurrent("AB")
        #expect(f.editor.undoManager?.canUndo == false)
    }

    @Test func staleSyncLeaseHostAndUninstallationCannotEditLaterRevision() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        let old = try #require(f.editor.access)
        f.editor.insertText("new", replacementRange: NSRange(location: 0, length: f.editor.string.utf16.count))
        f.editor.synchronize("old", selection: NSRange(location: 0, length: 0), expecting: old)
        try f.expectCurrent("new")
        f.editor.string = "unversioned"
        try f.expectCurrent("new")
        #expect(!f.editor.shouldChangeText(in: NSRange(location: 0, length: 0), replacementString: "bypass"))
        try f.protected.host.send(.query(.privacyInvalidated))
        f.editor.insertText("stale-host", replacementRange: NSRange(location: 0, length: 0))
        #expect(f.editor.access == nil && f.editor.string.isEmpty)
        try f.editor.begin(using: f.protected.restore())
        f.editor.removeFromSuperview()
        #expect(f.editor.access == nil && f.editor.string.isEmpty)
        let other = CommandProtectedTextView(session: f.protected.service)
        try other.begin(using: f.protected.restore())
        f.editor.end()
        #expect(other.access != nil)
        other.end()
    }

    @Test func protectedMarkedUpdatesConfirmCancelStayRejectedAndOrdinaryAppKitComposes() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        let old = try f.protected.host.owned()
        for text in ["z", "zhong", "中🙂"] {
            f.editor.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0),
                                   replacementRange: NSRange(location: 0, length: 0))
            #expect(!f.editor.hasMarkedText() && f.editor.issue == .compositionUnsupported)
        }
        f.editor.unmarkText()
        f.editor.cancelOperation(nil)
        #expect(try f.protected.host.owned() == old)
        try f.expectCurrent("synthetic-body")
        let ordinary = DaybookAppKitTextView()
        ordinary.isRichText = false
        ordinary.string = "prefix"
        for text in ["z", "zhong", "中🙂"] {
            ordinary.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0),
                                   replacementRange: NSRange(location: 0, length: ordinary.string.utf16.count))
            #expect(ordinary.hasMarkedText())
        }
        ordinary.insertText("中🙂", replacementRange: ordinary.markedRange())
        #expect(!ordinary.hasMarkedText() && ordinary.string == "中🙂")
        ordinary.setMarkedText("临时", selectedRange: NSRange(location: 2, length: 0),
                               replacementRange: NSRange(location: 0, length: 0))
        ordinary.insertText("", replacementRange: ordinary.markedRange())
        #expect(!ordinary.hasMarkedText() && ordinary.string == "中🙂")
    }

    @Test func directMutableStorageIsAnExplicitAfterMutationCounterexample() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        let before = try f.protected.host.owned()
        f.editor.textStorage?.replaceCharacters(in: NSRange(location: 0, length: 0), with: "uncheckpointed")
        #expect(f.editor.issue == .unsupportedMutation)
        #expect(f.editor.string.isEmpty && f.editor.access == nil)
        #expect(try f.protected.host.owned() == before)
        try f.expectRecovery("synthetic-body")
    }

    @Test func focusedNativeLifecycleRevokesOnBlur() async throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        try await NativeSyntaxUI.prepareFocus(in: f.window)
        try #require(f.window.makeFirstResponder(f.editor))
        f.editor.insertText("焦点", replacementRange: NSRange(location: 0, length: f.editor.string.utf16.count))
        #expect(f.window.firstResponder === f.editor)
        f.editor.setMarkedText("zu", selectedRange: NSRange(location: 2, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        try #require(f.window.makeFirstResponder(nil))
        #expect(f.editor.string.isEmpty && !f.editor.hasMarkedText() && f.editor.access == nil)
        try f.expectRecovery("焦点")
    }
}

@MainActor private final class UndoTarget { var value = 0 }

@MainActor final class CommandNativeFixture {
    let protected: ProtectedDraftFixture
    let editor: CommandProtectedTextView
    let window: NSWindow

    init() throws {
        protected = try ProtectedDraftFixture()
        try protected.start()
        _ = try protected.service.protect(protected.draft().stamp, expecting: protected.host.owned().lease)
        editor = CommandProtectedTextView(session: protected.service)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(editor)
        try editor.begin(using: protected.restore())
    }

    func close() { editor.end(); window.close() }

    func expectCurrent(_ text: String) throws {
        #expect(editor.string == text)
        let access = try #require(editor.access)
        let point = try protected.service.nativeRecoveryPoint(access, owner: editor)
        let contents = try point.open(keys: protected.vault.keys)
        #expect(contents.baseline.original(.notes, targets: .init(.none)) == .uniform(.longText("synthetic-baseline")))
        #expect(contents.arguments.first { $0.parameter == .notes }?.value == .longText(text))
        if let state = contents.editing.first {
            #expect(state.spelling == text)
            #expect(state.selectionLocation == editor.selectedRange().location)
            #expect(state.selectionLength == editor.selectedRange().length)
        }
        #expect(point.reference == (try protected.draft().protectedReference))
    }

    func expectRecovery(_ text: String) throws {
        let contents = try protected.contents(protected.restore())
        #expect(contents.arguments.first { $0.parameter == .notes }?.value == .longText(text))
    }
}
