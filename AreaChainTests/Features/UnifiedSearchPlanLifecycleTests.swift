import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchPlanLifecycleTests {
    @Test func clearQueryPageCollapseBlurAndLockNeverDeletePlan() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        let item = try fixture.enqueueOperation("todo.create")
        let before = fixture.controller.plan
        _ = fixture.controller.edit(.init(source: fixture.controller.buffer, text: "", selection: .init(location: 0, length: 0)))
        await fixture.controller.objectSelectionTask?.value
        #expect(fixture.controller.plan == before)
        try fixture.handoff.send(.query(.enterPage(QuerySessionFixture.page(.settings, host: HandoffFixture.source))))
        _ = fixture.controller.publishOperation(text: "")
        #expect(fixture.controller.plan == before)
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        fixture.controller.beginPlanEditing(item.stamp, source: fixture.controller.buffer)
        try await host.settle()
        let editor = try await host.focusParameter(.title)
        editor.insertText("Ordinary synthetic draft", replacementRange: editor.selectedRange())
        try await host.settle()
        let edited = fixture.controller.plan
        let old = fixture.controller.buffer
        let panel = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { SystemPageHost.release(other) }
        other.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(other)
        #expect(panel.subviews.isEmpty && editor.string.isEmpty)
        #expect(fixture.controller.plan == edited)
        #expect(!fixture.controller.removePlanItem(item.stamp, source: old))
        host.window.makeKeyAndOrderFront(nil)
        try await host.settle()
        try fixture.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        fixture.controller.refreshOperationPresentation()
        try await host.settle()
        NotificationCenter.default.post(name: .privacyWillLock, object: fixture.vault)
        #expect(panel.subviews.isEmpty && fixture.controller.plan == edited)
        try host.snapshot("plan-locked")
    }

    @Test func handoffRejectsOldPlanAndPickerCallbacksWithoutChangingReceiver() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        let item = try fixture.enqueueOperation("todo.completion")
        fixture.controller.beginPlanEditing(item.stamp, source: fixture.controller.buffer)
        let picker = try await fixture.chooseObjects()
        let old = fixture.controller.buffer
        _ = try fixture.handoff.transfer()
        let receiver = try fixture.handoff.state(HandoffFixture.target)
        #expect(fixture.controller.plan == nil && !fixture.controller.operationVisible)
        #expect(!fixture.controller.acceptObjects(picker.stamp))
        #expect(!fixture.controller.removePlanItem(item.stamp, source: old))
        fixture.controller.movePlanItem(item.stamp, offset: 1, source: old)
        #expect(try fixture.handoff.state(HandoffFixture.target) == receiver)
        #expect(try fixture.handoff.state().plan.items.isEmpty)
    }

    @Test func commandReturnAndSubmitNeverSealExecuteClearOrWritePreferences() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try fixture.enqueueOperation("setting.language", arguments: [PlanFixture.argument(.value, .choice("english"))])
        let before = try fixture.handoff.state()
        #expect(before.plan.check().canSealProtocol)
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let preferences = UserDefaults.standard.dictionaryRepresentation() as NSDictionary
        try await host.key(36, "\r", flags: .command)
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(try fixture.handoff.state() == before)
        #expect(fixture.controller.planMessage == "unified.plan.notExecutable")
        #expect(UserDefaults.standard.dictionaryRepresentation() as NSDictionary == preferences)
        #expect(fixture.opens.isEmpty)
        try host.snapshot("plan-submit-blocked")
    }
}
