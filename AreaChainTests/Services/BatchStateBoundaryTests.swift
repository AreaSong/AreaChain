import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct BatchStateBoundaryTests {
    @Test(arguments: Array(0..<14)) func acceptedMemberChildRecordDateAndSourceChangesReject(kind: Int) throws {
        let f = try BatchStateFixture()
        let row = f.row(f.second, "2026-10-07")
        try f.context.save()
        try f.queue()
        let accepted = try f.base.accept()
        switch kind {
        case 0: f.base.todos[0].isDone = true
        case 1: f.child.isDone = true
        case 2: f.context.insert(SubtaskItem(title: "Added child", todo: f.base.todos[0]))
        case 3: f.child.todo = f.base.other
        case 4: row.isSkipped = true
        case 5: f.row(f.second, "2026-10-08")
        case 6: f.context.delete(row)
        case 7: f.base.today = "2026-10-09"
        case 8: f.base.sourceRevision = UUID()
        case 9: f.base.history[f.base.routine.id] = []
        case 10: f.base.routine.weekdayMask = WeekdayMask.workdays
        case 11: row.routine = f.base.routine
        case 12: f.base.todos[0].dayKey = "2026-10-10"
        default: f.base.todos[0].title = "Changed title"
        }
        try f.context.save()
        #expect(throws: (any Error).self) { try f.base.submit(accepted) }
        #expect(f.base.count("save") == 0 && f.base.count("ui") == 0)
        #expect(try f.base.handoff.state().execution == nil)
    }

    @Test(arguments: Array(0..<6)) func ineligibleOccurrenceRejectsWholeBatchWithTargetAndDay(kind: Int) throws {
        let f = try BatchStateFixture()
        let target = f.mixed[1]
        switch kind {
        case 0: f.row(f.base.routine, "2026-10-06"); f.row(f.base.routine, "2026-10-06")
        case 1: f.base.history[f.base.routine.id] = []
        case 2:
            f.base.history[f.base.routine.id] = [.init(routineID: f.base.routine.id,
                interval: .init(lowerBound: "2026-10-06", upperBound: "2026-10-06"),
                rule: .weekdays((WeekdayMask.all & ~WeekdayMask.workdays)), source: .synthetic(reference: "not-scheduled"))]
        case 3: f.row(f.base.routine, "invalid-date")
        case 4:
            f.context.insert(DailyRoutine(id: f.base.routine.id, title: "Duplicate", sortOrder: 1))
        default:
            let row = f.row(f.base.routine, "2026-10-06")
            f.context.insert(RoutineCheck(id: row.id, dayKey: "2026-10-07", routine: f.second))
        }
        try f.context.save()
        try f.queue(targets: [f.base.taskTargets[0], target])
        do { _ = try f.base.preview(); Issue.record("Expected target refusal") }
        catch let issue as CommandBatchIssue {
            guard case .invalidTargets(let problems) = issue else { throw issue }
            #expect(problems.contains { $0.target == target })
        }
        #expect(f.base.count("save") == 0 && !f.base.todos[0].isDone && !f.child.isDone)
    }

    @Test func lastCheckRejectsChangesBeforeAnyMemberIsApplied() throws {
        let f = try BatchStateFixture()
        try f.queue()
        let accepted = try f.base.accept()
        f.base.beforeTransaction = {
            f.row(f.base.routine, "2026-10-08")
            try f.context.save()
        }
        #expect(throws: (any Error).self) { try f.base.submit(accepted) }
        #expect(!f.base.todos[0].isDone && !f.child.isDone && f.base.count("save") == 0 && f.base.count("ui") == 0)
        #expect(try f.base.handoff.state().execution?.units.first?.batch?.state == .notSubmitted)
    }

    @Test func unchangedMembersRemainBoundAndPendingForeignEditsAreNotRolledBack() throws {
        let f = try BatchStateFixture()
        f.base.todos[0].isDone = true
        try f.context.save()
        try f.queue(targets: Array(f.base.taskTargets.prefix(2)))
        let accepted = try f.base.accept()
        #expect(accepted.preview.changedCount == 1)
        f.base.beforeTransaction = { f.base.other.title = "Unsaved unrelated draft" }
        #expect(throws: (any Error).self) { try f.base.submit(accepted) }
        #expect(f.base.other.title == "Unsaved unrelated draft" && f.context.hasChanges && !f.base.todos[1].isDone)
        #expect(f.base.count("save") == 0 && f.base.count("ui") == 0)
    }
}
