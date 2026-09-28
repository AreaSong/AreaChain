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

        let streaks = evaluateRunningStreaks(
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
        map.reserveCapacity(min(checks.count, 64))
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

    private static func evaluateRunningStreaks(
        routine: RoutineSnapshot,
        checkMap: [String: CheckSnapshot],
        startKey: String,
        todayKey: String,
        calendar: Calendar
    ) -> (currentStreak: Int, bestStreak: Int) {
        if canUseIndexedWalk(routine: routine, startKey: startKey, todayKey: todayKey, calendar: calendar) {
            return evaluateIndexedStreakLoop(
                routine: routine,
                checkMap: checkMap,
                startKey: startKey,
                todayKey: todayKey,
                calendar: calendar
            )
        }
        return evaluateCursorStreakLoop(
            routine: routine,
            checkMap: checkMap,
            startKey: startKey,
            todayKey: todayKey,
            calendar: calendar
        )
    }

    /// 规范民事日后才按 checks 索引跳空档。非规范 today/created/pause 键仍按字符串上界逐日推进，避免与旧游标分叉。
    private static func canUseIndexedWalk(
        routine: RoutineSnapshot,
        startKey: String,
        todayKey: String,
        calendar: Calendar
    ) -> Bool {
        guard isCanonicalDayKey(startKey, calendar: calendar),
              isCanonicalDayKey(todayKey, calendar: calendar) else {
            return false
        }
        guard !routine.isEnabled, let pause = routine.pausedOnDayKey else {
            return true
        }
        return isCanonicalDayKey(pause, calendar: calendar)
    }

    private static func evaluateIndexedStreakLoop(
        routine: RoutineSnapshot,
        checkMap: [String: CheckSnapshot],
        startKey: String,
        todayKey: String,
        calendar: Calendar
    ) -> (currentStreak: Int, bestStreak: Int) {
        var runningStreak = 0
        var bestStreak = 0
        var gapStart = startKey
        let eventKeys = inRangeCanonicalCheckKeys(
            checkMap: checkMap, startKey: startKey, todayKey: todayKey, calendar: calendar
        )

        for key in eventKeys {
            let previous = DayKey.shifted(key, by: -1, calendar: calendar)
            if previous < key, gapStart <= previous {
                if gapContainsScheduledMiss(
                    routine: routine,
                    from: gapStart,
                    through: previous,
                    todayKey: todayKey,
                    calendar: calendar
                ) {
                    runningStreak = 0
                }
            }
            applyDay(
                key,
                check: checkMap[key],
                routine: routine,
                todayKey: todayKey,
                calendar: calendar,
                runningStreak: &runningStreak,
                bestStreak: &bestStreak
            )
            let next = DayKey.shifted(key, by: 1, calendar: calendar)
            guard next > key else {
                return (runningStreak, max(bestStreak, runningStreak))
            }
            gapStart = next
        }

        if gapStart <= todayKey,
           gapContainsScheduledMiss(
            routine: routine,
            from: gapStart,
            through: todayKey,
            todayKey: todayKey,
            calendar: calendar
           ) {
            runningStreak = 0
        }
        return (runningStreak, max(bestStreak, runningStreak))
    }

    private static func evaluateCursorStreakLoop(
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
            applyDay(
                cursorKey,
                check: checkMap[cursorKey],
                routine: routine,
                todayKey: todayKey,
                calendar: calendar,
                runningStreak: &runningStreak,
                bestStreak: &bestStreak
            )
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

    private static func applyDay(
        _ key: String,
        check: CheckSnapshot?,
        routine: RoutineSnapshot,
        todayKey: String,
        calendar: Calendar,
        runningStreak: inout Int,
        bestStreak: inout Int
    ) {
        if check?.isSkipped == true {
            return
        }
        if check?.isDone == true {
            runningStreak += 1
            if runningStreak > bestStreak {
                bestStreak = runningStreak
            }
            return
        }
        guard WeekdayMask.contains(routine.weekdayMask, dayKey: key, calendar: calendar) else {
            return
        }
        if key == todayKey || isPaused(routine, on: key) {
            return
        }
        runningStreak = 0
    }

    /// 空档里没有 skip/done。漏打一次就会清零，连续漏打仍是 0，因此只探测「是否存在一次漏打」。
    private static func gapContainsScheduledMiss(
        routine: RoutineSnapshot,
        from gapStart: String,
        through gapEnd: String,
        todayKey: String,
        calendar: Calendar
    ) -> Bool {
        guard gapStart <= gapEnd else { return false }
        if !routine.isEnabled, routine.pausedOnDayKey == nil {
            return false
        }

        var missEnd = gapEnd
        if todayKey >= gapStart, todayKey <= gapEnd {
            let yesterday = DayKey.shifted(todayKey, by: -1, calendar: calendar)
            guard yesterday < todayKey else { return false }
            missEnd = min(missEnd, yesterday)
        }
        if !routine.isEnabled, let pause = routine.pausedOnDayKey {
            let beforePause = DayKey.shifted(pause, by: -1, calendar: calendar)
            guard beforePause < pause else { return false }
            missEnd = min(missEnd, beforePause)
        }
        guard gapStart <= missEnd else { return false }
        return rangeContainsScheduledDay(
            from: gapStart, through: missEnd, mask: routine.weekdayMask, calendar: calendar
        )
    }

    private static func rangeContainsScheduledDay(
        from startKey: String,
        through endKey: String,
        mask: Int,
        calendar: Calendar
    ) -> Bool {
        guard startKey <= endKey,
              let start = DayKey.date(from: startKey, calendar: calendar),
              let end = DayKey.date(from: endKey, calendar: calendar),
              start <= end else {
            return false
        }
        if WeekdayMask.isAll(mask) {
            return true
        }
        // 连续 7 个民事日覆盖一周全部 weekday；`.day` 差值是不含起点的间隔。
        if let span = calendar.dateComponents([.day], from: start, to: end).day, span >= 6 {
            return true
        }
        var cursor = start
        while cursor <= end {
            if WeekdayMask.contains(mask, weekday: calendar.component(.weekday, from: cursor)) {
                return true
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else {
                return false
            }
            cursor = next
        }
        return false
    }

    private static func inRangeCanonicalCheckKeys(
        checkMap: [String: CheckSnapshot],
        startKey: String,
        todayKey: String,
        calendar: Calendar
    ) -> [String] {
        checkMap.keys.filter { key in
            key >= startKey && key <= todayKey && isCanonicalDayKey(key, calendar: calendar)
        }
        .sorted()
    }

    private static func isCanonicalDayKey(_ key: String, calendar: Calendar) -> Bool {
        guard let date = DayKey.date(from: key, calendar: calendar) else { return false }
        return DayKey.from(date, calendar: calendar) == key
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
