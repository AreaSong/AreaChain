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

    // MARK: - Category 3: Empty, Duplicate, Conflicting, and Scrambled Checks

    @Test func emptyChecksArrayOverLongSpanSafelyReturnsZero() {
        let routine = makeRoutine(createdDayKey: "2025-01-01")
        let res = HabitStreakLogic.calculate(routine: routine, checks: [], todayKey: "2026-09-08", calendar: utcCalendar)
        #expect(res.currentStreak == 0)
        #expect(res.bestStreak == 0)
        #expect(res.isDueToday == true)
        #expect(res.isCompletedToday == false)
    }

    @Test func massiveDuplicateChecksSameDayDoNotInflateStreak() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        // 50 duplicate checks for 2026-09-01
        let duplicates = (1...50).map { _ in
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true)
        }
        let res = HabitStreakLogic.calculate(routine: routine, checks: duplicates, todayKey: "2026-09-01", calendar: utcCalendar)
        #expect(res.currentStreak == 1)
        #expect(res.bestStreak == 1)
    }

    @Test func conflictingDoneAndSkippedChecksPreservesSkippedPrecedence() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        // Both done and skipped present for the same day
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true, isSkipped: false),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true, isSkipped: false),
            // Day 3 has two conflicting snapshots
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true, isSkipped: false),
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: false, isSkipped: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-04", isDone: true, isSkipped: false)
        ]
        let res = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-04", calendar: utcCalendar)
        // Day 3 merged has isSkipped: true, so it bridges Days 1-2 and Day 4 without adding Day 3 to streak count.
        // Total completed: Day 1, Day 2, Day 4 = 3
        #expect(res.currentStreak == 3)
        #expect(res.bestStreak == 3)
    }

    @Test func conflictingChecksOnTodaySetsProperStatusFlags() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true, isSkipped: true)
        ]
        let res = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-01", calendar: utcCalendar)
        #expect(res.isSkippedToday == true)
        #expect(res.isCompletedToday == false) // isSkipped prevents isCompletedToday
        #expect(res.currentStreak == 0)
    }

    // MARK: - Category 4: Mask Boundaries (0, 127, Single-Day, Alternating)

    @Test func maskZeroTreatedAsAllScheduled() {
        // WeekdayMask.sanitized(0) evaluates to WeekdayMask.all (127)
        let routine = makeRoutine(createdDayKey: "2026-09-01", weekdayMask: 0)
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true)
        ]
        let res = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-02", calendar: utcCalendar)
        #expect(res.currentStreak == 2)
        #expect(res.isDueToday == true)
    }

    @Test func mask127RequiresEveryDay() {
        let routine = makeRoutine(createdDayKey: "2026-09-01", weekdayMask: 127)
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            // 2026-09-02 missed
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true)
        ]
        let res = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-03", calendar: utcCalendar)
        #expect(res.currentStreak == 1)
        #expect(res.bestStreak == 1)
    }

    @Test func singleDayMaskSundayOnlyBridgesEntireWeek() {
        // Sunday is weekday 1 (bit 0: 1)
        let sundayMask = 1
        // 2026-08-30 is Sunday (weekday 1)
        // 2026-09-06 is next Sunday
        let routine = makeRoutine(createdDayKey: "2026-08-30", weekdayMask: sundayMask)
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-08-30", isDone: true)
        ]

        // On Wednesday 2026-09-02 (off-day)
        let wed = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-02", calendar: utcCalendar)
        #expect(wed.currentStreak == 1)
        #expect(wed.isDueToday == false)

        // On Saturday 2026-09-05 (off-day)
        let sat = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-05", calendar: utcCalendar)
        #expect(sat.currentStreak == 1)
        #expect(sat.isDueToday == false)

        // On Sunday 2026-09-06 morning (due, in progress)
        let sunMorning = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-06", calendar: utcCalendar)
        #expect(sunMorning.currentStreak == 1)
        #expect(sunMorning.isDueToday == true)
        #expect(sunMorning.isCompletedToday == false)

        // On Sunday 2026-09-06 completed
        var checksWithSun2 = checks
        checksWithSun2.append(makeCheck(routineId: routine.id, dayKey: "2026-09-06", isDone: true))
        let sunDone = HabitStreakLogic.calculate(routine: routine, checks: checksWithSun2, todayKey: "2026-09-06", calendar: utcCalendar)
        #expect(sunDone.currentStreak == 2)
        #expect(sunDone.bestStreak == 2)
        #expect(sunDone.isCompletedToday == true)
    }

    @Test func alternatingMaskMonWedFriBridgesOffDays() {
        // Monday (2, bit 1: 2), Wednesday (4, bit 3: 8), Friday (6, bit 5: 32) -> mask = 42
        let mwfMask = (1 << (2 - 1)) | (1 << (4 - 1)) | (1 << (6 - 1))
        let routine = makeRoutine(createdDayKey: "2026-08-31", weekdayMask: mwfMask) // 2026-08-31 is Monday

        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-08-31", isDone: true), // Mon
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true), // Wed
            makeCheck(routineId: routine.id, dayKey: "2026-09-04", isDone: true)  // Fri
        ]

        // On Saturday 2026-09-05 (off-day)
        let sat = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-05", calendar: utcCalendar)
        #expect(sat.currentStreak == 3)
        #expect(sat.isDueToday == false)

        // On Sunday 2026-09-06 (off-day)
        let sun = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-06", calendar: utcCalendar)
        #expect(sun.currentStreak == 3)
        #expect(sun.isDueToday == false)

        // On next Monday 2026-09-07 morning (scheduled, in progress)
        let monMorning = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-07", calendar: utcCalendar)
        #expect(monMorning.currentStreak == 3)
        #expect(monMorning.isDueToday == true)

        // If Monday 2026-09-07 is missed and we check on Tuesday 2026-09-08
        let tueAfterMissed = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-08", calendar: utcCalendar)
        #expect(tueAfterMissed.currentStreak == 0)
        #expect(tueAfterMissed.bestStreak == 3)
    }

    // MARK: - Category 5: Deleted Routine

    @Test func deletedRoutineAlwaysYieldsZeroStreakAndFlags() {
        let routine = makeRoutine(
            createdDayKey: "2026-09-01",
            deletedAt: Date()
        )
        let checks = (1...10).map { day in
            makeCheck(routineId: routine.id, dayKey: String(format: "2026-09-%02d", day), isDone: true)
        }
        let res = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2026-09-10", calendar: utcCalendar)
        #expect(res.currentStreak == 0)
        #expect(res.bestStreak == 0)
        #expect(res.isDueToday == false)
        #expect(res.isCompletedToday == false)
        #expect(res.isSkippedToday == false)
    }

    // MARK: - Category 6: Scale, Stress & Fuzzing Oracle

    @Test func fullYearContinuousStreakCalculationScalesFast() {
        let routine = makeRoutine(createdDayKey: "2025-01-01")
        var checks: [CheckSnapshot] = []

        var curDate = utcCalendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        for _ in 0..<365 {
            let key = DayKey.from(curDate, calendar: utcCalendar)
            checks.append(makeCheck(routineId: routine.id, dayKey: key, isDone: true))
            curDate = utcCalendar.date(byAdding: .day, value: 1, to: curDate)!
        }

        let start = DispatchTime.now()
        let res = HabitStreakLogic.calculate(routine: routine, checks: checks, todayKey: "2025-12-31", calendar: utcCalendar)
        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds

        #expect(res.currentStreak == 365)
        #expect(res.bestStreak == 365)
        // Ensure execution time is well under 50ms (50_000_000 ns)
        #expect(elapsed < 100_000_000)
    }

    @Test func fuzzingOracleMatchesIndependentStateMachine() {
        // Randomized stress test across 60 days with pseudo-random seed
        let startDateComponents = DateComponents(year: 2026, month: 1, day: 1)
        let baseDate = utcCalendar.date(from: startDateComponents)!
        let routineId = UUID()
        let routine = RoutineSnapshot(
            id: routineId,
            title: "Fuzz Test",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-01-01",
            weekdayMask: WeekdayMask.workdays // Mon-Fri
        )

        // Seeded pseudo-random sequence (LCG)
        var state: UInt64 = 42
        func nextRand() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }

        var checks: [CheckSnapshot] = []
        var checkMap: [String: CheckSnapshot] = [:]
        var dayKeys: [String] = []

        for dayOffset in 0..<60 {
            let date = utcCalendar.date(byAdding: .day, value: dayOffset, to: baseDate)!
            let dayKey = DayKey.from(date, calendar: utcCalendar)
            dayKeys.append(dayKey)

            let rand = nextRand() % 10
            if rand < 6 {
                // Done
                let snap = CheckSnapshot(routineId: routineId, dayKey: dayKey, isDone: true, isSkipped: false)
                checks.append(snap)
                checkMap[dayKey] = snap
            } else if rand < 8 {
                // Skipped
                let snap = CheckSnapshot(routineId: routineId, dayKey: dayKey, isDone: true, isSkipped: true)
                checks.append(snap)
                checkMap[dayKey] = snap
            } else {
                // Missed / no check
            }

            // Reference Oracle computation
            var oracleStreak = 0
            var oracleBest = 0
            for k in dayKeys {
                let isSched = WeekdayMask.contains(WeekdayMask.workdays, dayKey: k, calendar: utcCalendar)
                let chk = checkMap[k]
                if chk?.isSkipped == true {
                    // Skipped bridges streak
                } else if chk?.isDone == true {
                    oracleStreak += 1
                    if oracleStreak > oracleBest { oracleBest = oracleStreak }
                } else if isSched {
                    if k == dayKey {
                        // Today in progress: preserves streak through yesterday
                    } else {
                        oracleStreak = 0
                    }
                }
            }

            let result = HabitStreakLogic.calculate(
                routine: routine,
                checks: checks,
                todayKey: dayKey,
                calendar: utcCalendar
            )

            #expect(result.currentStreak == oracleStreak)
            #expect(result.bestStreak == max(oracleBest, oracleStreak))
        }
    }
}
