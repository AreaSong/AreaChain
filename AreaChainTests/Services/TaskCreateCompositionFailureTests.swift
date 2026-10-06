import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreateCompositionFailureTests {
    typealias Fixture = TaskCreateCompositionFixture

    @Test func repositoryFailureRollsBackTaskCreationAndBothTagEffects() throws {
        let fixture = try Fixture()
        let deleted = try fixture.seed("恢复", deleted: true)
        let preview = try fixture.preview("任务 #恢复 #新建 @08:30")
        let accepted = try fixture.accept(preview)
        let failing = TaskCreateFailureRepository(fixture.context)
        fixture.base.io.repositoryFactory = { _ in failing }
        let facts = try fixture.submit(accepted)
        #expect(failing.calls == 1 && failing.insertedCount == 1)
        #expect(facts.state == .notSubmitted && facts.save == .notCalled && facts.rollback == .returned)
        #expect(try fixture.base.io.capture.readTodos().isEmpty && fixture.tags().count == 1)
        #expect(try fixture.tags().first?.id == deleted.id && fixture.tags().first?.deletedAt == Date(timeIntervalSince1970: 100))
        #expect(!fixture.context.hasChanges && fixture.base.count("save") == 0 && fixture.base.count("ui") == 0)
        #expect(fixture.base.io.capture.authorizations.isEmpty)
        #expect(fixture.handoff.coordinator.taskCreations.preparations[accepted.draft.draftID] == accepted)
    }

    @Test(arguments: [false, true])
    func saveThrowPreservesUnknownTaskAndTagIdentities(commitsFirst: Bool) throws {
        let fixture = try Fixture()
        let deleted = try fixture.seed("恢复", deleted: true)
        let preview = try fixture.preview("任务 #恢复 #新建 @08:30")
        let accepted = try fixture.accept(preview)
        fixture.base.io.saveMode = commitsFirst ? .throwAfter : .throwBefore
        let request = try fixture.base.request()
        let facts = try fixture.adapter.execute(request)
        #expect(facts.state == .unknown && facts.savedID == nil && facts.candidateID == accepted.creationID)
        #expect(facts.save == .called && facts.rollback == .returned)
        #expect(try fixture.base.io.capture.readTodos().count == (commitsFirst ? 1 : 0))
        let tags = try fixture.tags()
        #expect(tags.count == (commitsFirst ? 2 : 1))
        #expect(tags.first { $0.id == deleted.id }?.deletedAt == (commitsFirst ? nil : Date(timeIntervalSince1970: 100)))
        if commitsFirst { #expect(tags.last?.id == accepted.tagCreationIDs["新建"]) }
        #expect(try fixture.base.unit().local == .unknown && fixture.handoff.state().execution?.outputs.isEmpty == true)
        #expect(try fixture.adapter.verifyUnknown(request.operation, expecting: fixture.handoff.owned().lease)
                == (commitsFirst ? .singleLive : .absent))
        #expect(throws: (any Error).self) { try fixture.adapter.execute(request) }
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.handoff.coordinator.taskCreations.preparations[accepted.draft.draftID] == accepted)
        #expect(fixture.base.count("save") == 1 && fixture.base.count("ui") == 0)
        #expect(fixture.base.io.capture.authorizations.isEmpty && !fixture.context.hasChanges)
    }

    @Test func nestedSharedCreationStaysPendingUntilOutermostSave() throws {
        let fixture = try Fixture()
        let preview = try fixture.preview("任务 #新建")
        let accepted = try fixture.accept(preview)
        var creation: TaskMutationService.Creation?
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.capture.boundary) {
            creation = TaskMutationService.createComposed(.init(composition: preview.composition,
                creationID: accepted.creationID, tagCreationIDs: accepted.tagCreationIDs, source: accepted.source),
                in: fixture.context, dependencies: fixture.base.io.capture.dependencies)
            #expect(creation?.state == .pending && creation?.savedID == nil && creation?.candidateID == accepted.creationID)
            let savedTags = try fixture.tags()
            let savedTodos = try fixture.base.io.capture.readTodos()
            #expect(savedTags.isEmpty && savedTodos.isEmpty)
            #expect(fixture.base.io.capture.registered.isEmpty && fixture.base.count("save") == 0)
        }
        #expect(creation?.state == .saved && creation?.savedID == accepted.creationID)
        #expect(try fixture.tags().count == 1 && fixture.base.io.capture.readTodos().count == 1)
        #expect(fixture.base.count("save") == 1 && fixture.base.count("ui") == 1)
    }

    @Test func secondAdapterReentryAndDuplicatesCannotWriteTwice() throws {
        let fixture = try Fixture()
        let tombstone = try fixture.seed("恢复", deleted: true)
        let preview = try fixture.preview("任务 #恢复 #新建")
        let accepted = try fixture.accept(preview)
        let other = TaskCreateCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment,
                                             capability: .ordinaryComposition)
        #expect(try other.accept(preview, expecting: fixture.handoff.owned().lease) == accepted)
        let request = try fixture.base.request()
        fixture.base.io.beforeTransaction = {
            #expect(throws: TaskCreateCommandIssue.alreadyInvoked) { try other.execute(request) }
        }
        let facts = try fixture.adapter.execute(request)
        #expect(facts.savedID == accepted.creationID)
        #expect(throws: (any Error).self) { try other.execute(request) }
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(try fixture.base.io.capture.readTodos().count == 1 && fixture.tags().count == 2)
        #expect(try fixture.tags().first { $0.id == tombstone.id }?.deletedAt == nil)
        #expect(fixture.base.count("save") == 1 && fixture.base.count("ui") == 1)
    }

    @Test(arguments: [false, true])
    func reservedNewTagIDCollisionIncludesTombstones(deleted: Bool) throws {
        let fixture = try Fixture()
        let preview = try fixture.preview()
        let accepted = try fixture.accept(preview)
        let id = try #require(accepted.tagCreationIDs["新建"])
        try fixture.seed("无关名", deleted: deleted, id: id)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        // 执行器还独立检查预分配 ID；不能靠目录摘要间接掩盖漏掉墓碑碰撞。
        #expect(throws: TaskCreateCommandIssue.identityCollision) {
            try InputTagResolver.apply(preview.composition.tags, creationIDs: accepted.tagCreationIDs, in: fixture.context)
        }
        #expect(try fixture.tags().count == 1 && !fixture.context.hasChanges)
        try fixture.expectNoCommandWrites()
    }

    @Test func lateCatalogMutationIsRejectedBeforeTransactionAndNotAutomaticallyPrepared() throws {
        let fixture = try Fixture()
        let row = try fixture.seed("恢复", deleted: true)
        let preview = try fixture.preview("任务 #恢复 #新建")
        let accepted = try fixture.accept(preview)
        fixture.base.io.beforeTransaction = {
            row.deletedAt = nil
            try fixture.context.save()
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.save == .notCalled && facts.rollback == .notCalled)
        #expect(try fixture.tags().count == 1 && !fixture.context.hasChanges)
        #expect(fixture.handoff.coordinator.taskCreations.preparations[accepted.draft.draftID] == accepted)
        try fixture.expectNoCommandWrites()
    }

    @Test(arguments: [0, 1, 2, 3, 4, 5])
    func authorizationRefreshAndConsumerResultsRemainSeparate(kind: Int) throws {
        let fixture = try Fixture()
        let preview = try fixture.preview("任务", extra: [.init(parameter: .time, operation: .setReminder, value: .time(510))])
        let accepted = try fixture.accept(preview)
        let authorization: CommandTaskCreateFacts.Authorization = kind == 1 ? .denied : kind == 4 ? .granted : .unknown
        fixture.base.io.authorizationResult = authorization
        fixture.base.io.notificationResult = kind == 2 ? .failed : .unknown
        fixture.base.io.calendarResult = kind == 3 ? .failed : .succeeded
        if kind == 3 { fixture.environment.afterPublication = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 5 { fixture.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        let request = try fixture.base.request()
        let facts = try fixture.adapter.execute(request)
        #expect(facts.state == .saved && facts.authorizationRequest == .returned && facts.savedID == accepted.creationID)
        #expect(facts.authorizationResult == authorization)
        #expect(facts.refreshRequested == (kind != 5))
        #expect(facts.notificationRequested == (kind == 5 ? nil : true) && facts.calendarRequested == (kind == 5 ? nil : true))
        #expect(fixture.base.io.capture.authorizations == [510])
        #expect(fixture.base.count("reminderRefresh") == (kind == 5 ? 0 : 1) && fixture.base.count("calendarRefresh") == (kind == 5 ? 0 : 1))
        #expect(try fixture.base.unit().effects[.notification] == (kind == 2 ? .failed : .unknown))
        #expect(try fixture.base.unit().effects[.calendar] == (kind == 5 ? .unknown : kind == 3 ? .failed : .succeeded))
        #expect(facts.publicationFailed == (kind == 3 || kind == 5))
        #expect(try fixture.base.unit().local == .committed && fixture.base.unit().taskCreation == facts)
        #expect(throws: (any Error).self) { try fixture.adapter.execute(request) }
        #expect(try fixture.base.io.capture.readTodos().count == 1 && fixture.base.count("save") == 1)
    }
}
