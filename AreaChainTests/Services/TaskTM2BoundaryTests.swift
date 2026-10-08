import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TaskTM2BoundaryTests {
    typealias Fixture = TaskTM2Fixture

    @Test(arguments: 0..<7) func childChangesInvalidateAcceptedCascade(kind: Int) throws {
        let fixture = try Fixture()
        fixture.base.todo.isDone = false
        let child = try fixture.child("child")
        let accepted = try fixture.accept("todo.completion", Fixture.completion(true))
        switch kind {
        case 0: _ = try fixture.child("new child")
        case 1: child.deletedAt = TaskTitleFixture.deletion
        case 2: child.isDone = true
        case 3:
            let other = TodoItem(title: "other", dayKey: "2026-10-05")
            fixture.context.insert(other); child.todo = other
        case 4: fixture.context.delete(child)
        case 5: fixture.context.insert(SubtaskItem(id: child.id, title: "duplicate"))
        default: fixture.base.todo.isDone = true
        }
        try fixture.context.save()
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
        #expect(try fixture.handoff.state().plan.items.first?.draft.arguments == [Fixture.completion(true)])
    }

    @Test func lastValidationRejectsChangedChildrenWithoutSavingUnrelatedEdits() throws {
        let fixture = try Fixture()
        fixture.base.todo.isDone = false
        _ = try fixture.child("child")
        let accepted = try fixture.accept("todo.completion", Fixture.completion(true))
        var calls = 0
        fixture.io.beforeTransaction = {
            calls += 1
            if calls == 2 { _ = try fixture.child("late child") }
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.conflict)
        #expect(try fixture.todo().subtasks.count == 2 && !fixture.todo().isDone)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test(arguments: [0, 1, 2, 3], [false, true])
    func saveFailurePreservesJointRollbackOrUnknown(kind: Int, commitsFirst: Bool) throws {
        let fixture = try Fixture()
        fixture.base.todo.isDone = false
        let child = try fixture.child("child")
        let commands = ["todo.completion", "todo.tags", "todo.createTag", "todo.due"]
        let arguments = [Fixture.completion(true), Fixture.tags(.add, [fixture.base.deleted.id]),
                         Fixture.name("New"), Fixture.due(800)]
        let accepted = try fixture.accept(commands[kind], arguments[kind])
        fixture.io.saveMode = commitsFirst ? .throwAfter : .throwBefore
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .unknown && facts.save == .called && facts.rollback == .returned)
        #expect(facts.savedTagIDs == nil && facts.completedSubtaskIDs == nil)
        let todo = try fixture.todo()
        if kind == 0 {
            #expect(todo.isDone == commitsFirst && todo.subtasks.first { $0.id == child.id }?.isDone == commitsFirst)
        }
        if kind == 1 {
            #expect(TagIDList.contains(todo.tagIDs, fixture.base.deleted.id) == commitsFirst)
            #expect(try fixture.tags().first { $0.id == fixture.base.deleted.id }?.deletedAt == (commitsFirst ? nil : TaskTitleFixture.deletion))
        }
        if kind == 2 {
            #expect(try fixture.tags().count == (commitsFirst ? 3 : 2))
            let reserved = try #require(accepted.tagCreationIDs["new"])
            #expect(TagIDList.contains(todo.tagIDs, reserved) == commitsFirst)
        }
        if kind == 3 { #expect(todo.dueMinutes == (commitsFirst ? 800 : 600)) }
        let run = try #require(fixture.handoff.state().execution)
        let operation = try #require(run.operation(accepted.preview.item.id))
        _ = try fixture.adapter.verifyUnknown(operation, expecting: fixture.handoff.owned().lease)
        #expect(try fixture.handoff.state().execution?.units.first?.local == .unknown)
        #expect(fixture.handoff.coordinator.taskFields.acceptances[accepted.preview.draft.draftID] == accepted)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 0 && !fixture.context.hasChanges)
    }

    @Test(arguments: [false, true]) func committedFailuresNeverEraseLocalFacts(registration: Bool) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("todo.createTag", Fixture.name("New"))
        if registration { fixture.io.afterRegistration = { throw CocoaError(.fileWriteUnknown) } }
        else { fixture.environment.beforePublication = { throw CocoaError(.fileWriteUnknown) } }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .saved && facts.registrationFailed == registration && facts.publicationFailed == !registration)
        #expect(try fixture.tags().count == 3 && TagIDList.parse(fixture.todo().tagIDs).count == 2)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 1)
    }

    @Test(arguments: 0..<8) func staleOrProtectedCatalogNeverLosesOriginalAssociation(kind: Int) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("todo.tags", Fixture.tags(.clear))
        switch kind {
        case 0: fixture.base.live.name = "Renamed"
        case 1: fixture.base.live.isPrivateDiary = true
        case 2: fixture.base.live.name = "日记"
        case 3: fixture.context.insert(TagItem(id: fixture.base.live.id, name: "Duplicate", sortOrder: 2))
        case 4: fixture.context.insert(TagItem(name: "work", sortOrder: 2))
        case 5: fixture.context.delete(fixture.base.live)
        case 6: fixture.base.deleted.deletedAt = nil
        default: fixture.base.todo.tagIDs = "invalid-id"
        }
        try fixture.context.save()
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
        if kind != 0 && kind != 6 { #expect(throws: (any Error).self) { try fixture.preview() } }
        #expect(!fixture.base.todo.tagIDs.isEmpty)
    }

    @Test func newlyMatchingNameInvalidatesCreateAcceptance() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("todo.createTag", Fixture.name("New"))
        fixture.context.insert(TagItem(name: "NEW", sortOrder: 2)); try fixture.context.save()
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(try fixture.tags().count == 3 && fixture.todo().tagIDs == fixture.base.live.id.uuidString)
        #expect(fixture.count("save") == 0)
    }

    @Test func sourceAndTransactionReentryCannotCreateTwice() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("todo.createTag", Fixture.name("New"))
        let other = TaskFieldCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment, capability: .milestone2)
        fixture.io.sourceRead = {
            #expect(throws: (any Error).self) { try other.accept(accepted.preview, expecting: fixture.handoff.owned().lease) }
        }
        fixture.io.beforeTransaction = {
            #expect(throws: (any Error).self) { try other.submit(accepted: accepted, expecting: fixture.handoff.owned().lease) }
        }
        #expect(try fixture.submit(accepted).state == .saved)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(try fixture.tags().count == 3)
    }

    @Test(arguments: [0, 1, 2, 3]) func dirtyAndDefaultCapabilityRejectNewCommands(kind: Int) throws {
        let fixture = try Fixture()
        let commands = ["todo.completion", "todo.tags", "todo.createTag", "todo.due"]
        let arguments = [Fixture.completion(false), Fixture.tags(.clear), Fixture.name("New"), Fixture.due(800)]
        try fixture.queue(commands[kind], arguments[kind])
        let basic = TaskFieldCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        #expect(!basic.supports(.init(rawValue: commands[kind])))
        #expect(throws: TaskFieldCommandIssue.unassembled) {
            try basic.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        fixture.base.todo.title = "unsaved"
        #expect(throws: TaskTitleCommandIssue.dirtyContext) { try fixture.preview() }
        #expect(fixture.context.hasChanges && fixture.base.todo.title == "unsaved" && fixture.count("save") == 0)
    }

    @Test func invalidDueIsNeverTreatedAsClear() throws {
        for argument in [CommandArgument(parameter: .time, operation: .assign, value: .time(-1)),
                         .init(parameter: .time, operation: .assign, value: .time(1440)),
                         .init(parameter: .time, operation: .clear, value: .time(800)),
                         .init(parameter: .time, operation: .assign, value: nil)] {
            #expect(throws: TaskFieldCommandIssue.invalidArguments) { try TaskFieldEdit(command: .init(rawValue: "todo.due"), argument: argument) }
        }
    }
}
