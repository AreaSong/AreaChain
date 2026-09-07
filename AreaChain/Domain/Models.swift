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
        sourceBundleID: String = ""
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
            sourceBundleID: sourceBundleID
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
        sourceBundleID: String = ""
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
            sourceBundleID: sourceBundleID
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
        DiaryEntry.self,
        ProjectItem.self,
        TagItem.self,
        AttachmentItem.self
    ]
}
