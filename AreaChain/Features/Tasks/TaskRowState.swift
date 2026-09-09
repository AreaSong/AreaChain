import Foundation

/// 任务行纯数据只读快照：用于 TaskRow 的高效解耦渲染与预览
struct TaskRowState: Identifiable, Equatable {
    var id: UUID
    var title: String
    var isDone: Bool
    var isResident: Bool
    var note: String?
    var streak: Int?
    var remindMinutes: Int?
    var todayKey: String?
    var currentDayKey: String?
    var weekdaysOnly: Bool?
    var isImportant: Bool
    var isUrgent: Bool
    var classify: TaskClassifyContext?
    var attachments: TaskAttachmentContext?
    var notes: String?
    var subtasks: [SubtaskSnapshot]
    var dragPayload: String?
    var isSelected: Bool
    var isExternalEditing: Bool

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool,
        isResident: Bool = false,
        note: String? = nil,
        streak: Int? = nil,
        remindMinutes: Int? = nil,
        todayKey: String? = nil,
        currentDayKey: String? = nil,
        weekdaysOnly: Bool? = nil,
        isImportant: Bool = false,
        isUrgent: Bool = false,
        classify: TaskClassifyContext? = nil,
        attachments: TaskAttachmentContext? = nil,
        notes: String? = nil,
        subtasks: [SubtaskSnapshot] = [],
        dragPayload: String? = nil,
        isSelected: Bool = false,
        isExternalEditing: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.isResident = isResident
        self.note = note
        self.streak = streak
        self.remindMinutes = remindMinutes
        self.todayKey = todayKey
        self.currentDayKey = currentDayKey
        self.weekdaysOnly = weekdaysOnly
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.classify = classify
        self.attachments = attachments
        self.notes = notes
        self.subtasks = subtasks
        self.dragPayload = dragPayload
        self.isSelected = isSelected
        self.isExternalEditing = isExternalEditing
    }

    static func == (lhs: TaskRowState, rhs: TaskRowState) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.isDone == rhs.isDone &&
        lhs.isResident == rhs.isResident &&
        lhs.note == rhs.note &&
        lhs.streak == rhs.streak &&
        lhs.remindMinutes == rhs.remindMinutes &&
        lhs.todayKey == rhs.todayKey &&
        lhs.currentDayKey == rhs.currentDayKey &&
        lhs.weekdaysOnly == rhs.weekdaysOnly &&
        lhs.isImportant == rhs.isImportant &&
        lhs.isUrgent == rhs.isUrgent &&
        lhs.notes == rhs.notes &&
        lhs.subtasks == rhs.subtasks &&
        lhs.dragPayload == rhs.dragPayload &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isExternalEditing == rhs.isExternalEditing
    }
}

/// 任务行统一交互动作枚举
enum TaskRowAction {
    case toggleDone
    case select
    case editTitle(String)
    case endEditing
    case delete
    case skip
    case moveToDay(String)
    case setRemindMinutes(Int?)
    case setWeekdaysOnly(Bool)
    case setEnabled(Bool)
    case toggleSubtask(UUID)
}
