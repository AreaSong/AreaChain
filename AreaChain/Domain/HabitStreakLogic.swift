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
        guard routine.deletedAt == nil else {
            return StreakResult(
                currentStreak: 0,
                bestStreak: 0,
                isDueToday: false,
                isCompletedToday: false,
                isSkippedToday: false
            )
        }

        guard DayKey.date(from: todayKey, calendar: calendar) != nil else {
            return StreakResult(
                currentStreak: 0,
                bestStreak: 0,
                isDueToday: false,
                isCompletedToday: false,
                isSkippedToday: false
            )
        }

        var checkMap: [String: CheckSnapshot] = [:]
        for check in checks where check.routineId == routine.id {
            if let existing = checkMap[check.dayKey] {
                checkMap[check.dayKey] = CheckSnapshot(
                    routineId: routine.id,
                    dayKey: check.dayKey,
                    isDone: existing.isDone || check.isDone,
                    isSkipped: existing.isSkipped || check.isSkipped
                )
            } else {
                checkMap[check.dayKey] = check
            }
        }

        let todayCheck = checkMap[todayKey]
        let isDueToday = routine.isEnabled
            && routine.createdDayKey <= todayKey
            && WeekdayMask.contains(routine.weekdayMask, dayKey: todayKey, calendar: calendar)
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
            } else {
                // Off-day bridge: runningStreak unchanged
            }

            guard let date = DayKey.date(from: cursorKey, calendar: calendar),
                  let next = calendar.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            let nextKey = DayKey.from(next, calendar: calendar)
            guard nextKey > cursorKey else { break }
            cursorKey = nextKey
        }

        return StreakResult(
            currentStreak: runningStreak,
            bestStreak: max(bestStreak, runningStreak),
            isDueToday: isDueToday,
            isCompletedToday: isCompletedToday,
            isSkippedToday: isSkippedToday
        )
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
