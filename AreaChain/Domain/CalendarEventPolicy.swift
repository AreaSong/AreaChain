import Foundation

enum CalendarEventPolicy {
    static func shouldPublish(isDone: Bool, deletedAt: Date?) -> Bool {
        deletedAt == nil && !isDone
    }

    /// 专属日历里找不到已绑定事件时，只解开绑定，绝不把待办送进回收站。
    static func shouldUnlinkMissingRemote(deletedAt: Date?, calendarEventID: String, seenRemote: Bool) -> Bool {
        deletedAt == nil && !calendarEventID.isEmpty && !seenRemote
    }

    /// 系统日历改成全天时清掉本机时刻，避免下次推送又带上旧提醒。
    static func remoteRemindMinutes(isAllDay: Bool, startDate: Date) -> Int? {
        isAllDay ? nil : RemindMinutes.from(date: startDate)
    }
}
