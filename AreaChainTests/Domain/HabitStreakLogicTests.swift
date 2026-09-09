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
        // 2026-09-01 is Tuesday
        // 2026-09-02 is Wednesday (off-day)
        // 2026-09-03 is Thursday (scheduled)
        // 2026-09-04..07 are Fri-Mon (off-days)
        // 2026-09-08 is Tuesday (scheduled)
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
}
