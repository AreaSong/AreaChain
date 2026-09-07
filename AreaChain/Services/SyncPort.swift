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
}

struct ExportedDiary: Codable, Equatable {
    var id: UUID
    var text: String
    var dayKey: String
    var createdAt: Date
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
                    createdDayKey: $0.createdDayKey
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
                    createdAt: $0.createdAt
                )
            },
            diaries: diaries.map {
                ExportedDiary(
                    id: $0.id,
                    text: $0.text,
                    dayKey: $0.dayKey,
                    createdAt: $0.createdAt
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
