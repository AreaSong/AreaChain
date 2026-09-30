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
    var closedDayKeys: Set<String> = []
    var createdDayKey: String? = nil

    enum Kind: Equatable {
        case resident(days: Int, closedToday: Bool)
        case once(dayKey: String, isDone: Bool)
    }
}

/// 通知中心里一条待发送提醒的可比较快照；不含正文，避免把用户标题以外的本地化文案算进是否需要重排。
struct ReminderNotificationRecord: Equatable, Hashable {
    var identifier: String
    var title: String
    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var minute: Int

    var dateComponents: DateComponents {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components
    }

    static func make(identifier: String, title: String, fire: Date, calendar: Calendar) -> ReminderNotificationRecord? {
        make(identifier: identifier, title: title, components: calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fire
        ))
    }

    static func make(identifier: String, title: String, components: DateComponents) -> ReminderNotificationRecord? {
        guard let year = components.year, let month = components.month, let day = components.day,
              let hour = components.hour, let minute = components.minute else {
            return nil
        }
        return ReminderNotificationRecord(
            identifier: identifier,
            title: title,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
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
                ),
                closedDayKeys: Set(checks.filter {
                    $0.routineId == routine.id && ($0.isDone || $0.isSkipped) && $0.dayKey >= todayKey
                }.map(\.dayKey)),
                createdDayKey: routine.createdDayKey
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
            if let createdDayKey = request.createdDayKey, createdDayKey > cursor {
                cursor = createdDayKey
            }
            // 每个已闭合日最多排除一周的候选；不能把长期提前打卡误当成没有下一次提醒。
            for _ in 0..<(request.closedDayKeys.count * 7 + 8) {
                if request.closedDayKeys.contains(cursor)
                    || !WeekdayMask.contains(days, dayKey: cursor, calendar: calendar) {
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

    static func records(
        catalog: [ReminderRequest],
        now: Date,
        calendar: Calendar = .current
    ) -> [ReminderNotificationRecord] {
        catalog.compactMap { request in
            guard let fire = nextFireDate(request, now: now, calendar: calendar) else { return nil }
            return ReminderNotificationRecord.make(
                identifier: notificationID(request.id),
                title: request.title,
                fire: fire,
                calendar: calendar
            )
        }
    }

    static let snoozeMarker = "snooze."
    static let catchUpMarker = "catchup."

    static func snoozeID(_ id: UUID) -> String {
        identifierPrefix + snoozeMarker + id.uuidString
    }

    static func catchUpID(_ id: UUID, dayKey: String) -> String {
        identifierPrefix + catchUpMarker + id.uuidString + "|" + dayKey
    }

    static func itemID(from identifier: String) -> UUID? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        var rest = String(identifier.dropFirst(identifierPrefix.count))
        if let bar = rest.firstIndex(of: "|") {
            rest = String(rest[..<bar])
        }
        if rest.hasPrefix(snoozeMarker) { rest.removeFirst(snoozeMarker.count) }
        if rest.hasPrefix(catchUpMarker) { rest.removeFirst(catchUpMarker.count) }
        return UUID(uuidString: rest)
    }

    static func catchUpDay(from identifier: String) -> String? {
        guard let bar = identifier.firstIndex(of: "|") else { return nil }
        let day = String(identifier[identifier.index(after: bar)...])
        return day.isEmpty ? nil : day
    }

    static func isClosedForFollowUp(_ request: ReminderRequest, todayKey: String) -> Bool {
        switch request.kind {
        case .once(_, let isDone):
            return isDone
        case .resident(_, let closedToday):
            return closedToday || request.closedDayKeys.contains(todayKey)
        }
    }

    static func shouldCatchUp(
        _ request: ReminderRequest,
        now: Date,
        todayKey: String,
        calendar: Calendar = .current
    ) -> Bool {
        guard !isClosedForFollowUp(request, todayKey: todayKey) else { return false }
        switch request.kind {
        case .once(let dayKey, _):
            guard dayKey == todayKey else { return false }
            guard let fire = DayKey.date(dayKey: dayKey, minutes: request.remindMinutes, calendar: calendar) else {
                return false
            }
            return fire <= now
        case .resident(let days, _):
            guard WeekdayMask.contains(days, dayKey: todayKey, calendar: calendar) else { return false }
            if let created = request.createdDayKey, created > todayKey { return false }
            guard let fire = DayKey.date(dayKey: todayKey, minutes: request.remindMinutes, calendar: calendar) else {
                return false
            }
            return fire <= now
        }
    }

    /// 横幅按整分触发。下一次补发用下一个整分，避免秒数和触发分对不上。
    static func nextWholeMinute(after now: Date, calendar: Calendar) -> Date? {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        guard let minute = calendar.date(from: parts) else { return nil }
        return calendar.date(byAdding: .minute, value: 1, to: minute)
    }

    /// 触发分还没到，这条仍应留在待发送计划里。
    static func triggerIsAwaiting(_ fire: Date, now: Date, calendar: Calendar) -> Bool {
        guard let minute = calendar.date(from: calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fire
        )) else { return false }
        return minute > now
    }

    /// 触发分当分钟内不要取消或重排。过了这一分，系统已经送达的横幅不再由计划重发。
    static func shouldRetainIssuedFire(_ fire: Date, now: Date, calendar: Calendar) -> Bool {
        guard let minute = calendar.date(from: calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fire
        )), let deadline = calendar.date(byAdding: .minute, value: 1, to: minute) else {
            return false
        }
        return now < deadline
    }

    static func deliveryRecords(
        catalog: [ReminderRequest],
        followUps: [UUID: ReminderFollowUp],
        now: Date,
        todayKey: String,
        calendar: Calendar = .current
    ) -> (records: [ReminderNotificationRecord], issuedCatchUps: [UUID: Date], retainedIDs: Set<String>) {
        var records: [ReminderNotificationRecord] = []
        var issued: [UUID: Date] = [:]
        var retained: Set<String> = []
        for request in catalog {
            let follow = followUps[request.id] ?? ReminderFollowUp()
            let closed = isClosedForFollowUp(request, todayKey: todayKey)
            if !closed, let snooze = follow.snoozeFire,
               shouldRetainIssuedFire(snooze, now: now, calendar: calendar) {
                retained.insert(snoozeID(request.id))
            }
            let snoozePending = !closed && follow.snoozeFire.map {
                triggerIsAwaiting($0, now: now, calendar: calendar)
            } == true
            if snoozePending, let snooze = follow.snoozeFire,
               let record = ReminderNotificationRecord.make(
                identifier: snoozeID(request.id),
                title: request.title,
                fire: snooze,
                calendar: calendar
               ) {
                records.append(record)
            }
            if let fire = nextFireDate(request, now: now, calendar: calendar),
               let record = ReminderNotificationRecord.make(
                identifier: notificationID(request.id),
                title: request.title,
                fire: fire,
                calendar: calendar
               ) {
                records.append(record)
            }
            if snoozePending || closed { continue }
            if follow.catchUpDayKey == todayKey {
                if let fire = follow.catchUpFire {
                    let identifier = catchUpID(request.id, dayKey: todayKey)
                    if shouldRetainIssuedFire(fire, now: now, calendar: calendar) {
                        retained.insert(identifier)
                    }
                    if triggerIsAwaiting(fire, now: now, calendar: calendar),
                       let record = ReminderNotificationRecord.make(
                        identifier: identifier,
                        title: request.title,
                        fire: fire,
                        calendar: calendar
                       ) {
                        records.append(record)
                    }
                }
                continue
            }
            if shouldCatchUp(request, now: now, todayKey: todayKey, calendar: calendar),
               let fire = nextWholeMinute(after: now, calendar: calendar),
               let record = ReminderNotificationRecord.make(
                identifier: catchUpID(request.id, dayKey: todayKey),
                title: request.title,
                fire: fire,
                calendar: calendar
               ) {
                records.append(record)
                retained.insert(record.identifier)
                issued[request.id] = fire
            }
        }
        return (records, issued, retained)
    }
}

struct ReminderFollowUp: Equatable {
    var catchUpDayKey: String?
    var catchUpFire: Date?
    var snoozeFire: Date?
}

enum ReminderActions {
    static let category = "areachain.reminder"
    static let complete = "areachain.reminder.complete"
    static let snooze10 = "areachain.reminder.snooze.10"
    static let snooze60 = "areachain.reminder.snooze.60"
    static let tenMinutes: TimeInterval = 600
    static let oneHour: TimeInterval = 3600
}
