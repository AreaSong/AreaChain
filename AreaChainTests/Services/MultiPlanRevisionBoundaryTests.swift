import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanRevisionBoundaryTests {
    @Test(arguments: [0, 1, 2, 3]) func historicalCredentialRejectsWrongScopeTypeOrReplacement(mode: Int) throws {
        let fixture = try MultiPlanOutputFixture(revisions: true)
        let parent = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments("原保存对象"))
        _ = try fixture.queue("todo.title", [SubtaskCommandFixture.title("后续")], from: parent)
        fixture.io.titleBeforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try fixture.start(); try fixture.drain()
        _ = try MultiPlanRevisionSupport.returnAll(fixture.adapter, fixture.handoff)
        let host = try fixture.handoff.owned()
        let item = try #require(host.session.plan.items.first)
        var reference = try #require(item.links.results[.target])
        if mode < 3 {
            var owner = host.lease.ownership
            var assembly = fixture.adapter.id
            if mode == 0 { owner = try fixture.handoff.owned(HandoffFixture.target).lease.ownership }
            if mode == 1 { assembly = UUID() }
            if mode == 2 { reference = .init(producer: reference.producer, outputType: .routine, history: reference.history) }
            #expect(throws: (any Error).self) { try fixture.handoff.coordinator.historicalOutput(reference, owner: owner, assemblyID: assembly) }
        } else {
            let original = try #require(fixture.io.creation.capture.readTodos().first)
            let id = original.id, record = original.persistentModelID
            fixture.context.delete(original); try fixture.context.save()
            let replacement = TodoItem(id: id, title: "相同UUID替身", dayKey: "2026-10-05")
            fixture.context.insert(replacement); try fixture.context.save()
            #expect(replacement.persistentModelID != record)
            #expect(throws: (any Error).self) { _ = try fixture.prepare() }
        }
        #expect(fixture.count("save") == 1 && fixture.count("saveTitle") == 0)
        #expect(try fixture.handoff.state().execution == nil && fixture.handoff.state().plan == host.session.plan)
    }

    @Test func editedCreationCollisionRejectsWithoutChangingReservedUUID() throws {
        let fixture = try MultiPlanOutputFixture(revisions: true)
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments())
        _ = try fixture.queue("todo.title", [SubtaskCommandFixture.title("消费者")], from: producer)
        fixture.io.creation.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try fixture.start()
        let id = try #require(fixture.handoff.coordinator.taskCreations.preparations[producer.draft.id]?.creationID)
        _ = try MultiPlanRevisionSupport.returnAll(fixture.adapter, fixture.handoff)
        try MultiPlanRevisionSupport.edit(producer.id, argument: SubtaskCommandFixture.title("改名不换身份"), handoff: fixture.handoff)
        fixture.context.insert(TodoItem(id: id, title: "碰撞记录", dayKey: "2026-10-05")); try fixture.context.save()
        fixture.io.creation.beforeTransaction = nil
        #expect(throws: (any Error).self) { try fixture.start() }
        #expect(fixture.handoff.coordinator.taskCreations.preparations[producer.draft.id]?.creationID == id)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test func subtaskCreationParentEditKeepsIdentityAndMigratesItsConsumer() throws {
        let fixture = try MultiPlanOutputFixture(revisions: true)
        let items = try fixture.chain()
        fixture.subtaskBefore = { throw TaskCreateCommandIO.Failure.injected }
        try fixture.start(); try fixture.drain()
        let id = try #require(fixture.handoff.coordinator.subtasks.acceptances[items[1].draft.id]?.object.id)
        _ = try MultiPlanRevisionSupport.returnAll(fixture.adapter, fixture.handoff)
        let child = try #require(fixture.handoff.state().plan.items.first)
        var links = child.links
        links.results = [:]
        try fixture.handoff.plan(.link(child.stamp, links))
        let other = TodoItem(title: "新显式父任务", dayKey: "2026-10-05")
        fixture.context.insert(other); try fixture.context.save()
        try MultiPlanRevisionSupport.edit(child.id, argument: .init(parameter: .parent, operation: .assign,
            value: .object(.init(type: .todo, id: other.id))), handoff: fixture.handoff)
        let revised = try fixture.handoff.state().plan.items
        #expect(revised[1].links.results[.target]?.producer == revised[0].stamp)
        fixture.subtaskBefore = nil
        try fixture.start(); try fixture.drain()
        let saved = try #require(fixture.children().first)
        #expect(saved.id == id && saved.todo?.id == other.id && saved.title == "新子标题")
        #expect(fixture.count("saveSubtask") == 2 && fixture.count("save") == 1)
    }

    @Test func returnedBatchRecomputesEntityLimitInsteadOfReusingOldWriteSet() throws {
        let fixture = try BatchCommandFixture(count: 2, stateOperations: true)
        try fixture.queue("batch.completion", argument: .init(parameter: .enabled, operation: .assign, value: .boolean(true)))
        try fixture.queue()
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(batch: fixture.adapter), supportsRevisions: true)
        fixture.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        _ = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        for index in 0..<4000 { fixture.context.insert(SubtaskItem(title: "合成子项", sortOrder: index, todo: fixture.todos[1])) }
        try fixture.context.save()
        fixture.beforeTransaction = nil
        #expect(throws: (any Error).self) { try MultiPlanRevisionSupport.start(adapter, fixture.handoff) }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
        #expect(try fixture.handoff.state().execution == nil)
    }

    @Test func rollbackBeforeSaveReturnsButUnknownAfterSaveCannot() throws {
        let fixture = try BatchCommandFixture()
        try fixture.queue(); try fixture.queue()
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(batch: fixture.adapter), supportsRevisions: true)
        let before = fixture.todos.map(\.dayKey)
        fixture.afterApply = { _ in throw TaskCreateCommandIO.Failure.injected }
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        let run = try #require(fixture.handoff.state().execution)
        #expect(run.units.allSatisfy { $0.batch?.rollback == .returned && $0.hasSafeLocalFailure })
        #expect(fixture.todos.map(\.dayKey) == before && fixture.count("save") == 0)
        _ = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        fixture.afterApply = nil
        fixture.saveMode = .throwAfter
        try? MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        #expect(throws: (any Error).self) { _ = try adapter.prepareReturn(expecting: fixture.handoff.owned().lease) }
        #expect(try fixture.handoff.state().execution?.hasUnknownCommit == true)
    }
}
