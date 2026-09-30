import Foundation

enum HabitDayMark: Equatable {
    case padding
    case outside
    case checked
    case skipped
    case missed
    case open
}

enum HabitMonth {
    static func mark(
        dayKey: String?,
        routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> HabitDayMark {
        guard let dayKey else { return .padding }
        guard routine.deletedAt == nil,
              routine.createdDayKey <= dayKey,
              WeekdayMask.contains(routine.weekdayMask, dayKey: dayKey, calendar: calendar) else {
            return .outside
        }
        if let check = checks.first(where: { $0.routineId == routine.id && $0.dayKey == dayKey }) {
            if check.isDone && check.isSkipped { return .skipped }
            if check.isDone { return .checked }
        }
        if dayKey < todayKey { return .missed }
        return .open
    }
}
