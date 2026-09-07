import Foundation

struct ExportSnapshot: Codable, Equatable {
    var exportedAt: Date
    var routines: [ExportedRoutine]
    var checks: [ExportedCheck]
    var todos: [ExportedTodo]
    var diaries: [ExportedDiary]
}

struct ExportedRoutine: Codable, Equatable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var isEnabled: Bool
    var createdDayKey: String
    var weekdaysOnly: Bool
    var createdAt: Date?
    var remindMinutes: Int?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, sortOrder, isEnabled, createdDayKey, weekdaysOnly, createdAt, remindMinutes, deletedAt
    }

    init(
        id: UUID,
        title: String,
        sortOrder: Int,
        isEnabled: Bool,
        createdDayKey: String,
        weekdaysOnly: Bool = false,
        createdAt: Date? = nil,
        remindMinutes: Int? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdDayKey = createdDayKey
        self.weekdaysOnly = weekdaysOnly
        self.createdAt = createdAt
        self.remindMinutes = RemindMinutes.clamped(remindMinutes)
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        title = try box.decode(String.self, forKey: .title)
        sortOrder = try box.decode(Int.self, forKey: .sortOrder)
        isEnabled = try box.decode(Bool.self, forKey: .isEnabled)
        createdDayKey = try box.decode(String.self, forKey: .createdDayKey)
        weekdaysOnly = try box.decodeIfPresent(Bool.self, forKey: .weekdaysOnly) ?? false
        createdAt = try box.decodeIfPresent(Date.self, forKey: .createdAt)
        remindMinutes = RemindMinutes.clamped(try box.decodeIfPresent(Int.self, forKey: .remindMinutes))
        deletedAt = try box.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct ExportedCheck: Codable, Equatable {
    var id: UUID
    var routineId: UUID
    var dayKey: String
    var isDone: Bool
    var isSkipped: Bool

    enum CodingKeys: String, CodingKey {
        case id, routineId, dayKey, isDone, isSkipped
    }

    init(
        id: UUID,
        routineId: UUID,
        dayKey: String,
        isDone: Bool,
        isSkipped: Bool = false
    ) {
        self.id = id
        self.routineId = routineId
        self.dayKey = dayKey
        self.isDone = isDone
        self.isSkipped = isSkipped
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        routineId = try box.decode(UUID.self, forKey: .routineId)
        dayKey = try box.decode(String.self, forKey: .dayKey)
        isDone = try box.decode(Bool.self, forKey: .isDone)
        isSkipped = try box.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
    }
}

struct ExportedTodo: Codable, Equatable {
    var id: UUID
    var title: String
    var isDone: Bool
    var dayKey: String
    var createdAt: Date
    var remindMinutes: Int?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, isDone, dayKey, createdAt, remindMinutes, deletedAt
    }

    init(
        id: UUID,
        title: String,
        isDone: Bool,
        dayKey: String,
        createdAt: Date,
        remindMinutes: Int? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.remindMinutes = RemindMinutes.clamped(remindMinutes)
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        title = try box.decode(String.self, forKey: .title)
        isDone = try box.decode(Bool.self, forKey: .isDone)
        dayKey = try box.decode(String.self, forKey: .dayKey)
        createdAt = try box.decode(Date.self, forKey: .createdAt)
        remindMinutes = RemindMinutes.clamped(try box.decodeIfPresent(Int.self, forKey: .remindMinutes))
        deletedAt = try box.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct ExportedDiary: Codable, Equatable {
    var id: UUID
    var text: String
    var dayKey: String
    var createdAt: Date
    var deletedAt: Date? = nil
}

enum SyncPort {
    static func makeSnapshot(
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem],
        diaries: [DiaryEntry],
        exportedAt: Date = .now
    ) -> ExportSnapshot {
        ExportSnapshot(
            exportedAt: exportedAt,
            routines: routines.map {
                ExportedRoutine(
                    id: $0.id,
                    title: $0.title,
                    sortOrder: $0.sortOrder,
                    isEnabled: $0.isEnabled,
                    createdDayKey: $0.createdDayKey,
                    weekdaysOnly: $0.weekdaysOnly,
                    createdAt: $0.createdAt,
                    remindMinutes: $0.remindMinutes,
                    deletedAt: $0.deletedAt
                )
            },
            checks: checks.compactMap { check in
                guard let routineId = check.routine?.id else { return nil }
                return ExportedCheck(
                    id: check.id,
                    routineId: routineId,
                    dayKey: check.dayKey,
                    isDone: check.isDone,
                    isSkipped: check.isSkipped
                )
            },
            todos: todos.map {
                ExportedTodo(
                    id: $0.id,
                    title: $0.title,
                    isDone: $0.isDone,
                    dayKey: $0.dayKey,
                    createdAt: $0.createdAt,
                    remindMinutes: $0.remindMinutes,
                    deletedAt: $0.deletedAt
                )
            },
            diaries: diaries.map {
                ExportedDiary(
                    id: $0.id,
                    text: $0.text,
                    dayKey: $0.dayKey,
                    createdAt: $0.createdAt,
                    deletedAt: $0.deletedAt
                )
            }
        )
    }

    static func encode(_ snapshot: ExportSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    static func decode(_ data: Data) throws -> ExportSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportSnapshot.self, from: data)
    }
}
