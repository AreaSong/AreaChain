import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CommandNativeFailureTests {
    @Test func initialRestoreFailureNeverInstallsNativeText() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        let editor = CommandProtectedTextView(session: f.service)
        SealedCommandDraft.testingAfterOpen = { f.vault.lock() }
        defer { SealedCommandDraft.testingAfterOpen = nil; editor.end() }
        #expect(throws: (any Error).self) { try editor.begin(using: f.restore()) }
        #expect(editor.string.isEmpty && editor.access == nil)
        #expect(try f.draft().protectedReference != nil)
    }

    @Test func sealAndEncodingFailureKeepVisibleAcceptedRevision() throws {
        let f = try CommandNativeFixture()
        defer { SealedCommandDraft.testingBeforeSeal = nil; f.close() }
        let before = try f.protected.host.owned()
        SealedCommandDraft.testingBeforeSeal = { throw PrivacyError.corruptData }
        f.editor.insertText("rejected", replacementRange: NSRange(location: 0, length: 0))
        #expect(f.editor.issue == .rejected)
        #expect(try f.protected.host.owned() == before)
        try f.expectCurrent("synthetic-body")
        SealedCommandDraft.testingBeforeSeal = nil
        let state = CommandDraftEditingState(parameter: "notes", spelling: "bad", selectionLocation: -1, selectionLength: 0)
        #expect(throws: (any Error).self) {
            try f.protected.service.acceptNative(state, using: #require(f.editor.access), owner: f.editor)
        }
        #expect(try f.protected.host.owned() == before)
        try f.expectCurrent("synthetic-body")
    }

    @Test(arguments: [false, true])
    func lockBeforeCheckpointOrAfterCheckpointBeforeNativeAcceptance(after: Bool) throws {
        let f = try CommandNativeFixture()
        defer { SealedCommandDraft.testingBeforeSeal = nil; f.close() }
        let before = try f.protected.host.owned()
        if after { f.editor.testingAfterCheckpoint = { f.protected.vault.lock() } }
        else { SealedCommandDraft.testingBeforeSeal = { f.protected.vault.lock() } }
        f.editor.insertText("next", replacementRange: NSRange(location: 0, length: f.editor.string.utf16.count))
        #expect(f.editor.string.isEmpty && f.editor.access == nil)
        #expect(!f.editor.hasMarkedText() && f.editor.undoManager?.canUndo == false)
        #expect((try f.protected.host.owned() == before) == !after)
        try f.protected.unlock()
        #expect(f.editor.string.isEmpty)
        try f.expectRecovery(after ? "next" : "synthetic-body")
    }

    @Test func nativeReentryRevokesOuterCandidateAndOldEchoCannotPublish() throws {
        let f = try CommandNativeFixture()
        defer { SealedCommandDraft.testingBeforeSeal = nil; f.close() }
        let old = try #require(f.editor.access)
        let before = try f.protected.host.owned()
        SealedCommandDraft.testingBeforeSeal = {
            f.editor.insertText("inner", replacementRange: NSRange(location: 0, length: 0))
        }
        f.editor.insertText("outer", replacementRange: NSRange(location: 0, length: 0))
        #expect(try f.protected.host.owned() == before)
        #expect(f.editor.access == nil && f.editor.string.isEmpty)
        SealedCommandDraft.testingBeforeSeal = nil
        try f.editor.begin(using: f.protected.restore())
        f.editor.synchronize("old-echo", selection: NSRange(location: 0, length: 0), expecting: old)
        f.editor.didChangeText()
        try f.expectCurrent("synthetic-body")
    }

    @Test(arguments: [false, true])
    func undoAndRedoInvalidationNeverRevealHistory(redo: Bool) throws {
        let f = try CommandNativeFixture()
        defer { SealedCommandDraft.testingBeforeSeal = nil; f.close() }
        f.editor.insertText("A", replacementRange: NSRange(location: 0, length: f.editor.string.utf16.count))
        f.editor.insertText("B", replacementRange: NSRange(location: 1, length: 0))
        if redo { f.editor.undoManager?.undo() }
        SealedCommandDraft.testingBeforeSeal = { f.protected.vault.lock() }
        if redo { f.editor.undoManager?.redo() }
        else { f.editor.undoManager?.undo() }
        #expect(f.editor.string.isEmpty && f.editor.access == nil)
        #expect(f.editor.undoManager?.canUndo == false && f.editor.undoManager?.canRedo == false)
        try f.protected.unlock()
        try f.expectRecovery(redo ? "A" : "AB")
    }

    @Test func markedUpdateLockAndUnmountNeverPretendIMEWasPreserved() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        f.editor.testingBeforeMarkedText = { f.protected.vault.lock() }
        f.editor.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0),
                               replacementRange: NSRange(location: NSNotFound, length: 0))
        f.editor.removeFromSuperview()
        #expect(f.editor.string.isEmpty && !f.editor.hasMarkedText() && f.editor.access == nil)
        try f.protected.unlock()
        try f.expectRecovery("synthetic-body")
        // 被拒绝的系统输入不是已接受内容；旧密文不含 zhong，不能宣称输入法暂存已保全。
        #expect(f.editor.checkpointCount == 0)
    }

    @Test func planLocationIsExplicitlyClosedWithoutCopyingToActive() throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.protect()
        let id = UUID()
        try f.host.send(.enqueue(f.draft().stamp, itemID: id, plan: f.host.state().plan.stamp))
        let item = try #require(f.host.state().plan.items.first)
        let access = try f.service.explicitlyRestore(item.draft.stamp, expecting: f.host.owned().lease)
        let editor = CommandProtectedTextView(session: f.service)
        #expect(throws: CommandDraftProtectionError.unsupported) { try editor.begin(using: access) }
        #expect(try f.host.state().operations.active == nil)
        #expect(editor.string.isEmpty && editor.access == nil)
        #expect(throws: (any Error).self) { try f.host.seal() }
        #expect(try f.host.state().execution == nil)
    }

    @Test func nativeAcceptLatencySamplesIncludeCheckpointAndStorageUpdate() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        var rows = ["bytes,sample,milliseconds,checkpoints"]
        for bytes in [1_024, 65_536, 1_048_576] {
            let body = String(repeating: "中a🙂", count: bytes / 8)
            f.editor.insertText(body, replacementRange: NSRange(location: 0, length: f.editor.string.utf16.count))
            for index in 0..<6 {
                let count = f.editor.checkpointCount
                let start = ContinuousClock.now
                f.editor.insertText("字", replacementRange: NSRange(location: f.editor.string.utf16.count, length: 0))
                let elapsed = start.duration(to: .now).components
                let milliseconds = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
                #expect(f.editor.checkpointCount == count + 1 && f.editor.issue == nil)
                rows.append("\(bytes),\(index),\(milliseconds),\(f.editor.checkpointCount - count)")
            }
            try f.expectCurrent(body + String(repeating: "字", count: 6))
            f.editor.undoManager?.removeAllActions()
        }
        Attachment.record(Data(rows.joined(separator: "\n").utf8), named: "command-native-latency.csv")
    }
}
