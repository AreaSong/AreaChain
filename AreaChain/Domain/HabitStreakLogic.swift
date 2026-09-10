import Foundation

public struct StreakResult: Equatable, Sendable {
    public let currentStreak: Int
    public let bestStreak: Int
    public let isDueToday: Bool
    public let isCompletedToday: Bool
    public let isSkippedToday: Bool

    public init(
        currentStreak: Int,
        bestStreak: Int,
        isDueToday: Bool = false,
        isCompletedToday: Bool = false,
        isSkippedToday: Bool = false
    ) {
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.isDueToday = isDueToday
        self.isCompletedToday = isCompletedToday
        self.isSkippedToday = isSkippedToday
    }
}

enum HabitStreakLogic {
    static func calculate(
        routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> StreakResult {
        guard routine.deletedAt == nil,
              DayKey.date(from: todayKey, calendar: calendar) != nil else {
            return StreakResult(currentStreak: 0, bestStreak: 0)
        }

        let checkMap = buildCheckMap(for: routine.id, from: checks)
        let todayStatus = evaluateTodayStatus(
            routine: routine,
            todayCheck: checkMap[todayKey],
            todayKey: todayKey,
            calendar: calendar
        )

        guard routine.createdDayKey <= todayKey else {
            return StreakResult(
                currentStreak: 0,
                bestStreak: 0,
                isDueToday: todayStatus.isDueToday,
                isCompletedToday: todayStatus.isCompletedToday,
                isSkippedToday: todayStatus.isSkippedToday
            )
        }

        let startKey = DayKey.date(from: routine.createdDayKey, calendar: calendar) != nil
            ? routine.createdDayKey
            : todayKey

        let streaks = evaluateRunningStreakLoop(
            routine: routine,
            checkMap: checkMap,
            startKey: startKey,
            todayKey: todayKey,
            calendar: calendar
        )

        return StreakResult(
            currentStreak: streaks.currentStreak,
            bestStreak: streaks.bestStreak,
            isDueToday: todayStatus.isDueToday,
            isCompletedToday: todayStatus.isCompletedToday,
            isSkippedToday: todayStatus.isSkippedToday
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

    private struct TodayStatus {
        let isDueToday: Bool
        let isCompletedToday: Bool
        let isSkippedToday: Bool
    }

    private static func evaluateTodayStatus(
        routine: RoutineSnapshot,
        todayCheck: CheckSnapshot?,
        todayKey: String,
        calendar: Calendar
    ) -> TodayStatus {
        let isDue = routine.isEnabled
            && routine.createdDayKey <= todayKey
            && WeekdayMask.contains(routine.weekdayMask, dayKey: todayKey, calendar: calendar)
        let isCompleted = (todayCheck?.isDone == true && todayCheck?.isSkipped != true)
        let isSkipped = (todayCheck?.isSkipped == true)

        return TodayStatus(
            isDueToday: isDue,
            isCompletedToday: isCompleted,
            isSkippedToday: isSkipped
        )
    }

    private static func evaluateRunningStreakLoop(
        routine: RoutineSnapshot,
        checkMap: [String: CheckSnapshot],
        startKey: String,
        todayKey: String,
        calendar: Calendar
    ) -> (currentStreak: Int, bestStreak: Int) {
        var runningStreak = 0
        var bestStreak = 0
        var cursorKey = startKey

        while cursorKey <= todayKey {
            let isScheduled = WeekdayMask.contains(routine.weekdayMask, dayKey: cursorKey, calendar: calendar)
            let check = checkMap[cursorKey]

            if check?.isSkipped == true {
                // Transparent bridge: runningStreak unchanged
            } else if check?.isDone == true {
                // Scheduled or off-day completed
                runningStreak += 1
                if runningStreak > bestStreak {
                    bestStreak = runningStreak
                }
            } else if isScheduled {
                if cursorKey == todayKey {
                    // Today in progress: preserves streak through yesterday
                } else if isPaused(routine, on: cursorKey) {
                    // 停用区间当桥接，不把没打开的日子当成漏打
                } else {
                    // Missed scheduled day prior to today: breaks streak
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

    /// 启用时补跳过的起点：有暂停日用暂停日；旧数据从最后一次打卡（否则创建日）起算。
    static func skipFillStart(
        pausedOnDayKey: String?,
        createdDayKey: String,
        checkDayKeys: [String]
    ) -> String {
        if let paused = pausedOnDayKey, !paused.isEmpty {
            return paused
        }
        return checkDayKeys.max() ?? createdDayKey
    }

    /// 停用后的排定日不当漏打。无暂停起点的旧数据，停用期间全部桥接。
    private static func isPaused(_ routine: RoutineSnapshot, on dayKey: String) -> Bool {
        guard !routine.isEnabled else { return false }
        if let start = routine.pausedOnDayKey {
            return dayKey >= start
        }
        return true
    }
}
