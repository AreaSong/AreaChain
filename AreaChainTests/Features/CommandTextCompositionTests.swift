import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CommandTextCompositionTests {
    @Test func ordinaryUnconfiguredCompositionPasteSelectionDeletionAndUndo() throws {
        let f = try ProtectedDraftFixture(configured: false)
        try f.start()
        let editor = CommandProtectedTextView(session: f.service)
        defer { editor.end() }
        try editor.begin(using: f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        editor.insertText("中文🙂e\u{301}\n第二行/#@!", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        editor.setSelectedRange(NSRange(location: 0, length: 2))
        for text in ["p", "pin", "拼音"] {
            editor.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0),
                                 replacementRange: NSRange(location: NSNotFound, length: 0))
            #expect(editor.hasMarkedText())
            #expect(try f.draft().arguments.first?.value == .longText("中文🙂e\u{301}\n第二行/#@!"))
        }
        editor.insertText("拼音", replacementRange: editor.markedRange())
        #expect(try f.draft().arguments.first?.value == .longText("拼音🙂e\u{301}\n第二行/#@!"))
        editor.undoManager?.undo()
        #expect(editor.string == "中文🙂e\u{301}\n第二行/#@!")
        editor.undoManager?.redo()
        #expect(editor.string.hasPrefix("拼音"))
        editor.setSelectedRange(NSRange(location: 4, length: 0))
        editor.deleteBackward(nil)
        #expect(!editor.string.contains("🙂"))
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("\n粘贴", forType: .string)
        #expect(editor.readSelection(from: board, type: .string))
        let retained = try f.draft().arguments
        f.vault.lock()
        #expect(editor.string.isEmpty)
        #expect(try f.draft().arguments == retained)
        #expect(try f.draft().protectedReference == nil)
    }

    @Test(arguments: [false, true])
    func compositionCancellationRestoresSelectionAndDoesNotCreateUndo(emptyInsert: Bool) throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        let original = f.editor.string
        f.editor.setSelectedRange(NSRange(location: 0, length: 9))
        f.editor.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        if emptyInsert { f.editor.insertText("", replacementRange: f.editor.markedRange()) }
        else { f.editor.cancelOperation(nil) }
        try f.expectCurrent(original)
        #expect(f.editor.selectedRange() == NSRange(location: 0, length: 9))
        #expect(f.editor.undoManager?.canUndo == false)
    }

    @Test func lockMidCompositionRestoresPendingWithoutAutomaticallyConfirming() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        let old = try #require(f.editor.access)
        f.editor.setMarkedText("未完成🙂", selectedRange: NSRange(location: 5, length: 0),
                               replacementRange: NSRange(location: 0, length: 9))
        let point = try f.protected.service.nativeRecoveryPoint(#require(f.editor.access), owner: f.editor)
        #expect(try point.open(keys: f.protected.vault.keys).arguments.first?.value == .longText("synthetic-body"))
        f.protected.vault.lock()
        #expect(f.editor.string.isEmpty && !f.editor.hasMarkedText())
        try f.protected.unlock()
        #expect(f.editor.string.isEmpty)
        try f.editor.begin(using: f.protected.restore())
        #expect(f.editor.pendingConfirmation && !f.editor.hasMarkedText())
        #expect(f.editor.string == "未完成🙂-body")
        f.editor.synchronize("late", selection: NSRange(location: 0, length: 0), expecting: old)
        #expect(f.editor.string == "未完成🙂-body")
        f.editor.confirmPendingInput()
        try f.expectCurrent("未完成🙂-body")
        #expect(!f.editor.pendingConfirmation)
    }

    @Test func invalidUnicodeRangesAndFailedMarkedCheckpointPreservePriorState() throws {
        let f = try CommandNativeFixture()
        defer { SealedCommandDraft.testingBeforeSeal = nil; f.close() }
        f.editor.insertText("🙂e\u{301}\n中", replacementRange: NSRange(location: 0, length: f.editor.string.utf16.count))
        let before = try f.protected.host.owned()
        f.editor.setSelectedRange(NSRange(location: 1, length: 0))
        f.editor.setSelectedRange(NSRange(location: 3, length: 0))
        f.editor.setMarkedText("x", selectedRange: NSRange(location: 2, length: 0),
                               replacementRange: NSRange(location: 0, length: 0))
        #expect(try f.protected.host.owned() == before)
        SealedCommandDraft.testingBeforeSeal = { throw PrivacyError.corruptData }
        f.editor.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0),
                               replacementRange: NSRange(location: 0, length: 0))
        #expect(try f.protected.host.owned() == before)
        try f.expectCurrent("🙂e\u{301}\n中")
    }

    @Test func ordinaryProtectionFailureKeepsDraftAndSuccessfulProtectionCannotDowngrade() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        let editor = CommandProtectedTextView(session: f.service)
        defer { editor.end(); SealedCommandDraft.testingBeforeSeal = nil }
        try editor.begin(using: f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        editor.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0),
                             replacementRange: NSRange(location: 0, length: 9))
        let before = try f.host.owned()
        SealedCommandDraft.testingBeforeSeal = { throw PrivacyError.corruptData }
        #expect(throws: (any Error).self) { try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        #expect(try f.host.owned() == before && editor.hasMarkedText())
        SealedCommandDraft.testingBeforeSeal = nil
        _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease)
        #expect(editor.string.isEmpty && editor.access == nil)
        #expect(try f.draft().arguments.isEmpty)
        #expect(throws: (any Error).self) { try f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease) }
        try editor.begin(using: f.restore())
        #expect(editor.pendingConfirmation && editor.string == "zhong-body")
        editor.cancelOperation(nil)
        #expect(editor.string == "synthetic-body")
    }

    @Test func onlyExplicitPlanLocationCanAttachAndVersionsAdvanceWithoutActiveCopy() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease)
        try f.host.send(.enqueue(f.draft().stamp, itemID: UUID(), plan: f.host.state().plan.stamp))
        let item = try #require(f.host.state().plan.items.first)
        try f.host.send(.plan(.beginEditing(item.stamp), f.host.state().plan.stamp))
        let access = try f.service.explicitlyRestore(item.draft.stamp, expecting: f.host.owned().lease)
        let editor = CommandProtectedTextView(session: f.service)
        defer { editor.end() }
        try editor.begin(using: access)
        editor.insertText("计划正文", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        let next = try #require(f.host.state().plan.items.first)
        #expect(next.version > item.version && next.draft.version > item.draft.version)
        #expect(try f.host.state().operations.active == nil)
        #expect(try f.service.nativeState(#require(editor.access), owner: editor).confirmedText == "计划正文")
        try f.host.send(.plan(.endEditing(next.stamp, .cancelKeepingChanges), f.host.state().plan.stamp))
        #expect(editor.string.isEmpty && editor.access == nil)
        #expect(throws: (any Error).self) { try f.host.seal() }
    }
}
