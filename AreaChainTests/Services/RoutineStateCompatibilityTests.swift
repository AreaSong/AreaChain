import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// R-M3兼容新读取，同时固定旧生产写入和页面差异。
@Suite(.serialized) @MainActor struct RoutineStateCompatibilityTests {
    @Test(arguments: [false, true], [false, true]) func fourStoredEncodings(done: Bool, skipped: Bool) {
        let day = QuerySessionFixture.today
        let check = CheckSnapshot(routineId: RoutineQueryFixture.id, dayKey: day, isDone: done, isSkipped: skipped)
        let read = RoutineQueryFixture.read([check])
        let expected: RoutineCheckReadState = skipped ? .skipped : (done ? .completed : .unprocessed)
        #expect(read.state == expected)
        let month = HabitMonth.mark(dayKey: day, routine: RoutineQueryFixture.routine(), checks: [check], todayKey: day,
                                   calendar: RoutineQueryFixture.dates.calendar)
        #expect(month == (done ? (skipped ? .skipped : .checked) : .open))
        #expect(DayBoardLogic.isRoutineDone(RoutineQueryFixture.routine(), checks: [check], on: day) == (done || skipped))
        let duplicate = RoutineQueryFixture.read([check, check])
        #expect(duplicate.diagnostics.contains(.identicalDuplicates) && duplicate.state == expected)
    }

    @Test func legacySkipRemainsLegalAndNewReaderPreservesEncodingDiagnostics() throws {
        let fixture = try RoutineCreateFixture()
        let routine = fixture.base.routine
        let repo = SwiftDataRoutineRepository(context: fixture.context)
        let day = QuerySessionFixture.today
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.base.io.boundary) {
            try repo.skipRoutine(id: routine.id, dayKey: day)
        }
        let check = try #require(repo.fetchChecks(for: routine.id).first { $0.dayKey == day })
        #expect(check.isDone && check.isSkipped)
        let raw = CheckSnapshot(routineId: RoutineQueryFixture.id, dayKey: day, isDone: check.isDone, isSkipped: check.isSkipped)
        #expect(RoutineQueryFixture.read([raw]).state == .skipped && RoutineQueryFixture.read([raw]).diagnostics.isEmpty)
        var alternate = raw
        alternate.isDone = false
        #expect(RoutineQueryFixture.read([raw, alternate]).diagnostics == [.equivalentEncodingDuplicates])
    }

    @Test func bridgeRangeAndDuplicateRowsRemainLegacy() throws {
        let fixture = try RoutineCreateFixture()
        let routine = fixture.base.routine
        routine.weekdayMask = WeekdayMask.all
        routine.pausedOnDayKey = "2026-10-05"
        let one = RoutineCheck(dayKey: "2026-10-05", isDone: false, routine: routine)
        let two = RoutineCheck(dayKey: "2026-10-05", isDone: false, routine: routine)
        let completed = RoutineCheck(dayKey: "2026-10-06", isDone: true, routine: routine)
        [one, two, completed].forEach { fixture.context.insert($0) }
        try fixture.context.save()
        let old = Set(routine.checks.map(\.id))
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.base.io.boundary) {
            try SwiftDataRoutineRepository(context: fixture.context).setRoutineEnabled(id: routine.id, enabled: true, todayKey: "2026-10-08")
        }
        #expect(one.isDone && one.isSkipped && two.isDone && two.isSkipped)
        #expect(completed.isDone && !completed.isSkipped)
        #expect(routine.isEnabled && routine.pausedOnDayKey == nil)
        let newRows = routine.checks.filter { !old.contains($0.id) }
        #expect(newRows.count == 1 && newRows.first?.dayKey == "2026-10-07")
        #expect(!routine.checks.contains { $0.dayKey == "2026-10-08" })
    }

    @Test func longPauseHasExistingFourThousandDayLimit() throws {
        let fixture = try RoutineCreateFixture()
        let routine = DailyRoutine(title: "长暂停", sortOrder: 0, isEnabled: false,
                                   createdDayKey: "2000-01-01", weekdayMask: WeekdayMask.all, pausedOnDayKey: "2000-01-01")
        fixture.context.insert(routine)
        try fixture.context.save()
        let end = DayKey.shifted("2000-01-01", by: 4001)
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.base.io.boundary) {
            try SwiftDataRoutineRepository(context: fixture.context).setRoutineEnabled(id: routine.id, enabled: true, todayKey: end)
        }
        #expect(routine.checks.count == 4000 && routine.isEnabled && routine.pausedOnDayKey == nil)
        #expect(!routine.checks.contains { $0.dayKey == DayKey.shifted(end, by: -1) })
    }
}
