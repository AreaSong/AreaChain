import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct BatchStateLimitTests {
    @Test(arguments: [3999, 4000, 4001]) func totalEntitiesIncludeDefinitionEvenForOneTarget(total: Int) throws {
        let f = try BatchStateFixture(enabled: false)
        let start = DayKey.shifted(f.base.today, by: -(total - 1), calendar: RoutineQueryFixture.dates.calendar)
        f.base.routine.createdDayKey = start; f.base.routine.pausedOnDayKey = start
        try f.context.save()
        try f.queue("batch.enabled", targets: [f.definitionTargets[0]])
        let preview = try f.base.preview()
        let counts = try #require(preview.writeSet?.counts)
        #expect(counts.total == total && counts.selected == 1 && counts.changed == 1)
        #expect(counts.modified[.routine] == 1 && counts.inserted[.check] == total - 1)
        #expect(preview.impacts[0].state?.span == total - 1)
        if total > 4000 {
            #expect(throws: CommandBatchIssue.writeLimit(counts)) {
                try f.base.adapter.accept(preview, expecting: f.base.handoff.owned().lease)
            }
            #expect(!f.base.routine.isEnabled && f.base.routine.checks.isEmpty && f.base.count("save") == 0)
        } else {
            let accepted = try f.base.accept()
            #expect(try f.base.submit(accepted).state == .saved)
            #expect(f.base.routine.checks.count == total - 1 && f.base.count("save") == 1 && f.base.count("ui") == 1)
            try f.assertCreated(accepted)
        }
    }

    @Test func spanLimitAndWholeBatchTotalAreIndependent() throws {
        let f = try BatchStateFixture(enabled: false)
        let start = DayKey.shifted(f.base.today, by: -4001, calendar: RoutineQueryFixture.dates.calendar)
        f.base.routine.createdDayKey = start; f.base.routine.pausedOnDayKey = start
        f.base.routine.weekdayMask = WeekdayMask.workdays
        try f.context.save()
        try f.queue("batch.enabled")
        #expect(throws: CommandBatchIssue.invalidTargets([.init(target: f.definitionTargets[0], reason: .state(.intervalLimit))])) {
            try f.base.preview()
        }
        #expect(f.base.count("save") == 0 && !f.second.isEnabled)
    }

    @Test func duplicateEffectsCountOnceAndConflictsReject() throws {
        let f = try BatchStateFixture()
        let entry = CommandBatchWriteSet.Entry(identity: .stored(.todo, f.base.todos[0].persistentModelID),
                                               value: .completion(f.base.todos[0].id, true))
        let set = try CommandBatchWriteSet(entries: [entry, entry], selected: 2, changed: 2)
        #expect(set.counts.total == 1 && set.counts.modified[.todo] == 1)
        let conflict = CommandBatchWriteSet.Entry(identity: entry.identity, value: .completion(f.base.todos[0].id, false))
        #expect(throws: CommandBatchIssue.writeConflict) {
            try CommandBatchWriteSet(entries: [entry, conflict], selected: 2, changed: 2)
        }
    }

    @Test func nearLimitMixedCascadeCostHasExplicitComposition() throws {
        let f = try BatchStateFixture()
        for index in 0..<3996 { f.context.insert(SubtaskItem(title: "Synthetic child \(index)", todo: f.base.todos[0])) }
        try f.context.save()
        let existingRecords = try f.checks().count
        try f.queue(targets: Array(f.mixed.prefix(3)))
        let start = ContinuousClock.now
        let preview = try f.base.preview()
        let prepared = ContinuousClock.now
        #expect(preview.writeSet?.counts.total == 4000)
        #expect(preview.writeSet?.counts.modified[.subtask] == 3997 && preview.writeSet?.counts.inserted[.check] == 2)
        let accepted = try f.base.adapter.accept(preview, expecting: f.base.handoff.owned().lease)
        let submitting = ContinuousClock.now
        let facts = try f.base.submit(accepted)
        let end = ContinuousClock.now
        #expect(facts.state == .saved && f.base.count("save") == 1 && f.base.count("ui") == 1)
        #expect(f.base.todos[0].subtasks.filter { $0.deletedAt == nil }.allSatisfy { $0.isDone })
        try f.assertCreated(accepted)
        print("BM2 COST warm-process new-memory-store Debug targets=3 task=1 subtask=3997 newChecks=2 existingChecks=\(existingRecords) prepare=\(start.duration(to: prepared)) submit=\(submitting.duration(to: end)); fixture/acceptance excluded; single sample")
    }
}
