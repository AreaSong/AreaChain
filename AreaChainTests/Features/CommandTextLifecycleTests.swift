import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CommandTextLifecycleTests {
    @Test func protectedCompositionAfterCheckpointLockAndExplicitPendingCancel() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        f.editor.testingAfterCheckpoint = { f.protected.vault.lock() }
        f.editor.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0),
                               replacementRange: NSRange(location: 0, length: 9))
        #expect(f.editor.issue == .acceptedNotDisplayed)
        #expect(f.editor.access == nil && f.editor.string.isEmpty)
        try f.protected.unlock()
        f.editor.testingAfterCheckpoint = nil
        try f.editor.begin(using: f.protected.restore())
        #expect(f.editor.pendingConfirmation && f.editor.string == "zhong-body")
        f.editor.cancelOperation(nil)
        try f.expectCurrent("synthetic-body")
    }

    @Test func protectedAppendThenClearRequireFreshOwnerAndKeepBaseline() throws {
        let f = try CommandNativeFixture()
        defer { f.close() }
        let old = try #require(f.editor.access)
        try f.editor.changeOperation(.append)
        #expect(f.editor.access == nil && f.editor.string.isEmpty)
        try f.editor.begin(using: f.protected.restore())
        f.editor.synchronize("late", selection: .init(location: 0, length: 0), expecting: old)
        f.editor.insertText("附加", replacementRange: .init(location: 0, length: f.editor.string.utf16.count))
        let contents = try f.protected.contents(#require(f.editor.access))
        #expect(contents.arguments.first?.operation == .append)
        #expect(contents.arguments.first?.value == .longText("附加"))
        #expect(contents.baseline.original(.notes, targets: .init(.none)) == .uniform(.longText("synthetic-baseline")))
        try f.editor.changeOperation(.clear)
        try f.editor.begin(using: f.protected.restore())
        #expect(!f.editor.isEditable && f.editor.string.isEmpty)
        let cleared = try f.protected.contents(#require(f.editor.access))
        #expect(cleared.arguments.first?.operation == .clear && cleared.arguments.first?.value == nil)
    }

    @Test func realParameterWindowBlurAndUnmountKeepUniqueDraft() async throws {
        let f = try UnifiedSearchResultsFixture()
        defer { f.stop() }
        _ = try await f.publish()
        f.controller.assembleLongText(vault: f.vault)
        try f.startOperation("todo.notes")
        let host = UnifiedSearchTestHost(results: f.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickResult("unified.longText.open.notes")
        let editor = try #require(f.controller.longTextEditing?.editor)
        try #require(host.window.makeFirstResponder(editor))
        editor.insertText("保留", replacementRange: .init(location: 0, length: 0))
        editor.setMarkedText("zhong", selectedRange: .init(location: 5, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
        let before = try f.draft
        let other = NSWindow(contentRect: .init(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { other.close() }
        other.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(other)
        #expect(other.isKeyWindow && !host.window.isKeyWindow)
        #expect(editor.string.isEmpty && editor.access == nil)
        #expect(try f.draft == before)
        f.controller.detach()
        #expect(try f.handoff.state().operations.active == before)
    }

    @Test func actualWorkspaceNavigationRetainsCompositionWithoutBusinessWrites() async throws {
        let f = try UnifiedSearchNavigationFixture()
        defer { f.stop() }
        try await f.start()
        f.controller.assembleLongText(vault: f.vault)
        #expect(f.controller.beginOperation(.init(rawValue: "todo.notes"), source: f.controller.buffer) != nil)
        f.controller.beginLongText(.notes, source: f.controller.buffer)
        try await f.settle()
        let editor = try #require(f.controller.longTextEditing?.editor)
        editor.insertText("导航保留", replacementRange: .init(location: 0, length: 0))
        editor.setMarkedText("zhong", selectedRange: .init(location: 5, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
        let before = try #require(f.controller.operations?.active)
        try await f.go("/go/settings")
        #expect(editor.string.isEmpty && editor.access == nil)
        #expect(f.controller.operations?.active == before)
        #expect(f.saves == 0 && f.publications == 0)
        try await f.back()
        #expect(f.controller.operations?.active == before)
        #expect(f.saves == 0 && f.publications == 0)
    }
}
