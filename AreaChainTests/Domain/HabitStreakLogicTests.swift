import Foundation
import Testing
@testable import AreaChain

struct HabitStreakLogicTests {
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

    // MARK: - 1. Consecutive Daily Check-ins

    @Test func consecutiveDailyCheckInsIncrementStreak() {
        let routine = makeRoutine()
        let checks = (1...5).map { day in
            makeCheck(routineId: routine.id, dayKey: String(format: "2026-09-%02d", day), isDone: true)
        }
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 5)
        #expect(result.bestStreak == 5)
        #expect(result.isDueToday == true)
        #expect(result.isCompletedToday == true)
        #expect(result.isSkippedToday == false)
    }

    // MARK: - 2. Today In-Progress Preserves Streak

    @Test func todayInProgressPreservesStreakThroughYesterday() {
        let routine = makeRoutine()
        let checks = (1...4).map { day in
            makeCheck(routineId: routine.id, dayKey: String(format: "2026-09-%02d", day), isDone: true)
        }
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 4)
        #expect(result.bestStreak == 4)
        #expect(result.isDueToday == true)
        #expect(result.isCompletedToday == false)
        #expect(result.isSkippedToday == false)
    }

    // MARK: - 3. Today Completed Increments Streak

    @Test func todayCompletedIncrementsStreakFromYesterday() {
        let routine = makeRoutine()
        var checks = (1...4).map { day in
            makeCheck(routineId: routine.id, dayKey: String(format: "2026-09-%02d", day), isDone: true)
        }
        let beforeToday = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(beforeToday.currentStreak == 4)

        checks.append(makeCheck(routineId: routine.id, dayKey: "2026-09-05", isDone: true))
        let afterToday = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(afterToday.currentStreak == 5)
        #expect(afterToday.bestStreak == 5)
        #expect(afterToday.isCompletedToday == true)
    }

    // MARK: - 4. Missed Scheduled Days Reset Streak

    @Test func missedScheduledDayResetsCurrentStreak() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true)
            // 2026-09-04 is missed
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 3)
        #expect(result.isDueToday == true)
        #expect(result.isCompletedToday == false)
    }

    @Test func completionAfterMissedDayRestartsStreakAtOne() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true),
            // 2026-09-04 missed
            makeCheck(routineId: routine.id, dayKey: "2026-09-05", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 1)
        #expect(result.bestStreak == 3)
        #expect(result.isCompletedToday == true)
    }

    // MARK: - 5. Skipped Days Bridge Streak

    @Test func singleSkippedDayBridgesStreakWithoutBreaking() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true, isSkipped: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-03",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 2)
        #expect(result.isCompletedToday == true)
    }

    @Test func yesterdaySkippedPreservesStreakWhenTodayInProgress() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true, isSkipped: true)
            // 2026-09-03 in progress
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-03",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 1)
        #expect(result.bestStreak == 1)
        #expect(result.isDueToday == true)
        #expect(result.isCompletedToday == false)
    }

    // MARK: - 6. Multiple Consecutive Skips

    @Test func multipleConsecutiveSkipsBridgeStreak() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true, isSkipped: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true, isSkipped: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-04", isDone: true, isSkipped: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-05", isDone: true)
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

    @Test func skipsAloneDoNotGenerateStreak() {
        let routine = makeRoutine()
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true, isSkipped: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true, isSkipped: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true, isSkipped: true)
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-03",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.isSkippedToday == true)
    }

    // MARK: - 7. Workday-Only Habits (M-F) Bridge Weekends

    @Test func workdaysHabitBridgesWeekendWhenFridayCompleted() {
        let routine = makeRoutine(
            createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.workdays
        )
        // 2026-09-04 is Friday (weekday 6)
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-04", isDone: true)
        ]
        // On Saturday 2026-09-05 (weekend off-day)
        let saturday = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(saturday.currentStreak == 1)
        #expect(saturday.isDueToday == false)

        // On Sunday 2026-09-06 (weekend off-day)
        let sunday = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-06",
            calendar: utcCalendar
        )
        #expect(sunday.currentStreak == 1)
        #expect(sunday.isDueToday == false)

        // On Monday 2026-09-07 morning (workday, in progress)
        let mondayMorning = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-07",
            calendar: utcCalendar
        )
        #expect(mondayMorning.currentStreak == 1)
        #expect(mondayMorning.isDueToday == true)
        #expect(mondayMorning.isCompletedToday == false)
    }

    @Test func workdaysHabitWeekendCheckMaintainsStreakOnMonday() {
        let routine = makeRoutine(
            createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.workdays
        )
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-04", isDone: true), // Friday
            makeCheck(routineId: routine.id, dayKey: "2026-09-07", isDone: true)  // Monday
        ]
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-07",
            calendar: utcCalendar
        )
        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 2)
        #expect(result.isCompletedToday == true)
    }

    @Test func workdaysHabitBreaksWhenFridayMissed() {
        let routine = makeRoutine(
            createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.workdays
        )
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true)
            // 2026-09-04 (Friday) missed
        ]
        // On Saturday
        let saturday = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-05",
            calendar: utcCalendar
        )
        #expect(saturday.currentStreak == 0)
        #expect(saturday.bestStreak == 1)

        // On Monday morning
        let mondayMorning = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-07",
            calendar: utcCalendar
        )
        #expect(mondayMorning.currentStreak == 0)
        #expect(mondayMorning.bestStreak == 1)

        // On Monday completed
        var mondayChecks = checks
        mondayChecks.append(makeCheck(routineId: routine.id, dayKey: "2026-09-07", isDone: true))
        let mondayDone = HabitStreakLogic.calculate(
            routine: routine,
            checks: mondayChecks,
            todayKey: "2026-09-07",
            calendar: utcCalendar
        )
        #expect(mondayDone.currentStreak == 1)
        #expect(mondayDone.bestStreak == 1)
    }

    // MARK: - 8. Custom Weekday Masks

    @Test func customWeekdayMaskBridgesInterveningOffDays() {
        // Tuesday (weekday 3, bit 2: 4) and Thursday (weekday 5, bit 4: 16) -> mask = 20
        let tueThuMask = (1 << (3 - 1)) | (1 << (5 - 1))
        let routine = makeRoutine(
            createdDayKey: "2026-09-01",
            weekdayMask: tueThuMask
        )
        // 2026-09-01 is Tuesday, 2026-09-03 is Thursday
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true)
        ]

        // On Wednesday (off-day)
        let wednesday = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-02",
            calendar: utcCalendar
        )
        #expect(wednesday.currentStreak == 1)
        #expect(wednesday.isDueToday == false)

        // On Thursday (completed)
        let thursday = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-03",
            calendar: utcCalendar
        )
        #expect(thursday.currentStreak == 2)
        #expect(thursday.isDueToday == true)
        #expect(thursday.isCompletedToday == true)

        // On Friday through Monday (off-days)
        for offDay in ["2026-09-04", "2026-09-05", "2026-09-06", "2026-09-07"] {
            let res = HabitStreakLogic.calculate(
                routine: routine,
                checks: checks,
                todayKey: offDay,
                calendar: utcCalendar
            )
            #expect(res.currentStreak == 2)
            #expect(res.isDueToday == false)
        }
    }

    @Test func customWeekdayMaskNextScheduledDayProgression() {
        let tueThuMask = (1 << (3 - 1)) | (1 << (5 - 1))
        let routine = makeRoutine(
            createdDayKey: "2026-09-01",
            weekdayMask: tueThuMask
        )
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true)
        ]

        // On next Tuesday morning (uncompleted)
        let nextTuesdayMorning = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-08",
            calendar: utcCalendar
        )
        #expect(nextTuesdayMorning.currentStreak == 2)
        #expect(nextTuesdayMorning.isDueToday == true)
        #expect(nextTuesdayMorning.isCompletedToday == false)

        // On next Tuesday completed
        var checksWithNextTue = checks
        checksWithNextTue.append(makeCheck(routineId: routine.id, dayKey: "2026-09-08", isDone: true))
        let nextTuesdayDone = HabitStreakLogic.calculate(
            routine: routine,
            checks: checksWithNextTue,
            todayKey: "2026-09-08",
            calendar: utcCalendar
        )
        #expect(nextTuesdayDone.currentStreak == 3)
        #expect(nextTuesdayDone.bestStreak == 3)
    }
}
