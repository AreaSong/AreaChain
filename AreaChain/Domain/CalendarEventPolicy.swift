import Foundation

enum CalendarEventPolicy {
    static func shouldPublish(isDone: Bool, deletedAt: Date?) -> Bool {
        deletedAt == nil && !isDone
    }

    /// 专属日历里找不到已绑定事件时，只解开绑定，绝不把待办送进回收站。
    static func shouldUnlinkMissingRemote(deletedAt: Date?, calendarEventID: String, seenRemote: Bool) -> Bool {
        deletedAt == nil && !calendarEventID.isEmpty && !seenRemote
    }
}
