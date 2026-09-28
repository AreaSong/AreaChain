import Foundation
@testable import AreaChain

// MARK: - Independent Reference Oracle for Habit Streak Testing

enum HabitStreakOracle {
    static func calculate(
        routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        todayKey: String,
        calendar: Calendar
    ) -> StreakResult {
        guard routine.deletedAt == nil,
              let todayDate = DayKey.date(from: todayKey, calendar: calendar) else {
            return StreakResult(currentStreak: 0, bestStreak: 0, isDueToday: false, isCompletedToday: false, isSkippedToday: false)
        }

        let checkMap = buildCheckMap(checks: checks, routineId: routine.id)
        let isDueToday = routine.isEnabled && routine.createdDayKey <= todayKey
            && WeekdayMask.contains(routine.weekdayMask, dayKey: todayKey, calendar: calendar)
        let todayStatus = checkMap[todayKey]
        let isCompletedToday = (todayStatus?.done == true && todayStatus?.skipped != true)
        let isSkippedToday = (todayStatus?.skipped == true)

        let streaks = calculateStreakPair(
            routine: routine, checkMap: checkMap, todayKey: todayKey,
            todayDate: todayDate, isCompletedToday: isCompletedToday, calendar: calendar
        )
        return StreakResult(
            currentStreak: streaks.current, bestStreak: streaks.best,
            isDueToday: isDueToday, isCompletedToday: isCompletedToday, isSkippedToday: isSkippedToday
        )
    }

    private static func calculateStreakPair(
        routine: RoutineSnapshot,
        checkMap: [String: (done: Bool, skipped: Bool)],
        todayKey: String,
        todayDate: Date,
        isCompletedToday: Bool,
        calendar: Calendar
    ) -> (current: Int, best: Int) {
        guard routine.createdDayKey <= todayKey else {
            return (0, 0)
        }
        guard let startDate = DayKey.date(from: routine.createdDayKey, calendar: calendar) else {
            let fallback = isCompletedToday ? 1 : 0
            return (fallback, fallback)
        }
        let dayKeys = collectDayKeys(startDate: startDate, todayDate: todayDate, calendar: calendar)
        let streak = evaluateStreak(
            dayKeys: dayKeys,
            checkMap: checkMap,
            weekdayMask: routine.weekdayMask,
            todayKey: todayKey,
            calendar: calendar
        )
        return (streak.running, max(streak.best, streak.running))
    }

    private static func buildCheckMap(
        checks: [CheckSnapshot],
        routineId: UUID
    ) -> [String: (done: Bool, skipped: Bool)] {
        var map: [String: (done: Bool, skipped: Bool)] = [:]
        for c in checks where c.routineId == routineId {
            let existing = map[c.dayKey] ?? (false, false)
            map[c.dayKey] = (existing.done || c.isDone, existing.skipped || c.isSkipped)
        }
        return map
    }

    private static func collectDayKeys(
        startDate: Date,
        todayDate: Date,
        calendar: Calendar
    ) -> [String] {
        var dayKeys: [String] = []
        var cur = startDate
        while cur <= todayDate {
            dayKeys.append(DayKey.from(cur, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cur) else { break }
            if next <= cur { break }
            cur = next
        }
        return dayKeys
    }

    private static func evaluateStreak(
        dayKeys: [String],
        checkMap: [String: (done: Bool, skipped: Bool)],
        weekdayMask: Int,
        todayKey: String,
        calendar: Calendar
    ) -> (running: Int, best: Int) {
        var running = 0
        var best = 0

        for key in dayKeys {
            let isScheduled = WeekdayMask.contains(weekdayMask, dayKey: key, calendar: calendar)
            let status = checkMap[key]

            if status?.skipped == true {
                // Skipped day bridges without altering running streak
            } else if status?.done == true {
                running += 1
                if running > best { best = running }
            } else if isScheduled {
                if key != todayKey {
                    running = 0
                }
            }
        }
        return (running, best)
    }

    static func generateRandomChecks(
        startDate: Date,
        endDate: Date,
        routineId: UUID,
        rng: inout EmpiricalPRNG,
        calendar: Calendar
    ) -> [CheckSnapshot] {
        var checks: [CheckSnapshot] = []
        var cur = startDate
        while cur <= endDate {
            let key = DayKey.from(cur, calendar: calendar)
            let roll = rng.nextDouble()

            if roll < 0.45 {
                checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: false))
            } else if roll < 0.65 {
                checks.append(CheckSnapshot(routineId: routineId, dayKey: key, isDone: true, isSkipped: true))
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cur) else { break }
            cur = next
        }
        return checks
    }
}

