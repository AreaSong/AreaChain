import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct CommandTextProtectedUITests {
    @Test func nativeParameterProtectFailureLockRecoveryAndPendingConfirmation() async throws {
        let synthetic = try ProtectedDraftFixture()
        let f = try UnifiedSearchResultsFixture(testVault: synthetic.vault)
        defer { f.stop(); SealedCommandDraft.testingBeforeSeal = nil }
        _ = try await f.publish()
        f.controller.assembleLongText(vault: synthetic.vault)
        try f.startOperation("todo.notes")
        let host = UnifiedSearchTestHost(width: 740, locale: "zh-Hans", results: f.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickResult("unified.longText.open.notes")
        let ordinary = try #require(f.controller.longTextEditing?.editor)
        try #require(host.window.makeFirstResponder(ordinary))
        ordinary.insertText("基线", replacementRange: .init(location: 0, length: 0))
        SealedCommandDraft.testingBeforeSeal = { throw PrivacyError.corruptData }
        f.controller.protectLongText(source: f.controller.buffer)
        #expect(f.controller.longTextMessage == "unified.longText.notProtected")
        #expect(ordinary.string == "基线" && f.controller.editingDraft?.protectedReference == nil)
        SealedCommandDraft.testingBeforeSeal = nil
        f.controller.protectLongText(source: f.controller.buffer)
        #expect(ordinary.string.isEmpty && ordinary.access == nil)
        try await host.settle()
        try await host.clickResult("unified.longText.open.notes")
        let protected = try #require(f.controller.longTextEditing?.editor)
        try #require(host.window.makeFirstResponder(protected))
        protected.setMarkedText("zhong", selectedRange: .init(location: 5, length: 0), replacementRange: .init(location: 0, length: 2))
        let accepted = try #require(protected.access)
        synthetic.vault.lock()
        #expect(protected.string.isEmpty && protected.access == nil)
        try synthetic.unlock()
        try await host.settle()
        #expect(protected.string.isEmpty)
        try f.handoff.send(.query(.enterPage(QuerySessionFixture.page(.overview, host: HandoffFixture.source))))
        _ = f.controller.publishOperation(text: "/tasks/notes")
        try f.session.resumeDisplay(expecting: f.controller.buffer.lease)
        try await host.settle()
        _ = try await f.publish()
        #expect(f.controller.beginOperation(.init(rawValue: "todo.notes"), source: f.controller.buffer) != nil)
        try await host.settle()
        try await host.clickResult("unified.longText.open.notes")
        let recovered = try #require(f.controller.longTextEditing?.editor)
        #expect(recovered.pendingConfirmation && !recovered.hasMarkedText() && recovered.string == "zhong")
        protected.synchronize("late", selection: .init(location: 0, length: 0), expecting: accepted)
        #expect(recovered.string == "zhong")
        let confirm = try host.resultNode("unified.longText.confirm")
        try await SettingsButtonTestSupport.reveal(confirm, in: host.window)
        try await host.settle()
        try host.snapshot("CM1-protected-pending")
        try await host.clickResult("unified.longText.confirm")
        let content = try #require(f.controller.longTextContent)
        let state = try content.nativeState(#require(recovered.access), owner: recovered)
        #expect(state.composition == nil && state.confirmedText == "zhong")
        #expect(f.controller.editingDraft?.arguments.isEmpty == true)
        #expect(try f.handoff.state().execution == nil)
    }
}
