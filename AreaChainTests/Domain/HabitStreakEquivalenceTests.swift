import Foundation
import Testing
@testable import AreaChain

struct HabitStreakEquivalenceTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeRoutine(
        id: UUID = UUID(),
        createdDayKey: String,
        weekdayMask: Int = WeekdayMask.all,
        isEnabled: Bool = true,
        pausedOnDayKey: String? = nil,
        deletedAt: Date? = nil
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            title: "Streak Slice",
            sortOrder: 0,
            isEnabled: isEnabled,
            createdDayKey: createdDayKey,
            weekdayMask: weekdayMask,
            deletedAt: deletedAt,
            pausedOnDayKey: pausedOnDayKey
        )
    }

    private func expectEqual(
        _ routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        todayKey: String,
        calendar: Calendar? = nil
    ) {
        let cal = calendar ?? utcCalendar
        let actual = HabitStreakLogic.calculate(
            routine: routine, checks: checks, todayKey: todayKey, calendar: cal
        )
        let naive = HabitStreakNaiveCursor.calculate(
            routine: routine, checks: checks, todayKey: todayKey, calendar: cal
        )
        #expect(actual == naive)
    }

    @Test func emptyChecksOnCreatedTodayAreZero() {
        let routine = makeRoutine(createdDayKey: "2026-09-08")
        expectEqual(routine, checks: [], todayKey: "2026-09-08")
        let result = HabitStreakLogic.calculate(
            routine: routine, checks: [], todayKey: "2026-09-08", calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.isDueToday == true)
    }

    @Test func emptyChecksOnOldDailyHabitResetBeforeToday() {
        let routine = makeRoutine(createdDayKey: "2024-01-01")
        expectEqual(routine, checks: [], todayKey: "2026-09-08")
        let result = HabitStreakLogic.calculate(
            routine: routine, checks: [], todayKey: "2026-09-08", calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
    }

    @Test func crossYearAndLeapDayStayEquivalent() {
        let leap = makeRoutine(createdDayKey: "2024-02-27")
        let leapChecks = [
            CheckSnapshot(routineId: leap.id, dayKey: "2024-02-27", isDone: true),
            CheckSnapshot(routineId: leap.id, dayKey: "2024-02-28", isDone: true),
            CheckSnapshot(routineId: leap.id, dayKey: "2024-02-29", isDone: true),
            CheckSnapshot(routineId: leap.id, dayKey: "2024-03-01", isDone: true)
        ]
        expectEqual(leap, checks: leapChecks, todayKey: "2024-03-01")

        let year = makeRoutine(createdDayKey: "2025-12-30")
        let yearChecks = [
            CheckSnapshot(routineId: year.id, dayKey: "2025-12-30", isDone: true),
            CheckSnapshot(routineId: year.id, dayKey: "2025-12-31", isDone: true),
            CheckSnapshot(routineId: year.id, dayKey: "2026-01-01", isDone: true)
        ]
        expectEqual(year, checks: yearChecks, todayKey: "2026-01-01")
    }

    @Test func timezoneCalendarsStayEquivalentOnCivilKeys() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let routine = makeRoutine(createdDayKey: "2026-03-01")
        let checks = (1...15).map { day in
            CheckSnapshot(
                routineId: routine.id,
                dayKey: String(format: "2026-03-%02d", day),
                isDone: true
            )
        }
        expectEqual(routine, checks: checks, todayKey: "2026-03-15", calendar: tokyo)
    }

    @Test func pausedIntervalBridgesMissesAndKeepsDoneDays() {
        let id = UUID()
        let routine = makeRoutine(
            id: id,
            createdDayKey: "2026-09-01",
            isEnabled: false,
            pausedOnDayKey: "2026-09-03"
        )
        let checks = [
            CheckSnapshot(routineId: id, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: id, dayKey: "2026-09-02", isDone: true)
        ]
        expectEqual(routine, checks: checks, todayKey: "2026-09-08")
        let result = HabitStreakLogic.calculate(
            routine: routine, checks: checks, todayKey: "2026-09-08", calendar: utcCalendar
        )
        #expect(result.currentStreak == 2)
        #expect(result.isDueToday == false)
    }

    @Test func missBeforePauseStillResetsCurrentStreak() {
        let id = UUID()
        let routine = makeRoutine(
            id: id,
            createdDayKey: "2026-09-01",
            isEnabled: false,
            pausedOnDayKey: "2026-09-04"
        )
        let checks = [
            CheckSnapshot(routineId: id, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: id, dayKey: "2026-09-02", isDone: true)
        ]
        expectEqual(routine, checks: checks, todayKey: "2026-09-08")
        let result = HabitStreakLogic.calculate(
            routine: routine, checks: checks, todayKey: "2026-09-08", calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 2)
    }

    @Test func legacyDisabledWithoutPauseBridgesAllMisses() {
        let id = UUID()
        let routine = makeRoutine(
            id: id,
            createdDayKey: "2026-01-01",
            isEnabled: false
        )
        let checks = [
            CheckSnapshot(routineId: id, dayKey: "2026-01-01", isDone: true)
        ]
        expectEqual(routine, checks: checks, todayKey: "2026-09-08")
        let result = HabitStreakLogic.calculate(
            routine: routine, checks: checks, todayKey: "2026-09-08", calendar: utcCalendar
        )
        #expect(result.currentStreak == 1)
        #expect(result.isDueToday == false)
    }

    @Test func leftoverPauseKeyDoesNotBridgeAfterReenable() {
        let id = UUID()
        let routine = makeRoutine(
            id: id,
            createdDayKey: "2026-09-01",
            isEnabled: true,
            pausedOnDayKey: "2026-09-04"
        )
        let checks = [
            CheckSnapshot(routineId: id, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: id, dayKey: "2026-09-02", isDone: true)
        ]
        expectEqual(routine, checks: checks, todayKey: "2026-09-08")
        let result = HabitStreakLogic.calculate(
            routine: routine, checks: checks, todayKey: "2026-09-08", calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 2)
    }

    @Test func skipMissAndOffDayBonusStayEquivalent() {
        let id = UUID()
        let routine = makeRoutine(
            id: id,
            createdDayKey: "2026-09-04",
            weekdayMask: WeekdayMask.workdays
        )
        let checks = [
            CheckSnapshot(routineId: id, dayKey: "2026-09-04", isDone: true),
            CheckSnapshot(routineId: id, dayKey: "2026-09-05", isDone: true),
            CheckSnapshot(routineId: id, dayKey: "2026-09-07", isDone: true)
        ]
        expectEqual(routine, checks: checks, todayKey: "2026-09-07")
        expectEqual(routine, checks: checks, todayKey: "2026-09-08")
    }

    @Test func softDeletedRoutineStaysZero() {
        let routine = makeRoutine(createdDayKey: "2026-09-01", deletedAt: Date())
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true)
        ]
        expectEqual(routine, checks: checks, todayKey: "2026-09-02")
        let result = HabitStreakLogic.calculate(
            routine: routine, checks: checks, todayKey: "2026-09-02", calendar: utcCalendar
        )
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.isDueToday == false)
    }

    @Test func nonCanonicalTodayKeyMatchesCursorWalk() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: true)
        ]
        expectEqual(routine, checks: checks, todayKey: "2026-99-99")
    }

    @Test func foreignAndBlankChecksDoNotChangeIndexedResult() {
        let routine = makeRoutine(createdDayKey: "2026-09-01")
        let other = UUID()
        let checks = [
            CheckSnapshot(routineId: other, dayKey: "2026-09-01", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-01", isDone: false, isSkipped: false),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-02", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "not-a-date", isDone: true)
        ]
        expectEqual(routine, checks: checks, todayKey: "2026-09-03")
    }

    @Test func randomHistoriesMatchNaiveCursorIncludingPause() {
        var rng = EmpiricalPRNG(seed: 20260928)
        let masks = [WeekdayMask.all, WeekdayMask.workdays, 0b1000001, 0b0001000]
        let base = DayKey.date(from: "2024-01-01", calendar: utcCalendar)!

        for _ in 1...40 {
            let span = rng.nextInt(in: 20..<180)
            let startOffset = rng.nextInt(in: 0..<40)
            guard let startDate = utcCalendar.date(byAdding: .day, value: startOffset, to: base),
                  let endDate = utcCalendar.date(byAdding: .day, value: span, to: startDate) else {
                continue
            }
            let startKey = DayKey.from(startDate, calendar: utcCalendar)
            let todayKey = DayKey.from(endDate, calendar: utcCalendar)
            let enabled = rng.nextBool(probability: 0.7)
            var pause: String?
            if !enabled, rng.nextBool(probability: 0.6) {
                let pauseOffset = rng.nextInt(in: 0..<max(span, 1))
                pause = DayKey.from(
                    utcCalendar.date(byAdding: .day, value: pauseOffset, to: startDate)!,
                    calendar: utcCalendar
                )
            }
            let routine = makeRoutine(
                createdDayKey: startKey,
                weekdayMask: masks[rng.nextInt(in: 0..<masks.count)],
                isEnabled: enabled,
                pausedOnDayKey: pause
            )
            var checks = HabitStreakOracle.generateRandomChecks(
                startDate: startDate,
                endDate: endDate,
                routineId: routine.id,
                rng: &rng,
                calendar: utcCalendar
            )
            if rng.nextBool(probability: 0.3) {
                checks.append(contentsOf: HabitStreakOracle.generateRandomChecks(
                    startDate: startDate,
                    endDate: endDate,
                    routineId: UUID(),
                    rng: &rng,
                    calendar: utcCalendar
                ))
            }
            expectEqual(routine, checks: checks, todayKey: todayKey)
            if enabled {
                let oracle = HabitStreakOracle.calculate(
                    routine: routine, checks: checks, todayKey: todayKey, calendar: utcCalendar
                )
                let actual = HabitStreakLogic.calculate(
                    routine: routine, checks: checks, todayKey: todayKey, calendar: utcCalendar
                )
                #expect(actual == oracle)
            }
        }
    }

    @Test func sparseTenThousandDayHistoryStaysEquivalentAndFast() {
        let routine = makeRoutine(createdDayKey: "1998-01-01", weekdayMask: WeekdayMask.workdays)
        var checks: [CheckSnapshot] = []
        var cursor = DayKey.date(from: "1998-01-01", calendar: utcCalendar)!
        for index in 0..<10_000 {
            let key = DayKey.from(cursor, calendar: utcCalendar)
            if index % 37 == 0 {
                checks.append(CheckSnapshot(routineId: routine.id, dayKey: key, isDone: true))
            } else if index % 41 == 0 {
                checks.append(
                    CheckSnapshot(routineId: routine.id, dayKey: key, isDone: true, isSkipped: true)
                )
            }
            cursor = utcCalendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        let todayKey = DayKey.from(
            utcCalendar.date(byAdding: .day, value: -1, to: cursor)!,
            calendar: utcCalendar
        )

        let started = Date()
        let actual = HabitStreakLogic.calculate(
            routine: routine, checks: checks, todayKey: todayKey, calendar: utcCalendar
        )
        let elapsed = Date().timeIntervalSince(started)
        let naive = HabitStreakNaiveCursor.calculate(
            routine: routine, checks: checks, todayKey: todayKey, calendar: utcCalendar
        )

        #expect(actual == naive)
        #expect(actual.bestStreak >= actual.currentStreak)
        #expect(elapsed < 0.2, "10_000-day sparse calculation took \(elapsed)s")
    }
}
