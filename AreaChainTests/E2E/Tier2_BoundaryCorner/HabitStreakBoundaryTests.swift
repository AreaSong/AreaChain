import Foundation
import Testing
@testable import AreaChain

@Suite("Tier 2 - Habit Streak Engine Boundary & Corner Cases")
struct HabitStreakBoundaryTests {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeRoutine(
        id: UUID = UUID(),
        title: String = "Boundary Routine",
        createdDayKey: String,
        weekdayMask: Int = WeekdayMask.all,
        isEnabled: Bool = true,
        deletedAt: Date? = nil
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            title: title,
            sortOrder: 0,
            isEnabled: isEnabled,
            createdDayKey: createdDayKey,
            weekdayMask: weekdayMask,
            deletedAt: deletedAt
        )
    }

    // T2.1: Leap year boundary (Feb 28 -> Feb 29 -> Mar 01, 2028) maintains streak
    @Test func leapYearBoundaryMaintainsStreak() {
        let routine = makeRoutine(createdDayKey: "2028-02-28")
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2028-02-28", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2028-02-29", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2028-03-01", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2028-03-01",
            calendar: utc
        )

        #expect(result.currentStreak == 3)
        #expect(result.bestStreak == 3)
    }

    // T2.2: Cross-year boundary (Dec 30, 2026 -> Dec 31, 2026 -> Jan 01, 2027) maintains streak
    @Test func crossYearBoundaryMaintainsStreak() {
        let routine = makeRoutine(createdDayKey: "2026-12-30")
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-12-30", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-12-31", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2027-01-01", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2027-01-01",
            calendar: utc
        )

        #expect(result.currentStreak == 3)
        #expect(result.bestStreak == 3)
    }

    // T2.3: Cross-month boundary across differing month lengths (Apr 30 -> May 01)
    @Test func crossMonthBoundary30To31Days() {
        let routine = makeRoutine(createdDayKey: "2026-04-29")
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-04-29", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-04-30", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-05-01", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-05-01",
            calendar: utc
        )

        #expect(result.currentStreak == 3)
        #expect(result.bestStreak == 3)
    }

    // T2.4: Multiple consecutive skipped days bridge streak across active days
    @Test func multipleConsecutiveSkipsBridgeStreak() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        // Mon done, Tue-Thu skipped, Fri done
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-02", isDone: true, isSkipped: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-03", isDone: true, isSkipped: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-04", isDone: true, isSkipped: true),
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
    }

    // T2.5: Custom weekday mask (e.g. MWF = Mon/Wed/Fri = 0b0101010) bridges off-days
    @Test func customWeekdayMaskMWF() {
        // Mon=2, Wed=4, Fri=6 -> binary bits 1, 3, 5 = (1<<1) | (1<<3) | (1<<5) = 2 | 8 | 32 = 42 (0b0101010)
        let mwfMask = (1 << 1) | (1 << 3) | (1 << 5)
        let routine = makeRoutine(createdDayKey: "2026-09-07", weekdayMask: mwfMask) // 2026-09-07 is Monday
        // Monday (07) checked, Wednesday (09) checked, Friday (11) checked
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-07", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-09", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-11", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-11",
            calendar: utc
        )

        #expect(result.currentStreak == 3)
        #expect(result.bestStreak == 3)
    }

    // T2.6: Custom weekend-only habit (Sat/Sun = 0b1000001 = 65) bridges 5 weekdays
    @Test func customWeekendOnlyHabit() {
        let weekendMask = (1 << 0) | (1 << 6) // Sunday=1, Saturday=64 -> 65
        // 2026-09-05 is Saturday, 09-06 is Sunday, 09-12 is next Saturday
        let routine = makeRoutine(createdDayKey: "2026-09-05", weekdayMask: weekendMask)
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-05", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-06", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-12", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-12",
            calendar: utc
        )

        #expect(result.currentStreak == 3)
        #expect(result.bestStreak == 3)
    }

    // T2.7: Duplicate check records on the same dayKey deduplicate safely
    @Test func duplicateChecksForSameDayDeduplicate() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-02", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-02", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-02",
            calendar: utc
        )

        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 2)
    }

    // T2.8: Conflicting checks on the same dayKey prioritize isDone: true
    @Test func conflictingChecksResolvesToDone() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: false),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-01",
            calendar: utc
        )

        #expect(result.currentStreak == 1)
        #expect(result.isCompletedToday == true)
    }

    // T2.9: Routine created in the future (> todayKey) returns 0 streak
    @Test func routineCreatedInFutureYieldsZeroStreak() {
        let routine = makeRoutine(createdDayKey: "2026-10-01")
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true)
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-01",
            calendar: utc
        )

        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.isDueToday == false)
    }

    // T2.10: Deleted routine returns 0 streak
    @Test func deletedRoutineYieldsZeroStreak() {
        let routine = makeRoutine(
            createdDayKey: "2026-09-01",
            deletedAt: Date()
        )
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-02", isDone: true),
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-02",
            calendar: utc
        )

        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
    }
}
