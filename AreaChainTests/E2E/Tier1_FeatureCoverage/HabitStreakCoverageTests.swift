import Foundation
import Testing
@testable import AreaChain

@Suite("Tier 1 - Habit Streak Engine Feature Coverage")
struct HabitStreakCoverageTests {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeRoutine(
        id: UUID = UUID(),
        title: String = "Test Habit",
        createdDayKey: String,
        weekdayMask: Int = WeekdayMask.all,
        isEnabled: Bool = true
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            title: title,
            sortOrder: 0,
            isEnabled: isEnabled,
            createdDayKey: createdDayKey,
            weekdayMask: weekdayMask
        )
    }

    // T1.1: Primary consecutive daily check-ins increment currentStreak and bestStreak
    @Test func consecutiveDailyCheckInsIncrementStreak() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = (1...5).map { day in
            CheckSnapshot(routineId: routine.id, dayKey: String(format: "2026-09-%02d", day), isDone: true)
        }

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utc
        )

        #expect(result.currentStreak == 5)
        #expect(result.bestStreak == 5)
        #expect(result.isDueToday == true)
        #expect(result.isCompletedToday == true)
        #expect(result.isSkippedToday == false)
    }

    // T1.2: Missed scheduled day breaks current streak but preserves historical peak
    @Test func missedDayResetsCurrentStreakWhilePreservingHistoricalBest() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        // Completed Day 1, 2, 3; Missed Day 4; Completed Day 5
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-02", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-03", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-05", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utc
        )

        #expect(result.currentStreak == 1)
        #expect(result.bestStreak == 3)
        #expect(result.isCompletedToday == true)
    }

    // T1.3: Weekday mask routine (Mon-Fri) bridges weekend off-days without breaking
    @Test func workdayHabitBridgesWeekendWithoutBreakingStreak() {
        // 2026-09-04 is Friday, 09-05 Saturday, 09-06 Sunday, 09-07 Monday
        let routine = makeRoutine(createdDayKey: "2026-09-04", weekdayMask: WeekdayMask.workdays)
        let fridayCheck = [CheckSnapshot(routineId: routine.id, dayKey: "2026-09-04", isDone: true)]

        // Evaluation on Monday before Monday check-in
        let mondayMorning = HabitStreakLogic.calculate(
            routine: routine,
            checks: fridayCheck,
            todayKey: "2026-09-07",
            calendar: utc
        )
        #expect(mondayMorning.currentStreak == 1)
        #expect(mondayMorning.isDueToday == true)
        #expect(mondayMorning.isCompletedToday == false)

        // Evaluation on Monday after Monday check-in
        let mondayChecks = fridayCheck + [CheckSnapshot(routineId: routine.id, dayKey: "2026-09-07", isDone: true)]
        let mondayEvening = HabitStreakLogic.calculate(
            routine: routine,
            checks: mondayChecks,
            todayKey: "2026-09-07",
            calendar: utc
        )
        #expect(mondayEvening.currentStreak == 2)
        #expect(mondayEvening.bestStreak == 2)
        #expect(mondayEvening.isCompletedToday == true)
    }

    // T1.4: Single skipped day bridges streak transparently without counting as missed
    @Test func singleSkippedDayBridgesStreakTransparently() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-02", isDone: true, isSkipped: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-03", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-03",
            calendar: utc
        )

        // Streak bridges Day 2 skip: 2 actual completions
        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 2)
        #expect(result.isCompletedToday == true)
    }

    // T1.5: Today in-progress preserves streak through yesterday
    @Test func todayInProgressPreservesStreakThroughYesterday() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = (1...4).map { day in
            CheckSnapshot(routineId: routine.id, dayKey: String(format: "2026-09-%02d", day), isDone: true)
        }

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utc
        )

        #expect(result.currentStreak == 4)
        #expect(result.bestStreak == 4)
        #expect(result.isDueToday == true)
        #expect(result.isCompletedToday == false)
    }

    // T1.6: Days prior to routine creation date are ignored
    @Test func routineCreationDateBoundary() {
        let routine = makeRoutine(createdDayKey: "2026-09-03")
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-03", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-04", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-04",
            calendar: utc
        )

        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 2)
    }

    // T1.7: Unscheduled off-day check-in counts as bonus completion
    @Test func offDayCompletionGrantsBonusStreakIncrement() {
        // Weekday routine (Mon-Fri) checked on Saturday (2026-09-05)
        let routine = makeRoutine(createdDayKey: "2026-09-04", weekdayMask: WeekdayMask.workdays)
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-04", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-05", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utc
        )

        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 2)
        #expect(result.isDueToday == false) // Saturday is not due
        #expect(result.isCompletedToday == true)
    }
}
