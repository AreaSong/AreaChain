import Foundation

struct ExportSnapshot: Codable, Equatable {
    var exportedAt: Date
    var routines: [ExportedRoutine]
    var checks: [ExportedCheck]
    var todos: [ExportedTodo]
    var diaries: [ExportedDiary]
    var projects: [ExportedProject]
    var tags: [ExportedTag]
    var attachments: [ExportedAttachment]

    enum CodingKeys: String, CodingKey {
        case exportedAt, routines, checks, todos, diaries, projects, tags, attachments
    }

    init(
        exportedAt: Date,
        routines: [ExportedRoutine],
        checks: [ExportedCheck],
        todos: [ExportedTodo],
        diaries: [ExportedDiary],
        projects: [ExportedProject] = [],
        tags: [ExportedTag] = [],
        attachments: [ExportedAttachment] = []
    ) {
        self.exportedAt = exportedAt
        self.routines = routines
        self.checks = checks
        self.todos = todos
        self.diaries = diaries
        self.projects = projects
        self.tags = tags
        self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        exportedAt = try box.decode(Date.self, forKey: .exportedAt)
        routines = try box.decode([ExportedRoutine].self, forKey: .routines)
        checks = try box.decode([ExportedCheck].self, forKey: .checks)
        todos = try box.decode([ExportedTodo].self, forKey: .todos)
        diaries = try box.decode([ExportedDiary].self, forKey: .diaries)
        projects = try box.decodeIfPresent([ExportedProject].self, forKey: .projects) ?? []
        tags = try box.decodeIfPresent([ExportedTag].self, forKey: .tags) ?? []
        attachments = try box.decodeIfPresent([ExportedAttachment].self, forKey: .attachments) ?? []
    }
}

struct ExportedProject: Codable, Equatable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var parentID: UUID? = nil
    var deletedAt: Date? = nil
}

struct ExportedTag: Codable, Equatable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var deletedAt: Date? = nil
}

struct ExportedAttachment: Codable, Equatable {
    var id: UUID
    var ownerKind: String
    var ownerID: UUID
    var filename: String
    var createdAt: Date
    var deletedAt: Date? = nil
}

