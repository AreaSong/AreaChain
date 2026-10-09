import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanRecoveryTests {
    @Test func retryKeepsOriginalRunHistoryAndDoesNotReplaySuccessfulUnit() throws {
        let fixture = try TaskFieldCommandFixture()
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        for kind in 0..<3 {
            try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: TaskFieldCommandFixture.command(kind)),
                targets: .init(.single, objects: [.init(type: .todo, id: fixture.base.todo.id)]),
                arguments: [TaskFieldCommandFixture.argument(kind)]))
        }
        let items = try fixture.handoff.state().plan.items
        try fixture.handoff.plan(.link(items[1].stamp, .init(predecessors: [items[0].id])))
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
                                              adapters: .init(taskField: fixture.adapter))
        let preview = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        var calls = 0
        fixture.io.beforeTransaction = {
            calls += 1
            if calls == 1 { throw TaskCreateCommandIO.Failure.injected }
        }
        try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let before = try #require(fixture.handoff.state().execution)
        let attempt = try #require(before.attempt(items[0].id))
        try adapter.retryLocal(attempt, expecting: fixture.handoff.owned().lease)
        let after = try #require(fixture.handoff.state().execution)
        #expect(after.stamp == before.stamp && after.snapshot == before.snapshot)
        #expect(after.units.allSatisfy { $0.state == .succeeded })
        #expect(after.units[2] == before.units[2])
        #expect(after.units[0].history.first?.receipt?.attempt == attempt)
        #expect(after.units[0].history.first?.taskField?.state == .notSubmitted)
        #expect(fixture.count("save") == 3 && fixture.count("ui") == 3)
        #expect(throws: (any Error).self) {
            try fixture.handoff.send(.result(.init(attempt: attempt, result: .failedWithoutCommit)))
        }
        #expect(fixture.count("save") == 3)
    }

    @Test func largerPlanUsesRealCreateOutputAndRequiresFreshConsumerAcceptance() throws {
        let fixture = try TaskChainCommandFixture()
        try fixture.queue("消费者标题")
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                                       arguments: TaskCreateCommandFixture.arguments("独立创建")))
        let create = TaskCreateCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.io.createEnvironment)
        let title = TaskTitleCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.io.titleEnvironment)
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(taskCreate: create, taskTitle: title))
        let preview = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        #expect(try fixture.io.creation.capture.readTodos().isEmpty)
        try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let before = try fixture.run
        let created = try #require(before.units[0].taskCreation?.savedID)
        #expect(before.units[0].state == .succeeded && before.units[1].attempt == 0 && before.units[2].attempt == 0)
        guard case .taskTitle(let consumer) = adapter.pending else { Issue.record("必须有真实消费者预览"); return }
        #expect(consumer.impact.target.id == created)
        #expect(consumer.binding.multiOutput?.object.id == created)
        #expect(try fixture.io.creation.capture.readTodos().first?.title == "第一步")
        try adapter.confirmPending(expecting: fixture.handoff.owned().lease)
        let run = try fixture.run
        #expect(run.units.allSatisfy { $0.state == .succeeded })
        #expect(run.units[0] == before.units[0])
        let todos = try fixture.io.creation.capture.readTodos()
        #expect(todos.count == 2 && todos.first(where: { $0.id == created })?.title == "消费者标题")
        #expect(fixture.io.creation.capture.trace.filter { $0 == "save" }.count == 2)
        #expect(fixture.io.creation.capture.trace.filter { $0 == "saveTitle" }.count == 1)
    }
}
