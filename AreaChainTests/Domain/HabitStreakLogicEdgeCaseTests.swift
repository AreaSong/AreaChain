import Foundation
import Testing
@testable import AreaChain

struct HabitStreakLogicEdgeCaseTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeRoutine(
        id: UUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: String = "晨间冥想",
        createdDayKey: String = "2026-09-01",
        weekdayMask: Int = WeekdayMask.all
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            title: title,
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: createdDayKey,
            weekdayMask: weekdayMask
        )
    }

    private func makeCheck(
        routineId: UUID,
        dayKey: String,
        isDone: Bool = true,
        isSkipped: Bool = false
    ) -> CheckSnapshot {
        CheckSnapshot(
            routineId: routineId,
            dayKey: dayKey,
            isDone: isDone,
            isSkipped: isSkipped
        )
    }

    // MARK: - 9. Best Streak Tracking

    @Test func bestStreakTracksHistoricalMaximumEvenAfterBreak() {
        let routine = makeRoutine(createdDayKey: "2026-08-01")
        var checks: [CheckSnapshot] = []

        // Period 1: 10 consecutive days (2026-08-01...2026-08-10)
        for day in 1...10 {
            checks.append(makeCheck(routineId: routine.id, dayKey: String(format: "2026-08-%02d", day), isDone: true))
        }
        // 2026-08-11 missed
        // Period 2: 3 consecutive days (2026-08-12...2026-08-14)
        for day in 12...14 {
            checks.append(makeCheck(routineId: routine.id, dayKey: String(format: "2026-08-%02d", day), isDone: true))
        }

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-08-14",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 3)
        #expect(result.bestStreak == 10)
    }

    @Test func bestStreakUpdatesWhenCurrentSurpassesHistoricalMaximum() {
        let routine = makeRoutine(createdDayKey: "2026-08-01")
        var checks: [CheckSnapshot] = []

        // Initial run of 2 days
        checks.append(makeCheck(routineId: routine.id, dayKey: "2026-08-01", isDone: true))
        checks.append(makeCheck(routineId: routine.id, dayKey: "2026-08-02", isDone: true))
        // 2026-08-03 missed
        // New run of 4 days
        for day in 4...7 {
            checks.append(makeCheck(routineId: routine.id, dayKey: String(format: "2026-08-%02d", day), isDone: true))
        }

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-08-07",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 4)
        #expect(result.bestStreak == 4)
    }

    // MARK: - 10. Created Today Edge Cases

    @Test func createdTodayUncheckedYieldsZeroStreak() {
        let routine = makeRoutine(createdDayKey: "2026-09-08")
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: [],
            todayKey: "2026-09-08",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.isDueToday == true)
        #expect(result.isCompletedToday == false)
        #expect(result.isSkippedToday == false)
    }

    @Test func createdTodayCheckedYieldsStreakOne() {
        let routine = makeRoutine(createdDayKey: "2026-09-08")
        let checks = [makeCheck(routineId: routine.id, dayKey: "2026-09-08", isDone: true)]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-08",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 1)
        #expect(result.bestStreak == 1)
        #expect(result.isDueToday == true)
        #expect(result.isCompletedToday == true)
    }

    @Test func createdTodaySkippedYieldsZeroStreak() {
        let routine = makeRoutine(createdDayKey: "2026-09-08")
        let checks = [makeCheck(routineId: routine.id, dayKey: "2026-09-08", isDone: true, isSkipped: true)]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-08",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.isDueToday == true)
        #expect(result.isSkippedToday == true)
        #expect(result.isCompletedToday == false)
    }

    @Test func createdTodayOnOffDayYieldsNotDueAndZeroStreak() {
        // Saturday 2026-09-05 on Workdays mask
        let routine = makeRoutine(
            createdDayKey: "2026-09-05",
            weekdayMask: WeekdayMask.workdays
        )
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: [],
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.isDueToday == false)
    }

    // MARK: - 11. Cross-Month & Cross-Year Boundaries

    @Test func crossMonthBoundaryMaintainsStreak() {
        let routine = makeRoutine(createdDayKey: "2026-08-30")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-08-30", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-08-31", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-02",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 4)
        #expect(result.bestStreak == 4)
    }

    @Test func crossYearBoundaryMaintainsStreak() {
        let routine = makeRoutine(createdDayKey: "2025-12-30")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2025-12-30", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2025-12-31", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-01-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-01-02", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-01-02",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 4)
        #expect(result.bestStreak == 4)
    }

    @Test func leapYearBoundaryMaintainsStreak() {
        let routine = makeRoutine(createdDayKey: "2024-02-28")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2024-02-28", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2024-02-29", isDone: true), // leap day
            makeCheck(routineId: routine.id, dayKey: "2024-03-01", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2024-03-01",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 3)
        #expect(result.bestStreak == 3)
    }

    // MARK: - 12. Duplicate and Scrambled Checks

    @Test func duplicateChecksForSameDayDoNotDoubleCount() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true), // duplicate
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-02",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 2)
    }

    @Test func unsortedChecksArrayProducesCorrectResult() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-05", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-04", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 5)
        #expect(result.bestStreak == 5)
    }

    @Test func conflictingChecksResolvesDoneStatus() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: false),
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-01",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 1)
        #expect(result.isCompletedToday == true)
    }

    // MARK: - 13. Isolation and Edge Boundary Filtering

    @Test func checksForOtherRoutinesAreFilteredOut() {
        let routineA = makeRoutine(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
        let routineB = makeRoutine(id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!)
        let checks = [
            makeCheck(routineId: routineB.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routineB.id, dayKey: "2026-09-02", isDone: true),
            makeCheck(routineId: routineA.id, dayKey: "2026-09-02", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routineA,
            checks: checks,
            todayKey: "2026-09-02",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 1)
        #expect(result.bestStreak == 1)
    }

    @Test func futureChecksDoNotAffectStreak() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-04", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-05", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-06", isDone: true) // future check
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 2)
    }

    @Test func emptyChecksArrayWithOldRoutineYieldsZeroStreak() {
        let routine = makeRoutine(createdDayKey: "2026-01-01")
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: [],
            todayKey: "2026-09-08",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.isDueToday == true)
        #expect(result.isCompletedToday == false)
    }

    // MARK: - 14. DayBoardLogic Legacy Forwarding

    @Test func legacyDayBoardLogicHabitStreakForwardsCorrectly() {
        let id = UUID()
        let checks = (1...3).map { day in
            makeCheck(routineId: id, dayKey: String(format: "2026-09-%02d", day), isDone: true)
        }
        let streak = DayBoardLogic.habitStreak(checks: checks, todayKey: "2026-09-03")
        #expect(streak == 3)
    }

    @Test func pausingBridgesMissedScheduledDays() {
        let id = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let routine = RoutineSnapshot(
            id: id,
            title: "晨间冥想",
            sortOrder: 0,
            isEnabled: false,
            createdDayKey: "2026-09-05",
            pausedOnDayKey: "2026-09-07"
        )
        let checks = [
            makeCheck(routineId: id, dayKey: "2026-09-05"),
            makeCheck(routineId: id, dayKey: "2026-09-06")
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-09",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 2)
        #expect(result.isDueToday == false)
    }

    @Test func skipFillStartPrefersPauseDayThenLastCheck() {
        #expect(
            HabitStreakLogic.skipFillStart(
                pausedOnDayKey: "2026-09-07",
                createdDayKey: "2026-09-01",
                checkDayKeys: ["2026-09-05"]
            ) == "2026-09-07"
        )
        #expect(
            HabitStreakLogic.skipFillStart(
                pausedOnDayKey: nil,
                createdDayKey: "2026-09-01",
                checkDayKeys: ["2026-09-03", "2026-09-05"]
            ) == "2026-09-05"
        )
        #expect(
            HabitStreakLogic.skipFillStart(
                pausedOnDayKey: nil,
                createdDayKey: "2026-09-01",
                checkDayKeys: []
            ) == "2026-09-01"
        )
    }
}