struct ExportedSubtask: Codable, Equatable {
    var id: UUID
    var title: String
    var isDone: Bool
    var sortOrder: Int
    var createdAt: Date? = nil
    var deletedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id, title, isDone, sortOrder, createdAt, deletedAt
    }

    init(
        id: UUID,
        title: String,
        isDone: Bool,
        sortOrder: Int = 0,
        createdAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        title = try box.decode(String.self, forKey: .title)
        isDone = try box.decode(Bool.self, forKey: .isDone)
        sortOrder = try box.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try box.decodeIfPresent(Date.self, forKey: .createdAt)
        deletedAt = try box.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct ExportedRoutine: Codable, Equatable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var isEnabled: Bool
    var createdDayKey: String
    var weekdaysOnly: Bool
    var weekdayMask: Int
    var createdAt: Date?
    var remindMinutes: Int?
    var deletedAt: Date?
    var projectID: UUID?
    var tagIDs: String
    var isImportant: Bool
    var isUrgent: Bool
    var sourceBundleID: String
    var notes: String = ""

    enum CodingKeys: String, CodingKey {
        case id, title, sortOrder, isEnabled, createdDayKey, weekdaysOnly, weekdayMask
        case createdAt, remindMinutes, deletedAt
        case projectID, tagIDs, isImportant, isUrgent, sourceBundleID, notes
    }

    init(
        id: UUID,
        title: String,
        sortOrder: Int,
        isEnabled: Bool,
        createdDayKey: String,
        weekdaysOnly: Bool = false,
        weekdayMask: Int? = nil,
        createdAt: Date? = nil,
        remindMinutes: Int? = nil,
        deletedAt: Date? = nil,
        projectID: UUID? = nil,
        tagIDs: String = "",
        isImportant: Bool = false,
        isUrgent: Bool = false,
        sourceBundleID: String = "",
        notes: String = ""
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
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        title = try box.decode(String.self, forKey: .title)
        sortOrder = try box.decode(Int.self, forKey: .sortOrder)
        isEnabled = try box.decode(Bool.self, forKey: .isEnabled)
        createdDayKey = try box.decode(String.self, forKey: .createdDayKey)
        let storedMask = try box.decodeIfPresent(Int.self, forKey: .weekdayMask)
        let flag = try box.decodeIfPresent(Bool.self, forKey: .weekdaysOnly) ?? false
        let mask = WeekdayMask.resolved(stored: storedMask, weekdaysOnly: flag)
        weekdayMask = mask
        weekdaysOnly = WeekdayMask.isWorkdays(mask)
        createdAt = try box.decodeIfPresent(Date.self, forKey: .createdAt)
        remindMinutes = RemindMinutes.clamped(try box.decodeIfPresent(Int.self, forKey: .remindMinutes))
        deletedAt = try box.decodeIfPresent(Date.self, forKey: .deletedAt)
        projectID = try box.decodeIfPresent(UUID.self, forKey: .projectID)
        tagIDs = try box.decodeIfPresent(String.self, forKey: .tagIDs) ?? ""
        isImportant = try box.decodeIfPresent(Bool.self, forKey: .isImportant) ?? false
        isUrgent = try box.decodeIfPresent(Bool.self, forKey: .isUrgent) ?? false
        sourceBundleID = try box.decodeIfPresent(String.self, forKey: .sourceBundleID) ?? ""
        notes = try box.decodeIfPresent(String.self, forKey: .notes) ?? ""
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
    var projectID: UUID?
    var tagIDs: String
    var isImportant: Bool
    var isUrgent: Bool
    var sourceBundleID: String
    var calendarEventID: String
    var notes: String = ""
    var subtasks: [ExportedSubtask] = []

    enum CodingKeys: String, CodingKey {
        case id, title, isDone, dayKey, createdAt, remindMinutes, deletedAt
        case projectID, tagIDs, isImportant, isUrgent, sourceBundleID, calendarEventID
        case notes, subtasks
    }

    init(
        id: UUID,
        title: String,
        isDone: Bool,
        dayKey: String,
        createdAt: Date,
        remindMinutes: Int? = nil,
        deletedAt: Date? = nil,
        projectID: UUID? = nil,
        tagIDs: String = "",
        isImportant: Bool = false,
        isUrgent: Bool = false,
        sourceBundleID: String = "",
        calendarEventID: String = "",
        notes: String = "",
        subtasks: [ExportedSubtask] = []
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
        self.subtasks = subtasks
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
        projectID = try box.decodeIfPresent(UUID.self, forKey: .projectID)
        tagIDs = try box.decodeIfPresent(String.self, forKey: .tagIDs) ?? ""
        isImportant = try box.decodeIfPresent(Bool.self, forKey: .isImportant) ?? false
        isUrgent = try box.decodeIfPresent(Bool.self, forKey: .isUrgent) ?? false
        sourceBundleID = try box.decodeIfPresent(String.self, forKey: .sourceBundleID) ?? ""
        calendarEventID = try box.decodeIfPresent(String.self, forKey: .calendarEventID) ?? ""
        notes = try box.decodeIfPresent(String.self, forKey: .notes) ?? ""
        subtasks = try box.decodeIfPresent([ExportedSubtask].self, forKey: .subtasks) ?? []
    }
}

struct ExportedDiary: Codable, Equatable {
    var id: UUID
    var text: String
    var dayKey: String
    var createdAt: Date
    var deletedAt: Date? = nil
    var tagIDs: String = ""
    var isPinned: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, text, dayKey, createdAt, deletedAt, tagIDs, isPinned
    }

    init(
        id: UUID,
        text: String,
        dayKey: String,
        createdAt: Date,
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

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        text = try box.decode(String.self, forKey: .text)
        dayKey = try box.decode(String.self, forKey: .dayKey)
        createdAt = try box.decode(Date.self, forKey: .createdAt)
        deletedAt = try box.decodeIfPresent(Date.self, forKey: .deletedAt)
        tagIDs = try box.decodeIfPresent(String.self, forKey: .tagIDs) ?? ""
        isPinned = try box.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}
