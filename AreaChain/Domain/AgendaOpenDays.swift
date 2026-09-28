import Foundation

/// 待处理逾期日扫描。产品入口仍是 `AgendaProjection`；此文件只为单文件行数上限拆出局部索引。
enum AgendaOpenDays {
    struct ClosedIndex {
        private let days: [UUID: Set<String>]

        init(_ checks: [CheckSnapshot]) {
            var map: [UUID: Set<String>] = [:]
            for check in checks where check.isDone || check.isSkipped {
                map[check.routineId, default: []].insert(check.dayKey)
            }
            days = map
        }

        func days(for routineId: UUID) -> Set<String> {
            days[routineId] ?? []
        }
    }

    static func listed(
        _ routine: RoutineSnapshot,
        closed: Set<String>,
        from start: String,
        through end: String,
        calendar: Calendar
    ) -> [String] {
        var days: [String] = []
        enumerateProcessedDays(from: start, through: end, calendar: calendar) { cursor in
            if WeekdayMask.contains(routine.weekdayMask, dayKey: cursor, calendar: calendar),
               !closed.contains(cursor) {
                days.append(cursor)
            }
        }
        return days
    }

    static func summary(
        _ routine: RoutineSnapshot,
        closed: Set<String>,
        from start: String,
        through end: String,
        calendar: Calendar
    ) -> (latest: String, count: Int)? {
        if let fast = summaryByCount(
            routine, closed: closed, from: start, through: end, calendar: calendar
        ) {
            return fast
        }
        var latest: String?
        var count = 0
        enumerateProcessedDays(from: start, through: end, calendar: calendar) { cursor in
            guard WeekdayMask.contains(routine.weekdayMask, dayKey: cursor, calendar: calendar),
                  !closed.contains(cursor) else { return }
            count += 1
            latest = cursor
        }
        guard let latest else { return nil }
        return (latest, count)
    }

    /// 合法民事日上用星期计数代替最多 4000 步空日遍历；非规范日键仍走逐日扫描。
    private static func summaryByCount(
        _ routine: RoutineSnapshot,
        closed: Set<String>,
        from start: String,
        through end: String,
        calendar: Calendar
    ) -> (latest: String, count: Int)? {
        guard let startDate = DayKey.date(from: start, calendar: calendar),
              let endDate = DayKey.date(from: end, calendar: calendar),
              startDate <= endDate,
              let span = calendar.dateComponents([.day], from: startDate, to: endDate).day else {
            return nil
        }
        let processed = min(span + 1, 4000)
        guard processed > 0,
              let lastDate = calendar.date(byAdding: .day, value: processed - 1, to: startDate) else {
            return nil
        }
        let lastKey = DayKey.from(lastDate, calendar: calendar)
        let scheduled = scheduledDayCount(
            from: startDate, through: lastDate, mask: routine.weekdayMask, calendar: calendar
        )
        var closedScheduled = 0
        for key in closed {
            guard key >= start, key <= lastKey,
                  let date = DayKey.date(from: key, calendar: calendar),
                  DayKey.from(date, calendar: calendar) == key,
                  WeekdayMask.contains(routine.weekdayMask, dayKey: key, calendar: calendar) else {
                continue
            }
            closedScheduled += 1
        }
        let openCount = scheduled - closedScheduled
        guard openCount > 0 else { return nil }
        var cursor = lastKey
        var steps = 0
        while cursor >= start, steps < 4000 {
            if WeekdayMask.contains(routine.weekdayMask, dayKey: cursor, calendar: calendar),
               !closed.contains(cursor) {
                return (cursor, openCount)
            }
            let previous = DayKey.shifted(cursor, by: -1, calendar: calendar)
            guard previous < cursor else { break }
            cursor = previous
            steps += 1
        }
        return nil
    }

    private static func scheduledDayCount(
        from start: Date,
        through end: Date,
        mask: Int,
        calendar: Calendar
    ) -> Int {
        guard let span = calendar.dateComponents([.day], from: start, to: end).day else { return 0 }
        let days = span + 1
        guard days > 0 else { return 0 }
        let startWeekday = calendar.component(.weekday, from: start)
        let fullWeeks = days / 7
        let remainder = days % 7
        var count = 0
        for offset in 0..<7 {
            let weekday = ((startWeekday - 1 + offset) % 7) + 1
            guard WeekdayMask.contains(mask, weekday: weekday) else { continue }
            count += fullWeeks
            if offset < remainder { count += 1 }
        }
        return count
    }

    private static func enumerateProcessedDays(
        from start: String,
        through end: String,
        calendar: Calendar,
        visit: (String) -> Void
    ) {
        var cursor = start
        var steps = 0
        while cursor <= end, steps < 4000 {
            visit(cursor)
            let next = DayKey.shifted(cursor, by: 1, calendar: calendar)
            guard next > cursor else { break }
            cursor = next
            steps += 1
        }
    }
}
