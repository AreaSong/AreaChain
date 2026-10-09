import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanCreationRetryTests {
    @Test func subtaskCreationRetryKeepsReservedObjectAndDoesNotReplayIndependentCreation() throws {
        let fixture = try SubtaskCommandFixture()
        let sentinel = try TaskCreateCommandIO()
        let create = try sentinelAdapter(sentinel, handoff: fixture.handoff)
        try fixture.queue("subtask.create", fixture.createArguments("可恢复子项"))
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
                                              adapters: .init(taskCreate: create, subtask: fixture.adapter))
        let preview = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        fixture.failMutation = true
        try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let before = try #require(fixture.handoff.state().execution)
        let reserved = try #require(before.units[1].subtask?.object)
        #expect(before.units[1].local == .notSubmitted && before.units[1].subtask?.rollback == .returned)
        fixture.failMutation = false
        try adapter.retryLocal(#require(before.attempt(before.units[1].id)), expecting: fixture.handoff.owned().lease)
        if adapter.pending != nil { try adapter.confirmPending(expecting: fixture.handoff.owned().lease) }
        let after = try #require(fixture.handoff.state().execution)
        #expect(after.units[0] == before.units[0] && after.units[1].subtask?.createdObject == reserved)
        #expect(try fixture.children().filter { $0.id == reserved.id }.count == 1)
        #expect(fixture.count("save") == 1 && sentinel.capture.trace.filter { $0 == "save" }.count == 1)
    }

    @Test func routineCreationRetryKeepsReservedIdentity() throws {
        let fixture = try RoutineCreateFixture()
        let sentinel = try TaskCreateCommandIO()
        let create = try sentinelAdapter(sentinel, handoff: fixture.handoff)
        try fixture.queue(title: "可恢复习惯")
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
                                              adapters: .init(taskCreate: create, routine: fixture.adapter))
        let preview = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        fixture.base.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let before = try #require(fixture.handoff.state().execution)
        let reserved = try #require(before.units[1].routineCreation?.creationID)
        #expect(before.units[1].local == .notSubmitted)
        fixture.base.beforeTransaction = nil
        try adapter.retryLocal(#require(before.attempt(before.units[1].id)), expecting: fixture.handoff.owned().lease)
        if adapter.pending != nil { try adapter.confirmPending(expecting: fixture.handoff.owned().lease) }
        let after = try #require(fixture.handoff.state().execution)
        #expect(after.units[0] == before.units[0] && after.units[1].routineCreation?.savedID == reserved)
        #expect(try fixture.stored(reserved).title == "可恢复习惯")
        #expect(fixture.base.count("save") == 1 && sentinel.capture.trace.filter { $0 == "save" }.count == 1)
    }

    private func sentinelAdapter(_ io: TaskCreateCommandIO, handoff: HandoffFixture) throws -> TaskCreateCommandAdapter {
        io.capture.calendarEnabled = true
        io.notificationResult = .succeeded
        io.calendarResult = .succeeded
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                               arguments: TaskCreateCommandFixture.arguments("独立已保存任务")))
        return TaskCreateCommandAdapter(coordinator: handoff.coordinator, environment: try io.environment())
    }
}
