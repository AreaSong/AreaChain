import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreateCommandFailureTests {
    @Test func repositoryMutationBeforeFailureActuallyRollsBackWithoutSave() throws {
        let fixture = try TaskCreateCommandFixture()
        let failing = TaskCreateFailureRepository(fixture.io.capture.context)
        fixture.io.repositoryFactory = { _ in failing }
        try fixture.queue()
        let prepared = try fixture.prepare()
        let request = try fixture.request()
        let facts = try fixture.adapter.execute(request)
        #expect(failing.calls == 1 && failing.insertedCount == 1)
        #expect(facts.creationID == prepared.creationID && facts.state == .notSubmitted)
        #expect(facts.save == .notCalled && facts.rollback == .returned)
        #expect(try fixture.io.capture.readTodos().isEmpty)
        #expect(!fixture.io.capture.context.hasChanges && fixture.count("save") == 0 && fixture.count("ui") == 0)
        // 协议的 replay 确认不授予业务权限：适配仍拒绝已经调用过的同一准备。
        try fixture.handoff.send(.retry(request.attempt, .safeLocalReplay))
        let retry = try fixture.handoff.begin()
        let next = TaskCreateCommandRequest(lease: try fixture.handoff.owned().lease, operation: request.operation, attempt: retry)
        #expect(throws: (any Error).self) { try fixture.adapter.execute(next) }
        #expect(failing.calls == 1 && fixture.count("save") == 0)
    }

    @Test(arguments: [false, true])
    func saveThrowIsUnknownEvenAfterActualCommit(commitsFirst: Bool) throws {
        let fixture = try TaskCreateCommandFixture()
        fixture.io.saveMode = commitsFirst ? .throwAfter : .throwBefore
        try fixture.queue()
        let prepared = try fixture.prepare()
        let request = try fixture.request()
        let facts = try fixture.adapter.execute(request)
        #expect(facts.state == .unknown && facts.savedID == nil && facts.candidateID == prepared.creationID)
        #expect(facts.save == .called && facts.rollback == .returned)
        #expect(try fixture.unit().local == .unknown && fixture.unit().state == .verificationRequired)
        #expect(try fixture.io.capture.readTodos().count == (commitsFirst ? 1 : 0))
        let verified = try fixture.adapter.verifyUnknown(request.operation, expecting: fixture.handoff.owned().lease)
        #expect(verified == (commitsFirst ? .singleLive : .absent))
        #expect(try fixture.unit().taskCreation == facts && fixture.unit().local == .unknown)
        #expect(throws: CommandExecutionError.requiresVerification) {
            try fixture.handoff.send(.retry(request.attempt, .safeLocalReplay))
        }
        #expect(throws: (any Error).self) { try fixture.adapter.execute(request) }
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 0 && fixture.count("calendarRefresh") == 0)
        #expect(fixture.io.capture.registered.isEmpty)
    }

    @Test func sameTitleDoesNotVerifyUnknownAndDuplicateIDIsAmbiguous() throws {
        let fixture = try TaskCreateCommandFixture()
        fixture.io.saveMode = .throwBefore
        try fixture.queue()
        _ = try fixture.prepare()
        let request = try fixture.request()
        let facts = try fixture.adapter.execute(request)
        let context = fixture.io.capture.context
        context.insert(TodoItem(title: "合成普通任务", dayKey: "2026-10-05"))
        try context.save()
        #expect(try fixture.adapter.verifyUnknown(request.operation, expecting: fixture.handoff.owned().lease) == .absent)
        context.insert(TodoItem(id: facts.creationID, title: "unrelated", dayKey: "2026-10-03", deletedAt: .now))
        try context.save()
        #expect(try fixture.adapter.verifyUnknown(request.operation, expecting: fixture.handoff.owned().lease) == .tombstone)
        context.insert(TodoItem(id: facts.creationID, title: "ambiguous", dayKey: "2026-10-03"))
        try context.save()
        #expect(try fixture.adapter.verifyUnknown(request.operation, expecting: fixture.handoff.owned().lease) == .ambiguous)
        #expect(try fixture.unit().local == .unknown && fixture.unit().taskCreation == facts)
        #expect(fixture.count("save") == 1)
    }

    @Test(arguments: [0, 1, 2, 3])
    func publicationAndExternalFailuresNeverRecreate(kind: Int) throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue()
        _ = try fixture.prepare()
        let request = try fixture.request()
        fixture.io.notificationResult = kind == 2 ? .failed : .succeeded
        fixture.io.calendarResult = kind == 3 ? .failed : .succeeded
        if kind == 0 { fixture.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 1 { fixture.environment.afterPublication = { throw TaskCreateCommandIO.Failure.injected } }
        let facts = try fixture.adapter.execute(request)
        #expect(facts.state == .saved && facts.savedID != nil)
        #expect(facts.publicationFailed == (kind < 2))
        #expect(facts.refreshRequested == (kind != 0))
        #expect(facts.calendarRequested == (kind == 0 ? nil : true))
        #expect(try fixture.unit().local == .committed)
        #expect(try fixture.unit().effects[kind == 2 ? .notification : .calendar] == (kind >= 2 ? .failed : kind == 0 ? .unknown : .succeeded))
        #expect(throws: (any Error).self) { try fixture.adapter.execute(request) }
        #expect(try fixture.io.capture.readTodos().count == 1)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == (kind == 0 ? 0 : 1))
        #expect(fixture.count("calendarRefresh") == (kind == 0 ? 0 : 1))
    }

    @Test func registrationFailureAfterSavedIDCannotRevertLocalSuccess() throws {
        let fixture = try TaskCreateCommandFixture()
        fixture.io.afterRegistration = { throw TaskCreateCommandIO.Failure.injected }
        try fixture.queue()
        let facts = try fixture.submit()
        #expect(facts.state == .saved && facts.registrationFailed)
        #expect(try fixture.unit().taskCreation == facts && fixture.unit().local == .committed)
        #expect(try fixture.io.capture.readTodos().count == 1)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }
}
