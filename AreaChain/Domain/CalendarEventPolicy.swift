import Foundation

enum CalendarEventPolicy {
    static func shouldPublish(isDone: Bool, deletedAt: Date?) -> Bool {
        deletedAt == nil && !isDone
    }

    /// 专属日历里找不到已绑定事件时，只解开绑定，绝不把待办送进回收站。
    static func shouldUnlinkMissingRemote(deletedAt: Date?, calendarEventID: String, seenRemote: Bool) -> Bool {
        deletedAt == nil && !calendarEventID.isEmpty && !seenRemote
    }

    /// 待办日期落在本次拉取窗口之外时，不能当成「远端删了事件」。
    static func shouldUnlinkMissingRemote(
        deletedAt: Date?,
        calendarEventID: String,
        seenRemote: Bool,
        dayKey: String,
        windowStart: Date,
        windowEnd: Date
    ) -> Bool {
        guard shouldUnlinkMissingRemote(
            deletedAt: deletedAt,
            calendarEventID: calendarEventID,
            seenRemote: seenRemote
        ) else { return false }
        guard let day = DayKey.date(from: dayKey) else { return true }
        return day >= windowStart && day <= windowEnd
    }

    /// 系统日历改成全天时清掉本机时刻，避免下次推送又带上旧提醒。
    static func remoteRemindMinutes(isAllDay: Bool, startDate: Date) -> Int? {
        isAllDay ? nil : RemindMinutes.from(date: startDate)
    }

    /// EventKit 全天日期按 GMT 午夜存，不用设备本地时区。
    static var gmtGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// EventKit 全天结束日是开区间，必须比开始多一天。
    static func allDayEnd(from start: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }

    /// 把 `dayKey` 写成 EventKit 全天区间（GMT 午夜 → 次日 GMT 午夜）。
    static func allDayBounds(dayKey: String, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        guard let localDay = DayKey.date(from: dayKey, calendar: calendar) else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: localDay)
        let gmt = gmtGregorian
        guard let start = gmt.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day)) else {
            return nil
        }
        return (start, allDayEnd(from: start, calendar: gmt))
    }

    /// EventKit 全天 `startDate` 按 GMT 午夜存民事日期；用本地时区会在西半球错一天。
    static func remoteDayKey(
        isAllDay: Bool,
        startDate: Date,
        calendar: Calendar = .current
    ) -> String {
        if isAllDay {
            return DayKey.from(startDate, calendar: gmtGregorian)
        }
        return DayKey.from(startDate, calendar: calendar)
    }

    static func eventQueryBounds(
        now: Date = .now,
        dayKeys: [String],
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        var start = calendar.date(byAdding: .year, value: -2, to: now) ?? now
        var end = calendar.date(byAdding: .year, value: 2, to: now) ?? now
        for key in dayKeys {
            guard let day = DayKey.date(from: key, calendar: calendar) else { continue }
            if let padded = calendar.date(byAdding: .day, value: -1, to: day), padded < start {
                start = padded
            }
            if let padded = calendar.date(byAdding: .day, value: 2, to: day), padded > end {
                end = padded
            }
        }
        if end <= start {
            end = start.addingTimeInterval(86_400)
        }
        return (start, end)
    }

    /// 专属日历里：无活 token、未绑定任何待办的事件（含清掉 notes 的旧事件）应删掉。
    static func shouldRemoveOrphanEvent(
        notes: String?,
        eventIdentifier: String?,
        liveTokens: Set<String>,
        knownEventIDs: Set<String>,
        unpublishedEventIDs: Set<String>
    ) -> Bool {
        let token = notes ?? ""
        if liveTokens.contains(token) { return false }
        let ident = eventIdentifier ?? ""
        if unpublishedEventIDs.contains(ident) { return true }
        if TodoDragToken.decode(token) != nil { return true }
        if !ident.isEmpty && knownEventIDs.contains(ident) { return false }
        return true
    }
}
