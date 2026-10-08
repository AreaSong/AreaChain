import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct BatchStateTransactionTests {
    @Test(arguments: [0, 1, 4]) func firstMiddleLastFailureRollsBackTasksChildrenAndChecks(position: Int) throws {
        let f = try BatchStateFixture()
        let tasks = f.base.todos.map(\.snapshot), definitions = f.routines.map(\.snapshot), checks = try f.checks()
        try f.queue()
        let accepted = try f.base.accept()
        var index = 0
        f.base.afterApply = { _ in
            defer { index += 1 }
            if index == position { throw TaskCreateCommandIO.Failure.injected }
        }
        let facts = try f.base.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.rollback == .returned)
        #expect(f.base.todos.map(\.snapshot) == tasks && f.routines.map(\.snapshot) == definitions && !f.child.isDone)
        #expect(try f.checks() == checks && f.base.count("save") == 0 && f.base.count("ui") == 0)
    }

    @Test(arguments: [0, 1, 2]) func enableFailureRollsBackAllDefinitionsAndRecords(position: Int) throws {
        let f = try BatchStateFixture(enabled: false)
        let third = DailyRoutine(title: "Third", sortOrder: 10, isEnabled: false, createdDayKey: "2026-10-05")
        f.context.insert(third); try f.context.save()
        let originals = (f.routines + [third]).map(\.snapshot)
        try f.queue("batch.enabled", targets: f.definitionTargets + [.init(type: .routine, id: third.id)])
        let accepted = try f.base.accept()
        var index = 0
        f.base.afterApply = { _ in
            defer { index += 1 }
            if index == position { throw TaskCreateCommandIO.Failure.injected }
        }
        let facts = try f.base.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.rollback == .returned)
        #expect((f.routines + [third]).map(\.snapshot) == originals)
        #expect(try f.checks().isEmpty)
        #expect(f.base.count("save") == 0 && f.base.count("ui") == 0)
    }

    @Test(arguments: [false, true], [false, true]) func unknownRetainsAllCreationKeysAndCannotReplay(after: Bool, enabling: Bool) throws {
        let f = try BatchStateFixture(enabled: !enabling)
        try f.queue(enabling ? "batch.enabled" : "batch.completion")
        let accepted = try f.base.accept()
        f.base.saveMode = after ? .throwAfter : .throwBefore
        let request = try f.base.request()
        let facts = try f.base.adapter.execute(request)
        #expect(facts.state == .unknown && facts.checkCreationIDs == accepted.checkCreationIDs && facts.writeSet == accepted.preview.writeSet)
        #expect(f.base.count("save") == 1 && f.base.count("ui") == 0)
        let another = BatchCommandAdapter(coordinator: f.base.handoff.coordinator, environment: f.base.environment)
        #expect(throws: (any Error).self) { try another.execute(request) }
        #expect(throws: (any Error).self) { try f.base.submit(accepted) }
        let fresh = try f.checks(in: ModelContext(f.base.io.container))
        #expect(fresh.count == (after ? (enabling ? 6 : 3) : 0))
        #expect(try f.base.handoff.state().execution?.units.first?.batch?.state == .unknown)
    }

    @Test(arguments: [0, 1, 2, 3]) func savedPublicationAndReentryDoNotReplay(kind: Int) throws {
        let f = try BatchStateFixture(enabled: false)
        try f.queue("batch.enabled")
        let accepted = try f.base.accept()
        if kind == 0 { f.base.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 1 { f.base.afterRegistration = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 2 { f.base.externalResult = .failed }
        if kind == 3 {
            f.base.afterApply = { _ in #expect(throws: (any Error).self) { try f.base.submit(accepted) } }
            f.base.onSave = { #expect(throws: (any Error).self) { try f.base.submit(accepted) } }
        }
        let facts = try f.base.submit(accepted)
        #expect(facts.state == .saved && f.base.count("save") == 1)
        #expect(facts.publicationFailed == (kind == 0) && facts.registrationFailed == (kind == 1))
        if kind == 2 { #expect(facts.external.allSatisfy { $0.notification == .failed && $0.calendar == .failed }) }
        #expect(throws: (any Error).self) { try f.base.submit(accepted) }
        try f.assertCreated(accepted)
    }
}
