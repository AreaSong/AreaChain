import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchMultiPlanOutputRecoveryTests {
    let support = UnifiedSearchMultiPlanOutputTests()

    @Test func nativeProducerRetryPreservesUUIDBeforeCreatingChildren() async throws {
        let io = try MultiPlanOutputFixture()
        let fixture = try support.makeFixture(io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let items = try support.queueChain(fixture)
        _ = try await fixture.publish()
        let host = support.makeHost(controller, compact: false)
        defer { host.close() }
        try await host.start()
        try await support.link(host, consumer: items[1], producer: items[0], parameter: .parent)
        try await support.link(host, consumer: items[2], producer: items[1])
        try await host.clickCompositionControl("unified.multi.prepare")
        var rejected = false
        io.io.creation.beforeTransaction = {
            if !rejected { rejected = true; throw TaskCreateCommandIO.Failure.injected }
        }
        try await host.clickCompositionControl("unified.multi.submit")
        try await support.settle(host, controller)
        let failed = try #require(controller.settingExecution)
        let reserved = try #require(fixture.handoff.coordinator.taskCreations.preparations[items[0].draft.id]?.creationID)
        #expect(failed.units[0].state == .failed && failed.units.dropFirst().allSatisfy { $0.state == .blocked && $0.attempt == 0 })
        #expect(io.count("save") == 0 && io.count("saveSubtask") == 0)
        try await host.revealSettingControlInsidePanel("unified.multi.retry." + items[0].id.uuidString)
        try host.snapshot("pm2-producer-failure")
        try await host.clickCompositionControl("unified.multi.retry." + items[0].id.uuidString)
        try await support.settle(host, controller)
        #expect(controller.settingExecution?.units[0].taskCreation?.savedID == reserved)
        for _ in 0..<2 {
            try await host.clickCompositionControl("unified.multi.confirm")
            try await support.settle(host, controller)
        }
        let child = try #require(io.children().first)
        #expect(child.todo?.id == reserved && child.title == "新子标题")
        #expect(controller.settingExecution?.units.allSatisfy { $0.state == .succeeded } == true)
        #expect(io.count("save") == 1 && io.count("saveSubtask") == 2 && io.count("ui") == 3)
        try await host.revealSettingControlInsidePanel("unified.multi.unit." + items[2].id.uuidString)
        try host.snapshot("pm2-producer-retried")
    }

    @Test(arguments: [0, 1, 2]) func nativeUnknownAtAnyLayerStopsEntirePlan(position: Int) async throws {
        let io = try MultiPlanOutputFixture()
        let fixture = try support.makeFixture(io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let items = try support.queueChain(fixture)
        _ = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments("独立项"))
        _ = try await fixture.publish()
        let host = support.makeHost(controller, compact: position != 0)
        defer { host.close() }
        try await host.start()
        try await support.link(host, consumer: items[1], producer: items[0], parameter: .parent)
        try await support.link(host, consumer: items[2], producer: items[1])
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let editor = try host.editor
        editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        controller.prepareMultiPlan(controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(controller.currentMultiPlanPreview == nil && io.count("save") == 0)
        editor.unmarkText()
        try await host.clickCompositionControl("unified.multi.prepare")
        if position == 0 { io.io.creation.saveMode = .throwAfter }
        else { io.subtaskBefore = { if io.count("saveSubtask") == position - 1 { io.subtaskSaveMode = .throwAfter } } }
        let old = controller.buffer
        try await host.clickCompositionControl("unified.multi.submit")
        try await support.settle(host, controller)
        for _ in 0..<position {
            try await host.clickCompositionControl("unified.multi.confirm")
            try await support.settle(host, controller)
        }
        let run = try #require(controller.settingExecution)
        #expect(run.hasUnknownCommit && run.units[position].local == .unknown)
        #expect(run.units.dropFirst(position + 1).allSatisfy { $0.attempt == 0 })
        #expect(io.count("save") + io.count("saveSubtask") == position + 1 && io.count("ui") == position)
        let rows = try io.io.creation.capture.readTodos()
        #expect(rows.count == 1)
        if position > 0 {
            let child = try #require(io.children().first)
            #expect(child.todo?.id == rows[0].id && child.title == (position == 2 ? "新子标题" : "子任务"))
        }
        try await host.revealSettingControlInsidePanel("unified.multi.paused")
        try host.snapshot("pm2-unknown-layer-\(position)")
        controller.requestOperationSubmit(old)
        try await host.key(36, "\r", flags: .command)
        #expect(controller.settingExecution == run)
        #expect(io.count("save") + io.count("saveSubtask") == position + 1)
    }

    @Test func newDisplayEventMustReviewActualCreatedParentAgain() async throws {
        let io = try MultiPlanOutputFixture()
        let fixture = try support.makeFixture(io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let items = try support.queueChain(fixture)
        _ = try await fixture.publish()
        let host = support.makeHost(controller, compact: true)
        defer { host.close() }
        try await host.start()
        try await support.link(host, consumer: items[1], producer: items[0], parameter: .parent)
        try await support.link(host, consumer: items[2], producer: items[1])
        try await host.clickCompositionControl("unified.multi.prepare")
        let old = controller.buffer
        io.io.creation.onRefresh = { try fixture.session.loseFocus(expecting: old.lease.ownership) }
        try await host.clickCompositionControl("unified.multi.submit")
        try await support.settle(host, controller)
        #expect(!controller.operationVisible && controller.multiPlan?.requiresDisplayReview == true)
        let run = try #require(controller.settingExecution)
        #expect(run.units[0].local == .committed && run.units[1].attempt == 0)
        io.io.creation.onRefresh = nil
        try fixture.session.resumeDisplay(expecting: controller.buffer.lease)
        controller.refreshOperationPresentation()
        try await host.settle()
        controller.requestOperationSubmit(old)
        #expect(controller.settingExecution == run && io.count("saveSubtask") == 0)
        try await host.clickCompositionControl("unified.multi.reviewRemaining")
        #expect(controller.multiPlan?.pending != nil && io.count("saveSubtask") == 0)
        try await host.revealSettingControlInsidePanel("unified.multi.confirm")
        try host.snapshot("pm2-display-new-acceptance")
        io.sourceRevision = UUID()
        try await host.clickCompositionControl("unified.multi.confirm")
        try await support.settle(host, controller)
        #expect(io.count("saveSubtask") == 0 && controller.multiPlan?.pending != nil)
        for _ in 0..<2 {
            try await host.clickCompositionControl("unified.multi.confirm")
            try await support.settle(host, controller)
        }
        #expect(controller.settingExecution?.units.allSatisfy { $0.state == .succeeded } == true)
        #expect(io.count("save") == 1 && io.count("saveSubtask") == 2 && io.count("ui") == 3)
    }
}
