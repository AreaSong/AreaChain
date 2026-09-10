import Foundation
import Testing
@testable import AreaChain

// MARK: - Empirical Challenger Test Suite

struct HabitStreakEmpiricalTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    // MARK: - 1. Complex Random Histories (30 to 365 days)

    private func makeRandomTrialFixture(
        trial: Int,
        routineId: UUID,
        baseDate: Date,
        masks: [Int],
        rng: inout EmpiricalPRNG
    ) -> (routine: RoutineSnapshot, checks: [CheckSnapshot], todayKey: String, daySpan: Int, mask: Int)? {
        let daySpan = rng.nextInt(in: 30..<365)
        let mask = masks[rng.nextInt(in: 0..<masks.count)]
        let startOffset = rng.nextInt(in: 0..<100)
        guard let startDate = utcCalendar.date(byAdding: .day, value: startOffset, to: baseDate),
              let endDate = utcCalendar.date(byAdding: .day, value: daySpan, to: startDate) else {
            return nil
        }

        let routine = RoutineSnapshot(
            id: routineId,
            title: "Empirical Routine \(trial)",
            sortOrder: trial,
            isEnabled: true,
            createdDayKey: DayKey.from(startDate, calendar: utcCalendar),
            weekdayMask: mask
        )
        let checks = HabitStreakOracle.generateRandomChecks(
            startDate: startDate,
            endDate: endDate,
            routineId: routineId,
            rng: &rng,
            calendar: utcCalendar
        )
        return (routine, checks, DayKey.from(endDate, calendar: utcCalendar), daySpan, mask)
    }

    private func runRandomHistoryTrial(
        trial: Int,
        routineId: UUID,
        baseDate: Date,
        masks: [Int],
        rng: inout EmpiricalPRNG
    ) {
        guard let fixture = makeRandomTrialFixture(
            trial: trial, routineId: routineId, baseDate: baseDate, masks: masks, rng: &rng
        ) else { return }

        let actual = HabitStreakLogic.calculate(
            routine: fixture.routine,
            checks: fixture.checks,
            todayKey: fixture.todayKey,
            calendar: utcCalendar
        )
        let oracle = HabitStreakOracle.calculate(
            routine: fixture.routine,
            checks: fixture.checks,
            todayKey: fixture.todayKey,
            calendar: utcCalendar
        )

        #expect(actual == oracle, "Mismatch on trial \(trial) with span \(fixture.daySpan) and mask \(fixture.mask)")
        #expect(actual.bestStreak >= actual.currentStreak, "Best streak must be >= current streak")
        #expect(actual.currentStreak >= 0)
        #expect(actual.bestStreak >= 0)
    }

    @Test func fuzzStreakWithRandomHistories30To365Days() {
        var rng = EmpiricalPRNG(seed: 20260908)
        let routineId = UUID()
        let masks = [
            WeekdayMask.all,
            WeekdayMask.workdays,
            0b1000001, // Weekends only (Sun + Sat)
            0b0001000, // Wednesday only
            0b0101010, // Mon, Wed, Fri
            0b0010100  // Tue, Thu
        ]
        let baseDate = DayKey.date(from: "2025-01-01", calendar: utcCalendar)!

        for trial in 1...50 {
            runRandomHistoryTrial(
                trial: trial,
                routineId: routineId,
                baseDate: baseDate,
                masks: masks,
                rng: &rng
            )
        }
    }

    // MARK: - 2. Alternating Check / Skip / Off-day Patterns

    @Test func alternatingCheckSkipOffDayPatterns() {
        let routineId = UUID()
        let routine = RoutineSnapshot(
            id: routineId,
            title: "Alternating Pattern Habit",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-01-01",
            weekdayMask: WeekdayMask.all
        )

        // Generate 60 days of [Done, Skipped, Done, Skipped, ...]
        var cur = DayKey.date(from: "2026-01-01", calendar: utcCalendar)!
        var checks: [CheckSnapshot] = []
        for i in 0..<60 {
            let key = DayKey.from(cur, calendar: utcCalendar)
            if i % 2 == 0 {
                // Even day: Done
                checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: false))
            } else {
                // Odd day: Skipped (bridges streak)
                checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: true))
            }
            cur = utcCalendar.date(byAdding: .day, value: 1, to: cur)!
        }

        let todayKey = DayKey.from(utcCalendar.date(byAdding: .day, value: -1, to: cur)!, calendar: utcCalendar)
        let actual = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: todayKey,
            calendar: utcCalendar
        )

        // 30 done days bridged by 30 skipped days = continuous 30-day streak
        #expect(actual.currentStreak == 30)
        #expect(actual.bestStreak == 30)
    }

    // MARK: - 3. Invariant: Non-Scheduled Days NEVER Decrease Streak

    private func stepOffDay(
        routineId: UUID,
        key: String,
        checks: inout [CheckSnapshot],
        rng: inout EmpiricalPRNG
    ) {
        let roll = rng.nextDouble()
        if roll < 0.33 {
            // No check
        } else if roll < 0.66 {
            checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: false, isSkipped: true))
        } else {
            checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: false))
        }
    }

    private func stepScheduledDay(
        routineId: UUID,
        key: String,
        checks: inout [CheckSnapshot],
        rng: inout EmpiricalPRNG
    ) {
        if rng.nextBool(probability: 0.8) {
            checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: false))
        } else {
            checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: true))
        }
    }

    @Test func invariantNonScheduledDaysNeverDecreaseStreak() {
        var rng = EmpiricalPRNG(seed: 424242)
        let routineId = UUID()

        // Workdays only habit (Mon-Fri)
        let routine = RoutineSnapshot(
            id: routineId,
            title: "Workday Habit",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.workdays
        )

        var cur = DayKey.date(from: "2026-09-01", calendar: utcCalendar)!
        var checks: [CheckSnapshot] = []
        var previousStreak = 0

        for _ in 0..<90 {
            let key = DayKey.from(cur, calendar: utcCalendar)
            let isScheduled = WeekdayMask.contains(WeekdayMask.workdays, dayKey: key, calendar: utcCalendar)

            if !isScheduled {
                stepOffDay(routineId: routineId, key: key, checks: &checks, rng: &rng)
                let result = HabitStreakLogic.calculate(
                    routine: routine,
                    checks: checks,
                    todayKey: key,
                    calendar: utcCalendar
                )
                #expect(result.currentStreak >= previousStreak, "Streak dropped on off-day \(key): was \(previousStreak), got \(result.currentStreak)")
                previousStreak = result.currentStreak
            } else {
                stepScheduledDay(routineId: routineId, key: key, checks: &checks, rng: &rng)
                let result = HabitStreakLogic.calculate(
                    routine: routine,
                    checks: checks,
                    todayKey: key,
                    calendar: utcCalendar
                )
                previousStreak = result.currentStreak
            }

            cur = utcCalendar.date(byAdding: .day, value: 1, to: cur)!
        }
    }

    // MARK: - 4. Invariant: Skipped Days NEVER Reset Streak

    @Test func invariantSkippedDaysNeverResetStreak() {
        let routineId = UUID()
        let routine = RoutineSnapshot(
            id: routineId,
            title: "Skip Invariant Habit",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.all
        )

        // Build a streak of 10 days
        var checks = (1...10).map { day in
            CheckSnapshot(routineId: routineId, dayKey: String(format: "2026-09-%02d", day), isDone: true, isSkipped: false)
        }

        let beforeSkip = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: "2026-09-10",
            calendar: utcCalendar
        )
        #expect(beforeSkip.currentStreak == 10)

        // Add 5 consecutive skipped days
        for day in 11...15 {
            let key = String(format: "2026-09-%02d", day)
            checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: true))

            let result = HabitStreakLogic.calculate(
                routine: routine,
                checks: checks,
                todayKey: key,
                calendar: utcCalendar
            )

            // Skipped day must maintain the 10 streak
            #expect(result.currentStreak == 10, "Day \(key) reset or changed streak to \(result.currentStreak)")
            #expect(result.bestStreak == 10)
        }
    }

    // MARK: - 5. Invariant: bestStreak >= currentStreak under All Conditions

    @Test func invariantBestStreakAlwaysGreaterOrEqualCurrentStreak() {
        var rng = EmpiricalPRNG(seed: 987654)
        let routineId = UUID()

        for trial in 1...30 {
            let routine = RoutineSnapshot(
                id: routineId,
                title: "Invariant Routine \(trial)",
                sortOrder: trial,
                isEnabled: true,
                createdDayKey: "2026-01-01",
                weekdayMask: WeekdayMask.all
            )

            var checks: [CheckSnapshot] = []
            var cur = DayKey.date(from: "2026-01-01", calendar: utcCalendar)!

            for _ in 1...60 {
                let key = DayKey.from(cur, calendar: utcCalendar)
                let choice = rng.nextInt(in: 0..<4)
                switch choice {
                case 0:
                    checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: false))
                case 1:
                    checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: true))
                case 2:
                    checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: false, isSkipped: false))
                default:
                    break // No check recorded
                }

                let result = HabitStreakLogic.calculate(
                    routine: routine,
                    checks: checks,
                    todayKey: key,
                    calendar: utcCalendar
                )

                #expect(result.bestStreak >= result.currentStreak, "Invariant violation: bestStreak (\(result.bestStreak)) < currentStreak (\(result.currentStreak)) on \(key)")
                #expect(result.currentStreak >= 0)
                #expect(result.bestStreak >= 0)

                cur = utcCalendar.date(byAdding: .day, value: 1, to: cur)!
            }
        }
    }

    // MARK: - 6. Timezones and DST Transitions Stress

    @Test func daylightSavingTimeTransitionsPreserveContinuity() {
        let timezones = [
            "America/New_York", // US Eastern (spring forward March, fall back Nov)
            "Europe/London",    // BST / GMT
            "Asia/Tokyo",       // UTC+9, no DST
            "Australia/Sydney"  // Southern hemisphere DST
        ]

        let routineId = UUID()

        for tzId in timezones {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: tzId)!

            // Period spanning US spring forward (March 8, 2026)
            let routine = RoutineSnapshot(
                id: routineId,
                title: "DST Routine \(tzId)",
                sortOrder: 0,
                isEnabled: true,
                createdDayKey: "2026-03-01",
                weekdayMask: WeekdayMask.all
            )

            var checks: [CheckSnapshot] = []
            for day in 1...15 {
                checks.append(CheckSnapshot(
                    routineId: routineId,
                    dayKey: String(format: "2026-03-%02d", day),
                    isDone: true,
                    isSkipped: false
                ))
            }

            let result = HabitStreakLogic.calculate(
                routine: routine,
                checks: checks,
                todayKey: "2026-03-15",
                calendar: cal
            )

            #expect(result.currentStreak == 15, "DST transition broke streak for timezone \(tzId)")
            #expect(result.bestStreak == 15)
        }
    }

    // MARK: - 7. Leap Year Continuity Stress

    @Test func leapYearContinuityStress() {
        let routineId = UUID()

        // 2024 is a leap year (Feb has 29 days)
        let leapRoutine = RoutineSnapshot(
            id: routineId,
            title: "Leap Routine",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2024-02-27",
            weekdayMask: WeekdayMask.all
        )

        let leapChecks = [
            CheckSnapshot(routineId: routineId, dayKey: "2024-02-27", isDone: true, isSkipped: false),
            CheckSnapshot(routineId: routineId, dayKey: "2024-02-28", isDone: true, isSkipped: false),
            CheckSnapshot(routineId: routineId, dayKey: "2024-02-29", isDone: true, isSkipped: false),
            CheckSnapshot(routineId: routineId, dayKey: "2024-03-01", isDone: true, isSkipped: false),
            CheckSnapshot(routineId: routineId, dayKey: "2024-03-02", isDone: true, isSkipped: false)
        ]

        let leapResult = HabitStreakLogic.calculate(
            routine: leapRoutine,
            checks: leapChecks,
            todayKey: "2024-03-02",
            calendar: utcCalendar
        )

        #expect(leapResult.currentStreak == 5)
        #expect(leapResult.bestStreak == 5)
    }

    // MARK: - 8. Scalability: 1000-Day Unbroken Streak

    @Test func thousandDayStreakPerformanceAndCorrectness() {
        let routineId = UUID()
        let routine = RoutineSnapshot(
            id: routineId,
            title: "Thousand Day Habit",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2023-01-01",
            weekdayMask: WeekdayMask.all
        )

        var cur = DayKey.date(from: "2023-01-01", calendar: utcCalendar)!
        var checks: [CheckSnapshot] = []
        for _ in 0..<1000 {
            let key = DayKey.from(cur, calendar: utcCalendar)
            checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: false))
            cur = utcCalendar.date(byAdding: .day, value: 1, to: cur)!
        }

        let todayKey = DayKey.from(utcCalendar.date(byAdding: .day, value: -1, to: cur)!, calendar: utcCalendar)

        let start = Date()
        let result = HabitStreakLogic.calculate(
            routine: routine,
            checks: checks,
            todayKey: todayKey,
            calendar: utcCalendar
        )
        let elapsed = Date().timeIntervalSince(start)

        #expect(result.currentStreak == 1000)
        #expect(result.bestStreak == 1000)
        #expect(elapsed < 0.2, "1000-day calculation must complete in under 200ms, took \(elapsed)s")
    }
}
