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
    var tagIDs: String = ""
    var isImportant: Bool = false
    var isUrgent: Bool = false
    var sourceBundleID: String = ""
    var notes: String = ""
    var pausedOnDayKey: String?
    var subtasksJSON: String = ""

    @Relationship(deleteRule: .cascade, inverse: \RoutineCheck.routine)
    var checks: [RoutineCheck]

    init(
        id: UUID = UUID(),
        title: String,
        sortOrder: Int = 0,
        isEnabled: Bool = true,
        createdDayKey: String = "",
        weekdaysOnly: Bool = false,
        weekdayMask: Int? = nil,
        createdAt: Date = .now,
        remindMinutes: Int? = nil,
        deletedAt: Date? = nil,
        tagIDs: String = "",
        isImportant: Bool = false,
        isUrgent: Bool = false,
        sourceBundleID: String = "",
        notes: String = "",
        pausedOnDayKey: String? = nil,
        subtasksJSON: String = ""
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdDayKey = createdDayKey
        self.weekdaysOnly = weekdaysOnly
        self.weekdayMask = weekdayMask
        self.createdAt = createdAt
        self.remindMinutes = remindMinutes
        self.deletedAt = deletedAt
        self.tagIDs = tagIDs
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.sourceBundleID = sourceBundleID
        self.notes = notes
        self.pausedOnDayKey = pausedOnDayKey
        self.subtasksJSON = subtasksJSON
        self.checks = []
    }
}

@Model
final class RoutineCheck {
    var id: UUID
    var dayKey: String
    var isDone: Bool
    var isSkipped: Bool = false
    var completedSubtaskIDs: String = ""
    var routine: DailyRoutine?

    init(
        id: UUID = UUID(),
        dayKey: String,
        isDone: Bool = false,
        isSkipped: Bool = false,
        completedSubtaskIDs: String = "",
        routine: DailyRoutine? = nil
    ) {
        self.id = id
        self.dayKey = dayKey
        self.isDone = isDone
        self.isSkipped = isSkipped
        self.completedSubtaskIDs = completedSubtaskIDs
        self.routine = routine
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
    var tagIDs: String = ""
    var todo: TodoItem?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        deletedAt: Date? = nil,
        tagIDs: String = "",
        todo: TodoItem? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.tagIDs = tagIDs
        self.todo = todo
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
    var tagIDs: String = ""
    var isImportant: Bool = false
    var isUrgent: Bool = false
    var sourceBundleID: String = ""
    var calendarEventID: String = ""
    var notes: String = ""
    var sortOrder: Int = 0
    var dueMinutes: Int?

    @Relationship(deleteRule: .cascade, inverse: \SubtaskItem.todo)
    var subtasks: [SubtaskItem]

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        dayKey: String = "",
        createdAt: Date = .now,
        remindMinutes: Int? = nil,
        deletedAt: Date? = nil,
        tagIDs: String = "",
        isImportant: Bool = false,
        isUrgent: Bool = false,
        sourceBundleID: String = "",
        calendarEventID: String = "",
        notes: String = "",
        sortOrder: Int = 0,
        dueMinutes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.remindMinutes = remindMinutes
        self.deletedAt = deletedAt
        self.tagIDs = tagIDs
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.sourceBundleID = sourceBundleID
        self.calendarEventID = calendarEventID
        self.notes = notes
        self.sortOrder = sortOrder
        self.dueMinutes = dueMinutes
        self.subtasks = []
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
    var hasExplicitTitle: Bool = false
    var isPrivate: Bool = false
    var encryptedText: Data? = nil
    var privacyVaultID: UUID? = nil

    var hasProtectedContent: Bool { isPrivate || encryptedText != nil || privacyVaultID != nil }

    init(
        id: UUID = UUID(),
        text: String = "",
        dayKey: String = "",
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
}

@Model
final class TagItem {
    var id: UUID
    var name: String
    var sortOrder: Int
    var deletedAt: Date?
    var isPrivateDiary: Bool = false
    var colorToken: String = ""

    init(
        id: UUID = UUID(),
        name: String = "",
        sortOrder: Int = 0,
        deletedAt: Date? = nil,
        colorToken: String = "",
        isPrivateDiary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.deletedAt = deletedAt
        self.colorToken = colorToken
        self.isPrivateDiary = isPrivateDiary
    }
}

@Model
final class AttachmentItem {
    var id: UUID
    var ownerKind: String
    var ownerID: UUID
    var filename: String
    var createdAt: Date
    var deletedAt: Date?
    var storageID: UUID? = nil
    var privacyVaultID: UUID? = nil
    var retiredStorageID: UUID? = nil

    init(
        id: UUID = UUID(),
        ownerKind: String = "",
        ownerID: UUID = UUID(),
        filename: String = "",
        createdAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.ownerKind = ownerKind
        self.ownerID = ownerID
        self.filename = filename
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

enum WidgetSchema {
    static let models: [any PersistentModel.Type] = [
        DailyRoutine.self,
        RoutineCheck.self,
        TodoItem.self,
        SubtaskItem.self,
        DiaryEntry.self,
        TagItem.self,
        AttachmentItem.self
    ]
}
