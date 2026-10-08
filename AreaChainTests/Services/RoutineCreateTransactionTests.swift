import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineCreateTransactionTests {
    @Test(arguments: [false, true]) func tagSortOverflowRejectsOnlyNecessaryCreation(creates: Bool) throws {
        let fixture = try RoutineCreateFixture()
        fixture.base.base.live.sortOrder = Int.max
        try fixture.context.save()
        try fixture.queue(title: creates ? "散步 #New" : "散步 #Work")
        if creates {
            #expect(throws: TaskCreateCommandIssue.invalidInput) { try fixture.preview() }
            #expect(fixture.base.count("save") == 0)
        } else { #expect(try fixture.submit(fixture.accept()).state == .saved) }
        #expect(try InputTagResolver.creationOrder([Int.max - 1], count: 1) == Int.max)
        #expect(throws: TaskCreateCommandIssue.invalidInput) { try InputTagResolver.creationOrder([Int.max - 1], count: 2) }
    }

    @Test func unreadableSortDoesNotFallBackToZero() throws {
        let fixture = try RoutineCreateFixture()
        let repo = RecurringToggleRepository(fixture.context)
        repo.failRead = true
        fixture.base.repository = { _ in repo }
        try fixture.queue()
        #expect(throws: RoutineCreateIssue.unreliableSort) { try fixture.preview() }
        #expect(repo.creations == 0 && fixture.base.count("save") == 0)
    }

    @Test func workFailureRollsBackDefinitionAndBothTagEffects() throws {
        let fixture = try RoutineCreateFixture()
        let before = try fixture.snapshots()
        let checks = try fixture.base.checks()
        let repo = RecurringToggleRepository(fixture.context)
        fixture.base.repository = { _ in repo }
        try fixture.queue(title: "散步 #New #恢复")
        let accepted = try fixture.accept()
        repo.fail = true
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.save == .notCalled && facts.rollback == .returned)
        #expect(try fixture.snapshots() == before && fixture.base.tags().count == 2 && fixture.base.base.deleted.deletedAt != nil)
        #expect(try fixture.base.checks() == checks && repo.switches == 0)
        #expect(fixture.base.count("save") == 0 && fixture.base.count("ui") == 0)
    }

    @Test func sameTitleCanBeCreatedBySeparateInvocationAndOldDefaultIDsStayRandom() throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue()
        let first = try fixture.submit(fixture.accept())
        let run = try #require(fixture.handoff.state().execution)
        try fixture.handoff.coordinator.send(.releaseExecution(run.stamp), expecting: fixture.handoff.owned().lease)
        try fixture.queue()
        let preview = try fixture.preview()
        let accepted = try fixture.adapter.acceptCreation(preview, expecting: fixture.handoff.owned().lease)
        let second = try fixture.submit(accepted)
        #expect(first.savedID != second.savedID && first.savedRoutine?.title == second.savedRoutine?.title)
        #expect(second.savedRoutine?.sortOrder == 32)
        var ids: [UUID] = []
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.base.io.boundary) {
            let repo = SwiftDataRoutineRepository(context: fixture.context)
            ids = try [repo.addRoutine(.init(title: "旧入口")).id, repo.addRoutine(.init(title: "旧入口")).id]
        }
        #expect(ids.count == 2 && ids[0] != ids[1])
    }

    @Test func commandRejectsNestedContextAndForeignRepository() throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue()
        let accepted = try fixture.accept()
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.base.io.boundary) {
            #expect(throws: TaskTitleCommandIssue.nestedTransaction) { try fixture.submit(accepted) }
        }
        let foreign = ModelContext(fixture.context.container)
        foreign.autosaveEnabled = false
        fixture.base.repository = { _ in SwiftDataRoutineRepository(context: foreign) }
        #expect(throws: RoutineCommandIssue.invalidRepository) { try fixture.submit(accepted) }
    }
}
