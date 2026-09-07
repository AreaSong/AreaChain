import Foundation
import SwiftData

@Model
final class DailyRoutine {
    @Attribute(.unique) var id: UUID
    var title: String
    var sortOrder: Int
    var isEnabled: Bool
    var createdDayKey: String
    var weekdaysOnly: Bool = false
    var createdAt: Date = Date()
    var remindMinutes: Int?
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \RoutineCheck.routine)
    var checks: [RoutineCheck]

    init(
        id: UUID = UUID(),
        title: String,
        sortOrder: Int,
        isEnabled: Bool = true,
        createdDayKey: String = DayKey.today(),
        weekdaysOnly: Bool = false,
        createdAt: Date = .now,
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
        self.checks = []
    }

    var snapshot: RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            title: title,
            sortOrder: sortOrder,
            isEnabled: isEnabled,
            createdDayKey: createdDayKey,
            weekdaysOnly: weekdaysOnly,
            createdAt: createdAt,
            remindMinutes: remindMinutes,
            deletedAt: deletedAt
        )
    }
}

@Model
final class RoutineCheck {
    @Attribute(.unique) var id: UUID
    var dayKey: String
    var isDone: Bool
    var isSkipped: Bool = false
    var routine: DailyRoutine?

    init(
        id: UUID = UUID(),
        dayKey: String,
        isDone: Bool = false,
        isSkipped: Bool = false,
        routine: DailyRoutine? = nil
    ) {
        self.id = id
        self.dayKey = dayKey
        self.isDone = isDone
        self.isSkipped = isSkipped
        self.routine = routine
    }

    var snapshot: CheckSnapshot? {
        guard let routineId = routine?.id else { return nil }
        return CheckSnapshot(
            routineId: routineId,
            dayKey: dayKey,
            isDone: isDone,
            isSkipped: isSkipped
        )
    }
}

@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isDone: Bool
    var dayKey: String
    var createdAt: Date
    var remindMinutes: Int?
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        dayKey: String,
        createdAt: Date = .now,
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

    var snapshot: TodoSnapshot {
        TodoSnapshot(
            id: id,
            title: title,
            isDone: isDone,
            dayKey: dayKey,
            createdAt: createdAt,
            remindMinutes: remindMinutes,
            deletedAt: deletedAt
        )
    }
}

@Model
final class DiaryEntry {
    @Attribute(.unique) var id: UUID
    var text: String
    var dayKey: String
    var createdAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        text: String,
        dayKey: String,
        createdAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }

    var snapshot: DiarySnapshot {
        DiarySnapshot(id: id, text: text, dayKey: dayKey, createdAt: createdAt, deletedAt: deletedAt)
    }
}

enum AreaChainSchema {
    static let models: [any PersistentModel.Type] = [
        DailyRoutine.self,
        RoutineCheck.self,
        TodoItem.self,
        DiaryEntry.self
    ]
}
