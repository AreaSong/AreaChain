import Foundation
import Testing
@testable import AreaChain

@Suite("Tier 5 - Habit Streak & DayBoard White-Box Coverage Hardening")
struct HabitStreakTier5WhiteBoxCoverageTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeRoutine(
        id: UUID = UUID(),
        title: String = "Hardening Routine",
        createdDayKey: String = "2026-09-01",
        weekdayMask: Int = WeekdayMask.all,
        isEnabled: Bool = true,
        deletedAt: Date? = nil,
        sortOrder: Int = 0,
        projectID: UUID? = nil,
        tagIDs: String = "",
        isImportant: Bool = false,
        isUrgent: Bool = false,
        remindMinutes: Int? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            title: title,
            sortOrder: sortOrder,
            isEnabled: isEnabled,
            createdDayKey: createdDayKey,
            weekdayMask: weekdayMask,
            createdAt: createdAt,
            remindMinutes: remindMinutes,
            deletedAt: deletedAt,
            projectID: projectID,
            tagIDs: tagIDs,
            isImportant: isImportant,
            isUrgent: isUrgent
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

    // MARK: - 1. HabitStreakLogic: Disabled Routine Branch Coverage

    @Test func disabledRoutineSetsIsDueTodayFalseWhilePreservingStreakHistory() {
        let routine = makeRoutine(
            createdDayKey: "2026-09-01",
            isEnabled: false // Disabled routine
        )
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-03", isDone: true)
        ]

        // When today (2026-09-03) has check:
        let checkedToday = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-03",
            calendar: utcCalendar
        )
        #expect(checkedToday.isDueToday == false) // isEnabled == false -> isDueToday is false
        #expect(checkedToday.isCompletedToday == true)
        #expect(checkedToday.isSkippedToday == false)
        #expect(checkedToday.currentStreak == 3)
        #expect(checkedToday.bestStreak == 3)

        // When today (2026-09-04) is in progress without check:
        let inProgressToday = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-04",
            calendar: utcCalendar
        )
        #expect(inProgressToday.isDueToday == false) // isEnabled == false
        #expect(inProgressToday.isCompletedToday == false)
        #expect(inProgressToday.currentStreak == 3) // Streak preserved through yesterday
    }

    // MARK: - 2. HabitStreakLogic: Today Check Status Permutations

    @Test func todayCheckStatusPermutationsExhaustive() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let today = "2026-09-01"

        // Permutation A: (isDone: false, isSkipped: false)
        let checkA = [makeCheck(routineId: routine.id, dayKey: today, isDone: false, isSkipped: false)]
        let resA = HabitStreakLogic.calculate(routine: routine, checks: checkA, todayKey: today, calendar: utcCalendar)
        #expect(resA.isCompletedToday == false)
        #expect(resA.isSkippedToday == false)
        #expect(resA.currentStreak == 0)

        // Permutation B: (isDone: true, isSkipped: false)
        let checkB = [makeCheck(routineId: routine.id, dayKey: today, isDone: true, isSkipped: false)]
        let resB = HabitStreakLogic.calculate(routine: routine, checks: checkB, todayKey: today, calendar: utcCalendar)
        #expect(resB.isCompletedToday == true)
        #expect(resB.isSkippedToday == false)
        #expect(resB.currentStreak == 1)

        // Permutation C: (isDone: false, isSkipped: true)
        let checkC = [makeCheck(routineId: routine.id, dayKey: today, isDone: false, isSkipped: true)]
        let resC = HabitStreakLogic.calculate(routine: routine, checks: checkC, todayKey: today, calendar: utcCalendar)
        #expect(resC.isCompletedToday == false)
        #expect(resC.isSkippedToday == true)
        #expect(resC.currentStreak == 0)

        // Permutation D: (isDone: true, isSkipped: true) -> isSkipped takes precedence
        let checkD = [makeCheck(routineId: routine.id, dayKey: today, isDone: true, isSkipped: true)]
        let resD = HabitStreakLogic.calculate(routine: routine, checks: checkD, todayKey: today, calendar: utcCalendar)
        #expect(resD.isCompletedToday == false) // isSkipped prevents isCompletedToday
        #expect(resD.isSkippedToday == true)
        #expect(resD.currentStreak == 0)
    }

    // MARK: - 3. HabitStreakLogic: CheckMap Merging Combinations

    @Test func checkMapDuplicateMergingAllFourBooleanCombinations() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let day = "2026-09-01"

        // 1. (false, false) + (false, false)
        let checks1 = [
            makeCheck(routineId: routine.id, dayKey: day, isDone: false, isSkipped: false),
            makeCheck(routineId: routine.id, dayKey: day, isDone: false, isSkipped: false)
        ]
        let r1 = HabitStreakLogic.calculate(routine: routine, checks: checks1, todayKey: day, calendar: utcCalendar)
        #expect(r1.currentStreak == 0)
        #expect(r1.isCompletedToday == false)

        // 2. (true, false) + (false, false)
        let checks2 = [
            makeCheck(routineId: routine.id, dayKey: day, isDone: true, isSkipped: false),
            makeCheck(routineId: routine.id, dayKey: day, isDone: false, isSkipped: false)
        ]
        let r2 = HabitStreakLogic.calculate(routine: routine, checks: checks2, todayKey: day, calendar: utcCalendar)
        #expect(r2.currentStreak == 1)
        #expect(r2.isCompletedToday == true)

        // 3. (false, false) + (true, false)
        let checks3 = [
            makeCheck(routineId: routine.id, dayKey: day, isDone: false, isSkipped: false),
            makeCheck(routineId: routine.id, dayKey: day, isDone: true, isSkipped: false)
        ]
        let r3 = HabitStreakLogic.calculate(routine: routine, checks: checks3, todayKey: day, calendar: utcCalendar)
        #expect(r3.currentStreak == 1)
        #expect(r3.isCompletedToday == true)

        // 4. (false, true) + (true, false) -> merged has both done=true, skipped=true
        let checks4 = [
            makeCheck(routineId: routine.id, dayKey: day, isDone: false, isSkipped: true),
            makeCheck(routineId: routine.id, dayKey: day, isDone: true, isSkipped: false)
        ]
        let r4 = HabitStreakLogic.calculate(routine: routine, checks: checks4, todayKey: day, calendar: utcCalendar)
        #expect(r4.isSkippedToday == true)
        #expect(r4.isCompletedToday == false)
    }

    // MARK: - 4. HabitStreakLogic: While-Loop Branch Coverage

    @Test func whileLoopRunningStreakLessThanBestStreakBranchCoverage() {
        let routine = makeRoutine(createdDayKey: "2026-08-01")
        var checks: [CheckSnapshot] = []

        // Historical high streak: 6 days (Aug 01..06)
        for day in 1...6 {
            checks.append(makeCheck(routineId: routine.id, dayKey: String(format: "2026-08-%02d", day), isDone: true))
        }
        // Aug 07 missed
        // Rebuilding streak: 2 days (Aug 08, Aug 09)
        checks.append(makeCheck(routineId: routine.id, dayKey: "2026-08-08", isDone: true))
        checks.append(makeCheck(routineId: routine.id, dayKey: "2026-08-09", isDone: true))

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-08-09",
            calendar: utcCalendar
        )

        // runningStreak was 1 then 2, which are both <= bestStreak (6),
        // thoroughly exercising the false branch of `runningStreak > bestStreak`.
        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 6)
    }

    @Test func whileLoopSingleDayStartKeyEqualsTodayKeyExecutesOnce() {
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

    // MARK: - 5. HabitStreakLogic: Date Advancements & Far Boundaries

    @Test func farFutureCenturyBoundaryTransitions() {
        let routine = makeRoutine(createdDayKey: "2099-12-30")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2099-12-30", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2099-12-31", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2100-01-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2100-01-02", isDone: true)
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2100-01-02",
            calendar: utcCalendar
        )

        #expect(result.currentStreak == 4)
        #expect(result.bestStreak == 4)
    }

    @Test func year9999BoundaryTerminatesDeterministically() {
        let routine = makeRoutine(createdDayKey: "9999-12-30")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "9999-12-30", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "9999-12-31", isDone: true)
        ]

        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "9999-12-31",
            calendar: utcCalendar
        )

        #expect(result.currentStreak == 2)
        #expect(result.bestStreak == 2)
    }

    // MARK: - 6. DayBoardLogic: Habit Streak Forwarders Coverage

    @Test func dayBoardLogicHabitStreakForRoutineForwardsCompletely() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = [
            makeCheck(routineId: routine.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routine.id, dayKey: "2026-09-02", isDone: true)
        ]

        let direct = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-02",
            calendar: utcCalendar
        )

        let forwarded = DayBoardLogic.habitStreak(
            for: routine,
            checks: checks,
            todayKey: "2026-09-02",
            calendar: utcCalendar
        )

        #expect(forwarded == direct)
        #expect(forwarded.currentStreak == 2)
        #expect(forwarded.bestStreak == 2)
        #expect(forwarded.isDueToday == true)
        #expect(forwarded.isCompletedToday == true)
        #expect(forwarded.isSkippedToday == false)
    }

    @Test func dayBoardLogicHabitStreakEmptyChecksReturnsZero() {
        let streak = DayBoardLogic.habitStreak(
            checks: [],
            todayKey: "2026-09-08",
            calendar: utcCalendar
        )
        #expect(streak == 0)
    }

    @Test func dayBoardLogicHabitStreakFutureChecksOnlyUsesTodayKey() {
        let id = UUID()
        // Checks that only exist in the future relative to todayKey
        let futureChecks = [
            makeCheck(routineId: id, dayKey: "2026-09-15", isDone: true),
            makeCheck(routineId: id, dayKey: "2026-09-16", isDone: true)
        ]

        let streak = DayBoardLogic.habitStreak(
            checks: futureChecks,
            todayKey: "2026-09-08",
            calendar: utcCalendar
        )

        #expect(streak == 0)
    }

    // MARK: - 7. DayBoardLogic: Routine Lists & Queries Coverage

    @Test func dayBoardLogicOpenAndCompletedRoutines() {
        let r1 = makeRoutine(id: UUID(), title: "R1 Completed", createdDayKey: "2026-09-01")
        let r2 = makeRoutine(id: UUID(), title: "R2 Open", createdDayKey: "2026-09-01")
        let r3 = makeRoutine(id: UUID(), title: "R3 Skipped", createdDayKey: "2026-09-01")
        let r4 = makeRoutine(
            id: UUID(),
            title: "R4 Not Due",
            createdDayKey: "2026-09-01",
            weekdayMask: 1 << (4 - 1) // Wednesday only, but today is Tuesday
        )

        let today = "2026-09-08" // Tuesday
        let checks = [
            makeCheck(routineId: r1.id, dayKey: today, isDone: true, isSkipped: false),
            makeCheck(routineId: r3.id, dayKey: today, isDone: true, isSkipped: true)
        ]

        let open = DayBoardLogic.openRoutines(routines: [r1, r2, r3, r4], checks: checks, dayKey: today)
        #expect(open.map(\.title) == ["R2 Open"])

        let completed = DayBoardLogic.completedRoutines(routines: [r1, r2, r3, r4], checks: checks, dayKey: today)
        // isRoutineDone considers both isDone and isSkipped as closed/done
        #expect(completed.map(\.title) == ["R1 Completed", "R3 Skipped"])
    }

    @Test func dayBoardLogicIsRoutineDueDisabledRoutineReturnsFalse() {
        let disabled = makeRoutine(
            createdDayKey: "2026-09-01",
            isEnabled: false
        )
        #expect(DayBoardLogic.isRoutineDue(disabled, on: "2026-09-08") == false)
    }

    @Test func dayBoardLogicUpcomingTodosTieBreaksByTitle() {
        let today = "2026-09-08"
        let futureDay = "2026-09-10"
        let todoZ = TodoSnapshot(id: UUID(), title: "Zulu Task", isDone: false, dayKey: futureDay)
        let todoA = TodoSnapshot(id: UUID(), title: "Alpha Task", isDone: false, dayKey: futureDay)
        let todoM = TodoSnapshot(id: UUID(), title: "Mike Task", isDone: false, dayKey: futureDay)

        let upcoming = DayBoardLogic.upcomingTodos(todos: [todoZ, todoA, todoM], todayKey: today)
        #expect(upcoming.map(\.title) == ["Alpha Task", "Mike Task", "Zulu Task"])
    }

    @Test func dayBoardLogicMatchingRoutinesAndSortedForBoard() {
        let projA = UUID()
        let projB = UUID()

        let rLow = makeRoutine(
            id: UUID(),
            title: "Low Priority",
            projectID: projA,
            isImportant: false,
            isUrgent: false,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let rUrgent = makeRoutine(
            id: UUID(),
            title: "Urgent Routine",
            projectID: projA,
            isImportant: false,
            isUrgent: true,
            createdAt: Date(timeIntervalSince1970: 50)
        )
        let rImportantUrgent = makeRoutine(
            id: UUID(),
            title: "Critical Routine",
            projectID: projA,
            isImportant: true,
            isUrgent: true,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let rOtherProject = makeRoutine(
            id: UUID(),
            title: "Other Project Routine",
            projectID: projB,
            isImportant: true,
            isUrgent: true
        )

        // Matching routines by project filter
        let filterA = BoardFilter(projectID: projA)
        let matched = DayBoardLogic.matchingRoutines([rLow, rUrgent, rImportantUrgent, rOtherProject], filter: filterA)
        #expect(matched.count == 3)
        #expect(!matched.contains { $0.id == rOtherProject.id })

        // Sorted for board (Eisenhower order: Q1 Important+Urgent > Q2 Important > Q3 Urgent > Q4 Rest)
        let sorted = DayBoardLogic.sortedForBoard(matched)
        #expect(sorted.map(\.title) == ["Critical Routine", "Urgent Routine", "Low Priority"])
    }

    // MARK: - 8. Exhaustive Weekday Mask Permutations

    @Test func exhaustiveSingleWeekdayMaskPermutations() {
        // Test all 7 distinct individual weekdays (Sunday=1 through Saturday=7)
        // In Gregorian:
        // 2026-09-06 is Sunday (1)
        // 2026-09-07 is Monday (2)
        // 2026-09-08 is Tuesday (3)
        // 2026-09-09 is Wednesday (4)
        // 2026-09-10 is Thursday (5)
        // 2026-09-11 is Friday (6)
        // 2026-09-12 is Saturday (7)

        let testDays = [
            (dayKey: "2026-09-06", weekday: 1),
            (dayKey: "2026-09-07", weekday: 2),
            (dayKey: "2026-09-08", weekday: 3),
            (dayKey: "2026-09-09", weekday: 4),
            (dayKey: "2026-09-10", weekday: 5),
            (dayKey: "2026-09-11", weekday: 6),
            (dayKey: "2026-09-12", weekday: 7)
        ]

        for (dayKey, weekday) in testDays {
            let mask = 1 << (weekday - 1)
            let routine = makeRoutine(createdDayKey: dayKey, weekdayMask: mask)

            // 1. Day of habit: due and completed -> streak 1
            let check1 = [makeCheck(routineId: routine.id, dayKey: dayKey, isDone: true)]
            let res1 = HabitStreakLogic.calculate(routine: routine, checks: check1, todayKey: dayKey, calendar: utcCalendar)
            #expect(res1.currentStreak == 1)
            #expect(res1.isDueToday == true)
            #expect(res1.isCompletedToday == true)

            // 2. Off-day (1 day later): not due, streak preserved
            let offDayKey = DayKey.shifted(dayKey, by: 1, calendar: utcCalendar)
            let resOff = HabitStreakLogic.calculate(routine: routine, checks: check1, todayKey: offDayKey, calendar: utcCalendar)
            #expect(resOff.currentStreak == 1)
            #expect(resOff.isDueToday == false)

            // 3. Next scheduled occurrence (7 days later): completed -> streak 2
            let nextOccurKey = DayKey.shifted(dayKey, by: 7, calendar: utcCalendar)
            var checks2 = check1
            checks2.append(makeCheck(routineId: routine.id, dayKey: nextOccurKey, isDone: true))
            let res2 = HabitStreakLogic.calculate(routine: routine, checks: checks2, todayKey: nextOccurKey, calendar: utcCalendar)
            #expect(res2.currentStreak == 2)
            #expect(res2.bestStreak == 2)
            #expect(res2.isDueToday == true)
            #expect(res2.isCompletedToday == true)
        }
    }

    @Test func emptyWeekdayMaskZeroAndHighBitSanitization() {
        // Mask 0 sanitizes to all days (127)
        let routineZero = makeRoutine(createdDayKey: "2026-09-01", weekdayMask: 0)
        let checks = [
            makeCheck(routineId: routineZero.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routineZero.id, dayKey: "2026-09-02", isDone: true)
        ]
        let resZero = HabitStreakLogic.calculate(routine: routineZero, checks: checks, todayKey: "2026-09-02", calendar: utcCalendar)
        #expect(resZero.currentStreak == 2)
        #expect(resZero.isDueToday == true)

        // Mask 0xFF (255) sanitizes to all days (127)
        let routineHigh = makeRoutine(createdDayKey: "2026-09-01", weekdayMask: 0xFF)
        let checksHigh = [
            makeCheck(routineId: routineHigh.id, dayKey: "2026-09-01", isDone: true),
            makeCheck(routineId: routineHigh.id, dayKey: "2026-09-02", isDone: true)
        ]
        let resHigh = HabitStreakLogic.calculate(routine: routineHigh, checks: checksHigh, todayKey: "2026-09-02", calendar: utcCalendar)
        #expect(resHigh.currentStreak == 2)
        #expect(resHigh.isDueToday == true)
    }
}
