import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct BatchStateCompatibilityTests {
    @Test func oldBatchStillRepairsAlreadyDoneParentWhileNewCommandDoesNot() throws {
        let f = try BatchStateFixture()
        f.base.todos[0].isDone = true
        try f.context.save()
        try ModelChanges.transaction(in: f.context, boundary: f.base.io.boundary) {
            #expect(DayBoardMutations.batchToggleDone([f.base.todos[0].id], markDone: true, todos: f.base.todos))
        }
        #expect(f.child.isDone && !f.deletedChild.isDone)
        #expect(f.base.count("save") == 1 && f.base.count("ui") == 1)
    }

    @Test func originalBatchEnableKeepsItsOwnScopeAndOneTransaction() throws {
        let f = try BatchStateFixture(enabled: false)
        try ModelChanges.transaction(in: f.context, boundary: f.base.io.boundary) {
            #expect(DayBoardMutations.batchSetRoutineEnabled(Set(f.routines.map(\.id)), enabled: true,
                todayKey: f.base.today, routines: f.routines))
        }
        #expect(f.routines.allSatisfy { $0.isEnabled && $0.pausedOnDayKey == nil })
        let checks = try f.checks()
        #expect(checks.count == 6 && checks.allSatisfy { $0.done && $0.skipped })
        #expect(f.base.count("save") == 1 && f.base.count("ui") == 1)
    }

    @Test func reprepareKeepsCompositeCreationIdentitiesAndHistoryFailureNamesDates() throws {
        let f = try BatchStateFixture()
        try f.queue()
        let old = try f.base.accept()
        let refreshed = try f.base.accept()
        #expect(old.id != refreshed.id && old.checkCreationIDs == refreshed.checkCreationIDs)
        #expect(throws: (any Error).self) { try f.base.submit(old) }
        #expect(try f.base.submit(refreshed).state == .saved)
        try f.assertCreated(refreshed)

        let other = try BatchStateFixture()
        other.base.historyRead = { _ in throw TaskCreateCommandIO.Failure.injected }
        try other.queue(targets: Array(other.mixed.prefix(3)))
        #expect(throws: CommandBatchIssue.invalidTargets(Array(other.mixed[1...2]).map {
            .init(target: $0, reason: .state(.historyUnknown))
        })) { try other.base.preview() }
        #expect(other.base.count("save") == 0 && !other.child.isDone)
    }
}
