import Foundation
import SwiftData

@Model
final class DailyRoutine {
    var id: UUID
    var title: String
    var sortOrder: Int
    var isEnabled: Bool
    var createdDayKey: String
    var weekdaysOnly: Bool = false
    var weekdayMask: Int?
    var createdAt: Date = Date()
    var remindMinutes: Int?
    var deletedAt: Date?
    var projectID: UUID?
    var tagIDs: String = ""
    var isImportant: Bool = false
    var isUrgent: Bool = false
    var sourceBundleID: String = ""
    var notes: String = ""
    var pausedOnDayKey: String?

    @Relationship(deleteRule: .cascade, inverse: \RoutineCheck.routine)
    var checks: [RoutineCheck]

    init(
        id: UUID = UUID(),
        title: String,
        sortOrder: Int,
        isEnabled: Bool = true,
        createdDayKey: String = DayKey.today(),
        weekdaysOnly: Bool = false,
        weekdayMask: Int? = nil,
        createdAt: Date = .now,
        remindMinutes: Int? = nil,
        deletedAt: Date? = nil,
        projectID: UUID? = nil,
        tagIDs: String = "",
        isImportant: Bool = false,
        isUrgent: Bool = false,
        sourceBundleID: String = "",
        notes: String = "",
        pausedOnDayKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdDayKey = createdDayKey
        let mask = WeekdayMask.resolved(stored: weekdayMask, weekdaysOnly: weekdaysOnly)
        self.weekdayMask = mask
        self.weekdaysOnly = WeekdayMask.isWorkdays(mask)
        self.createdAt = createdAt
        self.remindMinutes = RemindMinutes.clamped(remindMinutes)
        self.deletedAt = deletedAt
        self.projectID = projectID
        self.tagIDs = tagIDs
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.sourceBundleID = sourceBundleID
        self.notes = notes
        self.pausedOnDayKey = pausedOnDayKey
        self.checks = []
    }

    var resolvedWeekdayMask: Int {
        WeekdayMask.resolved(stored: weekdayMask, weekdaysOnly: weekdaysOnly)
    }

    var classifyBits: ClassifyBits {
        ClassifyBits(
            projectID: projectID,
            tagIDs: tagIDs,
            isImportant: isImportant,
            isUrgent: isUrgent,
            sourceBundleID: sourceBundleID
        )
    }

    func setWeekdayMask(_ mask: Int) {
        let next = WeekdayMask.sanitized(mask)
        weekdayMask = next
        weekdaysOnly = WeekdayMask.isWorkdays(next)
    }

    var snapshot: RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            title: title,
            sortOrder: sortOrder,
            isEnabled: isEnabled,
            createdDayKey: createdDayKey,
            weekdayMask: resolvedWeekdayMask,
            createdAt: createdAt,
            remindMinutes: remindMinutes,
            deletedAt: deletedAt,
            projectID: projectID,
            tagIDs: tagIDs,
            isImportant: isImportant,
            isUrgent: isUrgent,
            sourceBundleID: sourceBundleID,
            notes: notes,
            pausedOnDayKey: pausedOnDayKey
        )
    }
}

@Model
final class RoutineCheck {
    var id: UUID
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
final class SubtaskItem {
    var id: UUID
    var title: String
    var isDone: Bool
    var sortOrder: Int
    var createdAt: Date
    var deletedAt: Date?
    var todo: TodoItem?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        deletedAt: Date? = nil,
        todo: TodoItem? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.todo = todo
    }

    var snapshot: SubtaskSnapshot? {
        guard let todoId = todo?.id else { return nil }
        return SubtaskSnapshot(
            id: id,
            todoId: todoId,
            title: title,
            isDone: isDone,
            sortOrder: sortOrder,
            createdAt: createdAt,
            deletedAt: deletedAt
        )
    }
}

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var isDone: Bool
    var dayKey: String
    var createdAt: Date
    var remindMinutes: Int?
    var deletedAt: Date?
    var projectID: UUID?
    var tagIDs: String = ""
    var isImportant: Bool = false
    var isUrgent: Bool = false
    var sourceBundleID: String = ""
    var calendarEventID: String = ""
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \SubtaskItem.todo)
    var subtasks: [SubtaskItem]

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        dayKey: String,
        createdAt: Date = .now,
        remindMinutes: Int? = nil,
        deletedAt: Date? = nil,
        projectID: UUID? = nil,
        tagIDs: String = "",
        isImportant: Bool = false,
        isUrgent: Bool = false,
        sourceBundleID: String = "",
        calendarEventID: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.remindMinutes = RemindMinutes.clamped(remindMinutes)
        self.deletedAt = deletedAt
        self.projectID = projectID
        self.tagIDs = tagIDs
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.sourceBundleID = sourceBundleID
        self.calendarEventID = calendarEventID
        self.notes = notes
        self.subtasks = []
    }

    var classifyBits: ClassifyBits {
        ClassifyBits(
            projectID: projectID,
            tagIDs: tagIDs,
            isImportant: isImportant,
            isUrgent: isUrgent,
            sourceBundleID: sourceBundleID
        )
    }

    var snapshot: TodoSnapshot {
        TodoSnapshot(
            id: id,
            title: title,
            isDone: isDone,
            dayKey: dayKey,
            createdAt: createdAt,
            remindMinutes: remindMinutes,
            deletedAt: deletedAt,
            projectID: projectID,
            tagIDs: tagIDs,
            isImportant: isImportant,
            isUrgent: isUrgent,
            sourceBundleID: sourceBundleID,
            notes: notes,
            subtasks: subtasks.filter { $0.deletedAt == nil }.sorted(by: { $0.sortOrder < $1.sortOrder }).compactMap { $0.snapshot }
        )
    }
}

@Model
final class DiaryEntry {
    var id: UUID
    var text: String
    var dayKey: String
    var createdAt: Date
    var deletedAt: Date?
    var tagIDs: String = ""
    var isPinned: Bool = false

    init(
        id: UUID = UUID(),
        text: String,
        dayKey: String,
        createdAt: Date = .now,
        deletedAt: Date? = nil,
        tagIDs: String = "",
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.tagIDs = tagIDs
        self.isPinned = isPinned
    }

    var snapshot: DiarySnapshot {
        DiarySnapshot(
            id: id,
            text: text,
            dayKey: dayKey,
            createdAt: createdAt,
            deletedAt: deletedAt,
            tagIDs: tagIDs,
            isPinned: isPinned
        )
    }
}

enum AreaChainSchema {
    static let models: [any PersistentModel.Type] = [
        DailyRoutine.self,
        RoutineCheck.self,
        TodoItem.self,
        SubtaskItem.self,
        DiaryEntry.self,
        ProjectItem.self,
        TagItem.self,
        AttachmentItem.self
    ]
}
