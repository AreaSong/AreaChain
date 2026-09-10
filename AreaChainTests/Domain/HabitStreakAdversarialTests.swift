import Foundation
import Testing
@testable import AreaChain

struct HabitStreakAdversarialTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeRoutine(
        id: UUID = UUID(),
        title: String = "Adversarial Routine",
        createdDayKey: String = "2026-09-01",
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

    // MARK: - Category 1: Corrupt Dates & Format Variations

    @Test func corruptTodayKeyReturnsZeroSafe() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = [makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true)]

        let unparseableKeys = [
            "",
            "not-a-date",
            "2026/09/01",
            "20260901",
            "2026-09",
            "invalid-day-key-with-long-string-that-could-cause-buffer-overflow-or-crash-1234567890"
        ]

        for badKey in unparseableKeys {
            let result = HabitStreakLogic.calculate(
                routine: routine,
                checks: checks,
                todayKey: badKey,
                calendar: utcCalendar
            )
            #expect(result.currentStreak == 0)
            #expect(result.bestStreak == 0)
            #expect(result.isDueToday == false)
            #expect(result.isCompletedToday == false)
            #expect(result.isSkippedToday == false)
        }
    }

    @Test func numericOverflowDateComponentsHandledDeterministically() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = [makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true)]

        // DayKey.date(from:) parses 3 integers into DateComponents which Foundation Gregorian rolls over into year 2034
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-99-99",
            calendar: utcCalendar
        )
        // Current streak for far-future rolled-over date is 0 (broken since 2026)
        #expect(result.currentStreak == 0)
        // Historical best streak from 2026-09-01 is preserved
        #expect(result.bestStreak == 1)
        #expect(result.isCompletedToday == false)
    }

    @Test func corruptCreatedDayKeyHandlesSafelyWithoutHanging() {
        let corruptCreatedKeys = [
            "",
            "not-a-date",
            "2026-99-99",
            "0000-00-00",
            "123",
            "abc-def-ghi"
        ]

        for badKey in corruptCreatedKeys {
            let routine = makeRoutine(createdDayKey: badKey)
            let checks = [makeCheck(routineId: routine.id, dayKey: "2026-09-08", isDone: true)]
            let result = HabitStreakLogic.calculate(
                routine: routine,
                checks: checks,
                todayKey: "2026-09-08",
                calendar: utcCalendar
            )
            // Should complete quickly and produce a valid StreakResult (either 0 or 1 depending on whether it falls back to todayKey)
            #expect(result.currentStreak >= 0)
            #expect(result.bestStreak >= 0)
        }
    }

    @Test func futureCreatedDayKeyYieldsZeroStreak() {
        // Routine scheduled to begin in the future
        let routine = makeRoutine(createdDayKey: "2026-09-15")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-08", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-15", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-08",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.isDueToday == false)
    }

    @Test func createdDayKeyEqualToTodayKeyAllVariations() {
        let today = "2026-09-08" // Tuesday

        // Case A: Created today, scheduled today, uncompleted
        let routineA = makeRoutine(createdDayKey: today, weekdayMask: WeekdayMask.all)
        let resA = HabitStreakLogic.calculate(routine: routineA, checks: [], todayKey: today, calendar: utcCalendar)
        #expect(resA.currentStreak == 0)
        #expect(resA.bestStreak == 0)
        #expect(resA.isDueToday == true)
        #expect(resA.isCompletedToday == false)
        #expect(resA.isSkippedToday == false)

        // Case B: Created today, scheduled today, completed
        let checkB = [makeCheck(routineId: routineA.id, dayKey: today, isDone: true)]
        let resB = HabitStreakLogic.calculate(routine: routineA, checks: checkB, todayKey: today, calendar: utcCalendar)
        #expect(resB.currentStreak == 1)
        #expect(resB.bestStreak == 1)
        #expect(resB.isDueToday == true)
        #expect(resB.isCompletedToday == true)
        #expect(resB.isSkippedToday == false)

        // Case C: Created today, scheduled today, skipped
        let checkC = [makeCheck(routineId: routineA.id, dayKey: today, isDone: true, isSkipped: true)]
        let resC = HabitStreakLogic.calculate(routine: routineA, checks: checkC, todayKey: today, calendar: utcCalendar)
        #expect(resC.currentStreak == 0)
        #expect(resC.bestStreak == 0)
        #expect(resC.isDueToday == true)
        #expect(resC.isCompletedToday == false)
        #expect(resC.isSkippedToday == true)

        // Case D: Created today on an off-day (e.g. Wednesday mask, but today is Tuesday)
        let wednesdayMask = 1 << (4 - 1) // Wednesday only
        let routineD = makeRoutine(createdDayKey: today, weekdayMask: wednesdayMask)
        let resD = HabitStreakLogic.calculate(routine: routineD, checks: [], todayKey: today, calendar: utcCalendar)
        #expect(resD.currentStreak == 0)
        #expect(resD.bestStreak == 0)
        #expect(resD.isDueToday == false)
        #expect(resD.isCompletedToday == false)

        // Case E: Created today on an off-day, but completed anyway (off-day bonus)
        let checkE = [makeCheck(routineId: routineD.id, dayKey: today, isDone: true)]
        let resE = HabitStreakLogic.calculate(routine: routineD, checks: checkE, todayKey: today, calendar: utcCalendar)
        #expect(resE.currentStreak == 1)
        #expect(resE.bestStreak == 1)
        #expect(resE.isDueToday == false)
        #expect(resE.isCompletedToday == true)
    }

    // MARK: - Category 2: Leap Years & Calendar Boundary Transitions

    @Test func leapYear2024FullTransitionAndVariations() {
        let routine = makeRoutine(createdDayKey: "2024-02-27")

        // 1. All 4 days completed: Feb 27, Feb 28, Feb 29 (leap day), Mar 01
        let allDone = [
            makeCheck(routineId: routine.id, dayKey: "2024-02-27", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2024-02-28", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2024-02-29", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2024-03-01", isDone: true)
        ]
        let res1 = HabitStreakLogic.calculate(routine: routine, checks: allDone, todayKey: "2024-03-01", calendar: utcCalendar)
        #expect(res1.currentStreak == 4)
        #expect(res1.bestStreak == 4)

        // 2. Feb 29 skipped -> bridges streak
        let skippedLeap = [
            makeCheck(routineId: routine.id, dayKey: "2024-02-27", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2024-02-28", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2024-02-29", isDone: true, isSkipped: true),
            makeCheck(routineId: routine.id, dayKey: "2024-03-01", isDone: true)
        ]
        let res2 = HabitStreakLogic.calculate(routine: routine, checks: skippedLeap, todayKey: "2024-03-01", calendar: utcCalendar)
        #expect(res2.currentStreak == 3)
        #expect(res2.bestStreak == 3)

        // 3. Feb 29 missed -> breaks streak
        let missedLeap = [
            makeCheck(routineId: routine.id, dayKey: "2024-02-27", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2024-02-28", isDone: true),
            // Feb 29 missed
            makeCheck(routineId: routine.id, dayKey: "2024-03-01", isDone: true)
        ]
        let res3 = HabitStreakLogic.calculate(routine: routine, checks: missedLeap, todayKey: "2024-03-01", calendar: utcCalendar)
        #expect(res3.currentStreak == 1)
        #expect(res3.bestStreak == 2)
    }

    @Test func leapYear2028Transition() {
        let routine = makeRoutine(createdDayKey: "2028-02-28")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2028-02-28", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2028-02-29", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2028-03-01", isDone: true)
        ]
        let res = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2028-03-01", calendar: utcCalendar)
        #expect(res.currentStreak == 3)
        #expect(res.bestStreak == 3)
    }

    @Test func nonLeapYear2025DirectTransitionFeb28ToMar01() {
        let routine = makeRoutine(createdDayKey: "2025-02-27")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2025-02-27", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2025-02-28", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2025-03-01", isDone: true)
        ]
        let res = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2025-03-01", calendar: utcCalendar)
        #expect(res.currentStreak == 3)
        #expect(res.bestStreak == 3)
    }
}
