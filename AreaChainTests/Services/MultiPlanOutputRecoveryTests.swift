import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanOutputRecoveryTests {
    @Test(arguments: [0, 1, 2]) func retryKeepsEveryCreatedIdentityAndSuccessfulBranch(position: Int) throws {
        let fixture = try MultiPlanOutputFixture()
        let items = try fixture.chain()
        _ = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments("独立任务"))
        var failed = false
        if position == 0 {
            fixture.io.creation.beforeTransaction = {
                if !failed { failed = true; throw TaskCreateCommandIO.Failure.injected }
            }
        } else {
            fixture.subtaskBefore = {
                if !failed && fixture.count("saveSubtask") == position - 1 {
                    failed = true
                    throw TaskCreateCommandIO.Failure.injected
                }
            }
        }
        try fixture.start()
        try fixture.drain()
        let failedRun = try fixture.run
        #expect(failedRun.units[position].local == .notSubmitted && failedRun.units[position].state == .failed)
        #expect(failedRun.units.dropFirst(position + 1).dropLast().allSatisfy { $0.state == .blocked && $0.attempt == 0 })
        #expect(failedRun.units.last?.state == .succeeded)
        let parentReserved = try #require(fixture.handoff.coordinator.taskCreations.preparations[items[0].draft.id]?.creationID)
        let childReserved = fixture.handoff.coordinator.subtasks.acceptances[items[1].draft.id]?.object.id
        let attempt = try #require(failedRun.attempt(items[position].id))
        try fixture.adapter.retryLocal(attempt, expecting: fixture.handoff.owned().lease)
        try fixture.drain()
        let run = try fixture.run
        #expect(run.units.allSatisfy { $0.state == .succeeded } && run.units.last == failedRun.units.last)
        #expect(run.outputs[items[0].id]?.id == parentReserved)
        if let childReserved { #expect(run.outputs[items[1].id]?.id == childReserved) }
        #expect(run.units.prefix(position).elementsEqual(failedRun.units.prefix(position)))
        #expect(try fixture.children().count == 1 && fixture.io.creation.capture.readTodos().count == 2)
        #expect(fixture.count("save") == 2 && fixture.count("saveSubtask") == 2 && fixture.count("ui") == 4)
        #expect(run.units[position].history.contains { $0.number == attempt.number && $0.local == .notSubmitted })
        #expect(throws: (any Error).self) { try fixture.adapter.retryLocal(attempt, expecting: fixture.handoff.owned().lease) }
    }

    @Test(arguments: [0, 1, 2]) func localUnknownAtEveryLevelPausesIndependentItems(position: Int) throws {
        let fixture = try MultiPlanOutputFixture()
        let items = try fixture.chain()
        _ = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments("独立任务"))
        if position == 0 { fixture.io.creation.saveMode = .throwAfter }
        else {
            fixture.subtaskBefore = {
                if fixture.count("saveSubtask") == position - 1 { fixture.subtaskSaveMode = .throwAfter }
            }
        }
        try? fixture.start()
        for _ in 0..<position { try? fixture.confirm() }
        let run = try fixture.run
        #expect(run.hasUnknownCommit && run.units[position].local == .unknown)
        #expect(run.units.dropFirst(position + 1).allSatisfy { $0.attempt == 0 })
        let saves = fixture.count("save") + fixture.count("saveSubtask")
        #expect(saves == position + 1 && fixture.count("ui") == position)
        #expect(throws: (any Error).self) { try fixture.adapter.resume(expecting: fixture.handoff.owned().lease) }
        #expect(throws: (any Error).self) { try fixture.adapter.confirmPending(expecting: fixture.handoff.owned().lease) }
        #expect(throws: (any Error).self) {
            try fixture.adapter.retryLocal(#require(run.attempt(items[position].id)), expecting: fixture.handoff.owned().lease)
        }
        _ = try fixture.io.creation.capture.readTodos()
        _ = try fixture.children()
        #expect(try fixture.run == run && fixture.count("save") + fixture.count("saveSubtask") == saves)
    }

    @Test(arguments: [false, true]) func savedButExternalIncompleteNeverUnlocksChild(subtask: Bool) throws {
        let fixture = try MultiPlanOutputFixture()
        let items = try fixture.chain()
        if subtask { fixture.subtaskEnvironment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        else { fixture.io.creation.notificationResult = .failed }
        try fixture.start()
        if subtask { try fixture.confirm() }
        let run = try fixture.run
        let index = subtask ? 1 : 0
        #expect(run.units[index].local == .committed && run.units[index].state != .succeeded)
        #expect(run.outputs[items[index].id] != nil && run.units[index + 1].state == .blocked)
        #expect(run.creationOutput(for: .init(producer: items[index].stamp, outputType: subtask ? .subtask : .todo)) == nil)
        #expect(throws: (any Error).self) {
            try fixture.adapter.retryLocal(#require(run.attempt(items[index].id)), expecting: fixture.handoff.owned().lease)
        }
        #expect(fixture.count("save") == 1 && fixture.count("saveSubtask") == (subtask ? 1 : 0))
    }

    @Test func cancellationOfOneBranchPreservesOtherConsumersAndRealOutput() throws {
        let fixture = try MultiPlanOutputFixture()
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments("父任务"))
        let cancelled = try fixture.queue("todo.title", [SubtaskCommandFixture.title("取消项")], from: producer)
        _ = try fixture.queue("subtask.create", [SubtaskCommandFixture.title("保留项")], from: producer, parameter: .parent)
        try fixture.start()
        let output = try fixture.run.outputs
        try fixture.adapter.cancel(cancelled.id, expecting: fixture.handoff.owned().lease)
        try fixture.drain()
        #expect(try fixture.run.units[1].state == .notExecuted && fixture.run.units[2].state == .succeeded)
        #expect(try fixture.run.outputs[producer.id] == output[producer.id] && fixture.children().count == 1)
        #expect(fixture.count("save") == 1 && fixture.count("saveTitle") == 0 && fixture.count("saveSubtask") == 1)
    }

    @Test func lateSavedAndPendingFactsCannotEnterRetryGapOrReplaceOutput() throws {
        let fixture = try MultiPlanOutputFixture()
        let items = try fixture.chain()
        fixture.subtaskBefore = { throw TaskCreateCommandIO.Failure.injected }
        try fixture.start()
        try fixture.confirm()
        var run = try fixture.run
        let attempt = try #require(run.attempt(items[1].id))
        var facts = try #require(run.units[1].subtask)
        try run.retry(attempt, assurance: .safeLocalReplay)
        #expect(throws: CommandExecutionError.stale) { try run.recordSubtask(facts, attempt: attempt) }
        facts.state = .saved
        facts.save = .returned
        #expect(throws: CommandExecutionError.stale) { try run.recordSubtask(facts, attempt: attempt) }
        _ = try run.beginNext(expecting: run.stamp)
        #expect(throws: CommandExecutionError.stale) { try run.recordSubtask(facts, attempt: attempt) }
        #expect(throws: (any Error).self) {
            _ = try fixture.handoff.coordinator.multiPlanOutput(.init(producer: items[0].stamp, outputType: .todo), in: run)
        }
        #expect(try fixture.run.outputs.count == 1 && fixture.children().isEmpty)
    }

    @Test(arguments: [0, 1, 2]) func routineFailureRecoveryAndExternalBoundary(kind: Int) throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue()
        let producer = try #require(fixture.handoff.state().plan.items.first)
        _ = try MultiPlanRoutineOutputSupport.queue(fixture, command: "routine.weekdays",
            argument: .init(parameter: .weekdays, operation: .assign, value: .weekdays(WeekdayMask.all)), producer: producer)
        let adapter = MultiPlanRoutineOutputSupport.adapter(fixture)
        var failures = 0
        if kind == 0 {
            fixture.base.beforeTransaction = {
                failures += 1
                if failures == 1 { throw TaskCreateCommandIO.Failure.injected }
            }
        } else if kind == 1 { fixture.base.saveMode = .throwAfter }
        else { fixture.base.notificationResult = .failed }
        let preview = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        try? adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let run = try #require(fixture.handoff.state().execution)
        let reserved = try #require(fixture.handoff.coordinator.taskCreations.routinePreparations[producer.draft.id]?.creationID)
        #expect(run.units[1].attempt == 0 && run.units[1].state == .blocked)
        if kind == 0 {
            try adapter.retryLocal(#require(run.attempt(producer.id)), expecting: fixture.handoff.owned().lease)
            try adapter.confirmPending(expecting: fixture.handoff.owned().lease)
            #expect(try fixture.handoff.state().execution?.outputs[producer.id]?.id == reserved)
            #expect(fixture.base.count("save") == 2 && fixture.base.count("ui") == 2)
        } else {
            #expect(run.units[0].local == (kind == 1 ? .unknown : .committed))
            #expect(throws: (any Error).self) {
                try adapter.retryLocal(#require(run.attempt(producer.id)), expecting: fixture.handoff.owned().lease)
            }
            #expect(fixture.base.count("save") == 1)
        }
    }
}
