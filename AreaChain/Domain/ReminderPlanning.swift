import Foundation

enum RemindMinutes {
    static let range = 0..<1440

    static func clamped(_ value: Int?) -> Int? {
        guard let value, range.contains(value) else { return nil }
        return value
    }

    static func from(date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func date(minutes: Int, on base: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let minutes = clamped(minutes) else { return nil }
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: base)
    }

    static func label(_ minutes: Int, locale: Locale = .current, calendar: Calendar = .current) -> String {
        guard let date = date(minutes: minutes, calendar: calendar) else {
            return String(format: "%02d:%02d", minutes / 60, minutes % 60)
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum ClockLabel {
    static func created(
        _ date: Date,
        now: Date = .now,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        }
        return formatter.string(from: date)
    }
}

struct ReminderRequest: Equatable {
    var id: UUID
    var title: String
    var remindMinutes: Int
    var kind: Kind

    enum Kind: Equatable {
        case resident(days: Int, closedToday: Bool)
        case once(dayKey: String, isDone: Bool)
    }
}

enum ReminderPlanning {
    static let identifierPrefix = "areachain.remind."

    static func notificationID(_ id: UUID) -> String {
        identifierPrefix + id.uuidString
    }

    static func catalog(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        todayKey: String
    ) -> [ReminderRequest] {
        let standing = routines.compactMap { routine -> ReminderRequest? in
            guard routine.deletedAt == nil, routine.isEnabled, let minutes = RemindMinutes.clamped(routine.remindMinutes) else {
                return nil
            }
            return ReminderRequest(
                id: routine.id,
                title: routine.title,
                remindMinutes: minutes,
                kind: .resident(
                    days: WeekdayMask.sanitized(routine.weekdayMask),
                    closedToday: DayBoardLogic.isRoutineDone(routine, checks: checks, on: todayKey)
                )
            )
        }
        let once = todos.compactMap { todo -> ReminderRequest? in
            guard todo.deletedAt == nil, let minutes = RemindMinutes.clamped(todo.remindMinutes) else { return nil }
            return ReminderRequest(
                id: todo.id,
                title: todo.title,
                remindMinutes: minutes,
                kind: .once(dayKey: todo.dayKey, isDone: todo.isDone)
            )
        }
        return standing + once
    }

    static func nextFireDate(
        _ request: ReminderRequest,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard RemindMinutes.clamped(request.remindMinutes) != nil else { return nil }
        switch request.kind {
        case .once(let dayKey, let isDone):
            guard !isDone else { return nil }
            guard let fire = DayKey.date(dayKey: dayKey, minutes: request.remindMinutes, calendar: calendar)
            else { return nil }
            return fire > now ? fire : nil
        case .resident(let days, let closedToday):
            var cursor = DayKey.from(now, calendar: calendar)
            if closedToday {
                cursor = DayKey.shifted(cursor, by: 1, calendar: calendar)
            }
            for _ in 0..<16 {
                if !WeekdayMask.contains(days, dayKey: cursor, calendar: calendar) {
                    cursor = DayKey.shifted(cursor, by: 1, calendar: calendar)
                    continue
                }
                guard let fire = DayKey.date(dayKey: cursor, minutes: request.remindMinutes, calendar: calendar)
                else { return nil }
                if fire > now { return fire }
                cursor = DayKey.shifted(cursor, by: 1, calendar: calendar)
            }
            return nil
        }
    }
}