// MARK: - Deterministic PRNG for Reproducible Empirical Tests

struct EmpiricalPRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed != 0 ? seed : 0x8a5cd789635d2dff
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound)
        return range.lowerBound + Int(next() % span)
    }

    mutating func nextDouble() -> Double {
        Double(next() & 0xFFFFFFFFFFFF) / Double(0x1000000000000)
    }

    mutating func nextBool(probability: Double = 0.5) -> Bool {
        nextDouble() < probability
    }
}

/// PHASE-3A 冻结的逐日游标：只给等价测试对照，不作为产品入口。
enum HabitStreakNaiveCursor {
    static func calculate(
        routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        todayKey: String,
        calendar: Calendar
    ) -> StreakResult {
        guard routine.deletedAt == nil,
              DayKey.date(from: todayKey, calendar: calendar) != nil else {
            return StreakResult(currentStreak: 0, bestStreak: 0)
        }

        let checkMap = buildCheckMap(for: routine.id, from: checks)
        let isDueToday = routine.isEnabled
            && routine.createdDayKey <= todayKey
            && WeekdayMask.contains(routine.weekdayMask, dayKey: todayKey, calendar: calendar)
        let todayCheck = checkMap[todayKey]
        let isCompletedToday = (todayCheck?.isDone == true && todayCheck?.isSkipped != true)
        let isSkippedToday = (todayCheck?.isSkipped == true)

        guard routine.createdDayKey <= todayKey else {
            return StreakResult(
                currentStreak: 0,
                bestStreak: 0,
                isDueToday: isDueToday,
                isCompletedToday: isCompletedToday,
                isSkippedToday: isSkippedToday
            )
        }

        let startKey = DayKey.date(from: routine.createdDayKey, calendar: calendar) != nil
            ? routine.createdDayKey
            : todayKey
        let streaks = walkDays(
            routine: routine,
            checkMap: checkMap,
            startKey: startKey,
            todayKey: todayKey,
            calendar: calendar
        )
        return StreakResult(
            currentStreak: streaks.current,
            bestStreak: streaks.best,
            isDueToday: isDueToday,
            isCompletedToday: isCompletedToday,
            isSkippedToday: isSkippedToday
        )
    }

    private static func buildCheckMap(
        for routineId: UUID,
        from checks: [CheckSnapshot]
    ) -> [String: CheckSnapshot] {
        var map: [String: CheckSnapshot] = [:]
        for check in checks where check.routineId == routineId {
            if let existing = map[check.dayKey] {
                map[check.dayKey] = CheckSnapshot(
                    routineId: routineId,
                    dayKey: check.dayKey,
                    isDone: existing.isDone || check.isDone,
                    isSkipped: existing.isSkipped || check.isSkipped
                )
            } else {
                map[check.dayKey] = check
            }
        }
        return map
    }

    private static func walkDays(
        routine: RoutineSnapshot,
        checkMap: [String: CheckSnapshot],
        startKey: String,
        todayKey: String,
        calendar: Calendar
    ) -> (current: Int, best: Int) {
        var runningStreak = 0
        var bestStreak = 0
        var cursorKey = startKey

        while cursorKey <= todayKey {
            let isScheduled = WeekdayMask.contains(routine.weekdayMask, dayKey: cursorKey, calendar: calendar)
            let check = checkMap[cursorKey]

            if check?.isSkipped == true {
                // bridge
            } else if check?.isDone == true {
                runningStreak += 1
                if runningStreak > bestStreak {
                    bestStreak = runningStreak
                }
            } else if isScheduled {
                if cursorKey == todayKey {
                    // today in progress
                } else if isPaused(routine, on: cursorKey) {
                    // paused bridge
                } else {
                    runningStreak = 0
                }
            }

            guard let date = DayKey.date(from: cursorKey, calendar: calendar),
                  let next = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            let nextKey = DayKey.from(next, calendar: calendar)
            guard nextKey > cursorKey else { break }
            cursorKey = nextKey
        }

        return (runningStreak, max(bestStreak, runningStreak))
    }

    private static func isPaused(_ routine: RoutineSnapshot, on dayKey: String) -> Bool {
        guard !routine.isEnabled else { return false }
        if let start = routine.pausedOnDayKey {
            return dayKey >= start
        }
        return true
    }
}
