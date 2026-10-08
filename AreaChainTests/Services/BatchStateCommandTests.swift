import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct BatchStateCommandTests {
    @Test(arguments: [false, true]) func mixedDatesAndTypedIdentitiesShareOneCommit(done: Bool) throws {
        let f = try BatchStateFixture()
        if !done {
            f.base.todos[0].isDone = true; f.base.todos[1].isDone = true; f.child.isDone = true
            f.row(f.base.routine, "2026-10-06", done: true, skipped: true)
            f.row(f.second, "2026-10-07", done: true)
        }
        let untouched = f.row(f.second, "2026-10-08", done: true, skipped: true)
        try f.context.save()
        let definitions = f.routines.map(\.snapshot), other = f.base.other.snapshot
        let untouchedID = untouched.id
        try f.queue(value: done, targets: f.mixed + [f.mixed[1]])
        let accepted = try f.base.accept()
        #expect(accepted.preview.targets.objects == f.mixed)
        #expect(accepted.preview.impacts.map(\.target) == f.mixed)
        #expect(accepted.preview.writeSet?.counts.total == (done ? 6 : 4))
        #expect(accepted.checkCreationIDs.count == (done ? 3 : 0))
        #expect(Set(accepted.checkCreationIDs.values).count == accepted.checkCreationIDs.count)
        #expect(try f.base.adapter.accept(accepted.preview, expecting: f.base.handoff.owned().lease) == accepted)
        let facts = try f.base.submit(accepted)
        #expect(facts.state == .saved && f.base.count("save") == 1 && f.base.count("ui") == 1)
        #expect(facts.writeSet == accepted.preview.writeSet && facts.checkCreationIDs == accepted.checkCreationIDs)
        #expect(f.base.todos.prefix(2).allSatisfy { $0.isDone == done })
        #expect(f.child.isDone && !f.deletedChild.isDone)
        #expect(f.routines.map(\.snapshot) == definitions && f.base.other.snapshot == other)
        let checks = try f.checks()
        for target in f.mixed where target.type == .routineOccurrence {
            let rows = checks.filter { $0.parent == target.id && $0.day == target.dayKey }
            #expect(rows.count == (!done && target.dayKey == "2026-10-07" && target.id == f.base.routine.id ? 0 : 1))
            #expect(rows.allSatisfy { $0.done == done && !$0.skipped })
        }
        #expect(checks.first { $0.id == untouchedID }?.skipped == true)
        try f.assertCreated(accepted)
        #expect(facts.external.map(\.target) == accepted.preview.impacts.filter { !$0.noChange }.map(\.target))
        #expect(try f.checks(in: ModelContext(f.base.io.container)) == checks)
    }

    @Test func alreadyCompletedParentDoesNotRepairChildrenAndAllNoChangeDoesNotSave() throws {
        let f = try BatchStateFixture()
        f.base.todos[0].isDone = true
        try f.context.save()
        try f.queue(targets: [f.base.taskTargets[0]])
        let accepted = try f.base.accept()
        #expect(accepted.preview.impacts[0].completion?.affected.isEmpty == true)
        #expect(accepted.preview.writeSet?.counts.total == 0)
        #expect(try f.base.submit(accepted).state == .noChange)
        #expect(!f.child.isDone && f.base.count("save") == 0 && f.base.count("ui") == 0)
    }

    @Test(arguments: [false, true]) func multipleDefinitionsHaveExactPauseAndBridge(resume: Bool) throws {
        let f = try BatchStateFixture(enabled: !resume)
        let preserved = f.row(f.base.routine, "2026-10-05", done: true)
        let conflicting = f.row(f.base.routine, "2026-10-05", skipped: true)
        let openA = f.row(f.base.routine, "2026-10-06")
        let openB = f.row(f.base.routine, "2026-10-06")
        try f.context.save()
        let before = try f.checks()
        try f.queue("batch.enabled", value: resume)
        let accepted = try f.base.accept()
        #expect(accepted.preview.writeSet?.counts.total == (resume ? 8 : 2))
        #expect(accepted.checkCreationIDs.count == (resume ? 4 : 0))
        let facts = try f.base.submit(accepted)
        #expect(facts.state == .saved && f.base.count("save") == 1 && f.base.count("ui") == 1)
        #expect(f.routines.allSatisfy { $0.isEnabled == resume && $0.pausedOnDayKey == (resume ? nil : "2026-10-08") })
        #expect(preserved.isDone && !preserved.isSkipped && !conflicting.isDone && conflicting.isSkipped)
        if resume { #expect(openA.isDone && openA.isSkipped && openB.isDone && openB.isSkipped) }
        else { #expect(try f.checks() == before) }
        try f.assertCreated(accepted)
    }

    @Test func absenceReopenAndAlreadyEnabledRemainInQualificationSet() throws {
        for command in ["batch.completion", "batch.enabled"] {
            let f = try BatchStateFixture()
            try f.queue(command, value: command == "batch.enabled", targets: command == "batch.enabled" ? nil : Array(f.mixed.dropFirst().dropLast()))
            let accepted = try f.base.accept()
            #expect(accepted.preview.changedCount == 0 && accepted.checkCreationIDs.isEmpty)
            #expect(try f.base.submit(accepted).state == .noChange)
            #expect(f.base.count("save") == 0 && f.base.count("ui") == 0)
        }
    }

    @Test func basicAssemblyAndCommandSpecificDatesStayClosed() throws {
        let basic = try BatchCommandFixture()
        #expect(!basic.adapter.supports(.init(rawValue: "batch.completion")))
        try basic.queue("batch.completion", argument: .init(parameter: .enabled, operation: .assign, value: .boolean(true)))
        #expect(throws: CommandBatchIssue.unassembled) { try basic.preview() }
        let todo = CommandObjectReference(type: .todo, id: UUID(), dayKey: "2026-10-08")
        #expect(!CommandBatchEdit.move("2026-10-08").allows(todo))
        #expect(!CommandBatchEdit.completion(true).allows(todo))
        #expect(!CommandBatchEdit.enabled(true).allows(.init(type: .routine, id: UUID(), dayKey: "2026-10-08")))
        #expect(!CommandBatchEdit.completion(true).allows(.init(type: .routineOccurrence, id: UUID())))
    }
}
