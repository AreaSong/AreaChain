import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TaskTM2TransactionTests {
    typealias Fixture = TaskTM2Fixture

    @Test(arguments: [0, 1, 2]) func mutationFailureRollsBackParentsChildrenAndTagsTogether(kind: Int) throws {
        let fixture = try Fixture(failingRepository: true)
        fixture.base.todo.isDone = false
        let child = try fixture.child("child")
        let before = fixture.base.todo.snapshot
        let argument = kind == 0 ? Fixture.completion(true) : Fixture.name(kind == 1 ? "New" : "恢复")
        let accepted = try fixture.accept(kind == 0 ? "todo.completion" : "todo.createTag", argument)
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.save == .notCalled && facts.rollback == .returned)
        let todo = try fixture.todo()
        #expect(todo.snapshot == before && todo.subtasks.first { $0.id == child.id }?.isDone == false)
        #expect(try fixture.tags().count == 2 && fixture.tags().first { $0.id == fixture.base.deleted.id }?.deletedAt == TaskTitleFixture.deletion)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0 && !fixture.context.hasChanges)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
    }

    @Test func untouchedTombstoneAssociationIsNotRestoredAndOrderNormalizationIsExplicit() throws {
        let fixture = try Fixture()
        fixture.base.todo.tagIDs = [fixture.base.deleted.id.uuidString.lowercased(), fixture.base.live.id.uuidString,
                                   fixture.base.deleted.id.uuidString].joined(separator: ",")
        try fixture.context.save()
        let accepted = try fixture.accept("todo.tags", Fixture.tags(.add, [fixture.base.live.id]))
        #expect(!accepted.preview.noChange && accepted.preview.tags?.actions.final.isEmpty == true)
        #expect(try fixture.submit(accepted).state == .saved)
        #expect(try fixture.todo().tagIDs == TagIDList.encode([fixture.base.deleted.id, fixture.base.live.id]))
        #expect(try fixture.tags().first { $0.id == fixture.base.deleted.id }?.deletedAt == TaskTitleFixture.deletion)
    }

    @Test func alreadyLinkedTombstoneStillRequiresAcceptedRestoration() throws {
        let fixture = try Fixture()
        fixture.base.todo.tagIDs = TagIDList.encode([fixture.base.live.id, fixture.base.deleted.id])
        try fixture.context.save()
        let accepted = try fixture.accept("todo.createTag", Fixture.name("恢复"))
        #expect(!accepted.preview.noChange && accepted.preview.tags?.actions.final.map(\.effect) == [.restoreAndAssociate])
        #expect(try fixture.submit(accepted).savedTagEffects == [.restoreAndAssociate])
        #expect(try fixture.todo().tagIDs == TagIDList.encode([fixture.base.live.id, fixture.base.deleted.id]))
        #expect(try fixture.tags().first { $0.id == fixture.base.deleted.id }?.deletedAt == nil)
    }

    @Test(arguments: [0, 1, 2, 3]) func multipleTargetsAreNeverNarrowedOrExecuted(kind: Int) throws {
        let fixture = try Fixture()
        let commands = ["todo.completion", "todo.tags", "todo.createTag", "todo.due"]
        let arguments = [Fixture.completion(false), Fixture.tags(.clear), Fixture.name("New"), Fixture.due(800)]
        let targets = CommandDraftTargets(.selected, objects: [
            .init(type: .todo, id: fixture.base.todo.id), .init(type: .todo, id: UUID())])
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
            commandID: .init(rawValue: commands[kind]), targets: targets, arguments: [arguments[kind]]))
        #expect(throws: (any Error).self) { try fixture.preview() }
        #expect(try fixture.handoff.state().plan.items.first?.draft.targets == targets)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test(arguments: [0, 1, 2, 3]) func targetAndSourceQualificationCannotBeBypassed(kind: Int) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("todo.due", Fixture.due(800))
        switch kind {
        case 0: fixture.base.todo.deletedAt = TaskTitleFixture.deletion
        case 1:
            fixture.context.insert(TodoItem(id: fixture.base.todo.id, title: "Duplicate", dayKey: "2026-10-05"))
        case 2: fixture.base.protection = .unknown
        default: fixture.io.revision = UUID()
        }
        try fixture.context.save()
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test func dueSharedAssignmentPreservesLegacyClampingAndFields() throws {
        let fixture = try Fixture()
        let before = fixture.base.todo.snapshot
        for minutes in [0, 1439, -1, 1440] {
            TaskMutationService.assignDue(fixture.base.todo, minutes: minutes)
            #expect(fixture.base.todo.dueMinutes == ((0..<1440).contains(minutes) ? minutes : nil))
            var expected = before
            expected.dueMinutes = (0..<1440).contains(minutes) ? minutes : nil
            #expect(fixture.base.todo.snapshot == expected)
        }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }
}
