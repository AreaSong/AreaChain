import Foundation

enum CalendarEventPolicy {
    static func shouldPublish(isDone: Bool, deletedAt: Date?) -> Bool {
        deletedAt == nil && !isDone
    }
}
