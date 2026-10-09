import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanRevisionTests {
    @Test(arguments: [false, true]) func successAndNoChangeStayReadOnlyWhileFailureIsEdited(noChange: Bool) throws {
        let fixture = try TaskFieldCommandFixture()
        let adapter = MultiPlanRevisionSupport.adapter(fixture)
        _ = try MultiPlanRevisionSupport.queue(fixture, argument: TaskFieldCommandFixture.argument(0, unchanged: noChange))
        let last = try MultiPlanRevisionSupport.queue(fixture, kind: 1)
        fixture.io.beforeTransaction = {
            if try fixture.handoff.state().execution?.units.first?.state == .succeeded { throw TaskCreateCommandIO.Failure.injected }
        }
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        let original = try #require(fixture.handoff.state().execution)
        #expect(original.units[0].state == .succeeded && original.units[1].hasSafeLocalFailure)
        let oldLease = try fixture.handoff.owned().lease
        let ticket = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        #expect(try fixture.handoff.state().execution == nil)
        #expect(try fixture.handoff.state().plan.items.map(\.id) == [last.id])
        #expect(fixture.handoff.coordinator.revisionChain(HandoffFixture.source).first?.run == original)
        #expect(throws: (any Error).self) { try adapter.resume(expecting: oldLease) }
        #expect(throws: (any Error).self) { try adapter.returnRemaining(ticket, expecting: fixture.handoff.owned().lease) }
        fixture.io.beforeTransaction = nil
        try MultiPlanRevisionSupport.edit(last.id, argument: .init(parameter: .priority, operation: .assign, value: .choice("p1")), handoff: fixture.handoff)
        #expect(adapter.preview == nil && fixture.count("save") == (noChange ? 0 : 1))
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        let run = try #require(fixture.handoff.state().execution)
        #expect(run.stamp != original.stamp && run.units.count == 1 && run.units[0].state == .succeeded)
        #expect(fixture.base.todo.isImportant && fixture.base.todo.isUrgent)
        #expect(fixture.count("save") == (noChange ? 1 : 2) && fixture.count("ui") == (noChange ? 1 : 2))
        #expect(fixture.handoff.coordinator.revisionChain(HandoffFixture.source).first?.run == original)
        #expect(throws: (any Error).self) { try fixture.handoff.send(.result(#require(original.units[1].receipt))) }
    }

    @Test func savedProducerConsumerCanReturnTwiceWithoutRecreation() throws {
        let fixture = try MultiPlanOutputFixture(revisions: true)
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments("原对象"))
        let consumer = try fixture.queue("todo.title", [SubtaskCommandFixture.title("第一次")], from: producer)
        fixture.io.titleBeforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try fixture.start()
        try fixture.drain()
        let original = try fixture.run
        let output = try #require(original.outputs[producer.id])
        for title in ["返回一次", "返回两次"] {
            _ = try MultiPlanRevisionSupport.returnAll(fixture.adapter, fixture.handoff)
            let plan = try fixture.handoff.state().plan
            #expect(plan.items.count == 1 && plan.items[0].id == consumer.id)
            #expect(plan.items[0].links.results[.target]?.history?.object == output)
            try MultiPlanRevisionSupport.edit(consumer.id, argument: SubtaskCommandFixture.title(title), handoff: fixture.handoff)
            if title == "返回两次" { fixture.io.titleBeforeTransaction = nil }
            do { try fixture.start(); try fixture.drain() }
            catch { Issue.record("修订重新提交：\(type(of: error)) / \(error)"); return }
        }
        #expect(try fixture.run.units.allSatisfy { $0.state == .succeeded })
        let todos = try fixture.io.creation.capture.readTodos()
        #expect(todos.count == 1 && todos[0].id == output.id && todos[0].title == "返回两次")
        #expect(fixture.count("save") == 1 && fixture.count("saveTitle") == 1 && fixture.count("ui") == 2)
        let history = fixture.handoff.coordinator.revisionChain(HandoffFixture.source)
        #expect(history.count == 2 && history.last?.run == original)
    }

    @Test func unsubmittedProducerMigratesEveryBranchAndMultilevelReference() throws {
        let fixture = try MultiPlanOutputFixture(revisions: true)
        let chain = try fixture.chain()
        let branch = try fixture.queue("todo.title", [SubtaskCommandFixture.title("分支最终名")], from: chain[0])
        fixture.io.creation.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try fixture.start()
        let original = try fixture.run
        let creationID = try #require(fixture.handoff.coordinator.taskCreations.preparations[chain[0].draft.id]?.creationID)
        _ = try MultiPlanRevisionSupport.returnAll(fixture.adapter, fixture.handoff)
        let before = try fixture.handoff.state().plan
        try MultiPlanRevisionSupport.edit(chain[0].id, argument: SubtaskCommandFixture.title("新父标题"), handoff: fixture.handoff)
        let items = try fixture.handoff.state().plan.items
        #expect(CommandPlanValidation.structure(items).isEmpty)
        #expect(items[1].links.results[.parent]?.producer == items[0].stamp)
        #expect(items[2].links.results[.target]?.producer == items[1].stamp)
        #expect(items[3].id == branch.id && items[3].links.results[.target]?.producer == items[0].stamp)
        #expect(zip(items, before.items).allSatisfy { $0.version > $1.version })
        #expect(items[1].draft.arguments == before.items[1].draft.arguments && items[2].draft.arguments == before.items[2].draft.arguments)
        fixture.io.creation.beforeTransaction = nil
        try fixture.start()
        try fixture.drain()
        #expect(try fixture.run.units.allSatisfy { $0.state == .succeeded })
        #expect(try fixture.run.outputs[chain[0].id]?.id == creationID)
        #expect(try fixture.children().count == 1 && fixture.children()[0].todo?.id == creationID)
        #expect(fixture.count("save") == 1 && fixture.count("saveSubtask") == 2 && fixture.count("saveTitle") == 1)
        #expect(fixture.handoff.coordinator.revisionChain(HandoffFixture.source).first?.run == original)
    }

    @Test func completedOrderingAndCurrentBaselineArePreserved() throws {
        let fixture = try TaskFieldCommandFixture()
        let adapter = MultiPlanRevisionSupport.adapter(fixture)
        let first = try MultiPlanRevisionSupport.queue(fixture)
        let second = try MultiPlanRevisionSupport.queue(fixture)
        try fixture.handoff.plan(.link(second.stamp, .init(predecessors: [first.id])))
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff, maximum: 1)
        let original = try #require(fixture.handoff.state().execution)
        _ = try MultiPlanRevisionSupport.returnAll(adapter, fixture.handoff)
        let item = try #require(fixture.handoff.state().plan.items.first)
        #expect(item.links.completedPredecessors[first.id]?.execution == original.stamp)
        var stripped = item.links
        stripped.completedPredecessors = [:]
        #expect(throws: (any Error).self) { try fixture.handoff.plan(.link(item.stamp, stripped)) }
        let preview = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        guard case .taskField(let field) = preview.members[item.id] else { Issue.record("缺少真实字段预览"); return }
        #expect(field.original == .move("2026-10-09") && field.noChange)
        try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }

    @Test(arguments: [0, 1, 2]) func unknownExternalAndBusyRejectWholeReturn(mode: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        let adapter = MultiPlanRevisionSupport.adapter(fixture)
        _ = try MultiPlanRevisionSupport.queue(fixture)
        _ = try MultiPlanRevisionSupport.queue(fixture, kind: 1)
        if mode == 0 { fixture.io.saveMode = .throwAfter }
        if mode == 1 { fixture.io.notificationResult = .failed }
        var rejectedWhileCalling = false
        if mode == 2 { fixture.io.beforeTransaction = {
            do { _ = try adapter.prepareReturn(expecting: fixture.handoff.owned().lease) }
            catch { rejectedWhileCalling = true }
        } }
        try? MultiPlanRevisionSupport.start(adapter, fixture.handoff, maximum: 1)
        let before = try #require(fixture.handoff.state().execution)
        if mode < 2 {
            #expect(throws: (any Error).self) { _ = try adapter.prepareReturn(expecting: fixture.handoff.owned().lease) }
            #expect(try fixture.handoff.state().execution == before)
        } else { #expect(rejectedWhileCalling) }
        #expect(fixture.handoff.coordinator.revisionChain(HandoffFixture.source).isEmpty)
    }

    @Test func staleReturnTicketAndPreparationOccupationKeepOnlyOriginal() throws {
        let fixture = try TaskFieldCommandFixture()
        let adapter = MultiPlanRevisionSupport.adapter(fixture)
        _ = try MultiPlanRevisionSupport.queue(fixture)
        _ = try MultiPlanRevisionSupport.queue(fixture, kind: 1)
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff, maximum: 1)
        let before = try #require(fixture.handoff.state().execution)
        let ticket = try adapter.prepareReturn(expecting: fixture.handoff.owned().lease)
        try fixture.handoff.send(.query(.setInput("过期事件")))
        #expect(throws: (any Error).self) { try adapter.returnRemaining(ticket, expecting: fixture.handoff.owned().lease) }
        try fixture.handoff.coordinator.withMultiPlanPreparation(expecting: fixture.handoff.owned().lease) {
            #expect(throws: (any Error).self) { _ = try adapter.prepareReturn(expecting: fixture.handoff.owned().lease) }
        }
        #expect(try fixture.handoff.state().execution == before && fixture.handoff.state().plan.items.isEmpty)
    }
}
