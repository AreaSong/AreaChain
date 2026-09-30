import Foundation

/// 今日、手记和菜单栏共用筛选里需要跨启动记住的部分。日期范围只留在本次运行。
enum BoardFilterCodec {
    struct Payload: Codable, Equatable {
        var taskTagID: String?
        var taskBundleID: String?
        var taskPriority: String
        var taskReminder: String
        var diaryTagID: String?
    }

    static func payload(from filters: BoardFilters) -> Payload {
        Payload(
            taskTagID: filters.tasks.tagID?.uuidString,
            taskBundleID: filters.tasks.bundleID,
            taskPriority: filters.tasks.priorityScope.rawValue,
            taskReminder: filters.tasks.reminderScope.rawValue,
            diaryTagID: filters.diary.tagID?.uuidString
        )
    }

    static func filters(from payload: Payload) -> BoardFilters {
        var filters = BoardFilters()
        filters.tasks.tagID = payload.taskTagID.flatMap(UUID.init(uuidString:))
        let bundle = payload.taskBundleID?.trimmingCharacters(in: .whitespacesAndNewlines)
        filters.tasks.bundleID = bundle?.isEmpty == false ? bundle : nil
        let priority = PriorityFilterScope(rawValue: payload.taskPriority) ?? .all
        filters.tasks = filters.tasks.withPriorityScope(priority)
        filters.tasks.reminderScope = ReminderFilterScope(rawValue: payload.taskReminder) ?? .all
        filters.diary.tagID = payload.diaryTagID.flatMap(UUID.init(uuidString:))
        return filters
    }

    static func encode(_ filters: BoardFilters) -> Data? {
        try? JSONEncoder().encode(payload(from: filters))
    }

    static func decode(_ data: Data) -> BoardFilters? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        return filters(from: payload)
    }
}
