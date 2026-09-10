import Foundation

// MARK: - Task Row Sub-DTOs

/// 任务行身份与核心状态（<= 5 参数）
struct TaskRowIdentityState: Equatable {
    var id: UUID
    var title: String
    var isDone: Bool
    var isResident: Bool
    var priority: TaskPriorityFlags

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        isResident: Bool = false,
        priority: TaskPriorityFlags = TaskPriorityFlags()
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.isResident = isResident
        self.priority = priority
    }

    var isImportant: Bool {
        get { priority.isImportant }
        set { priority.isImportant = newValue }
    }

    var isUrgent: Bool {
        get { priority.isUrgent }
        set { priority.isUrgent = newValue }
    }
}

/// 任务行日期与习惯打卡状态（<= 5 参数）
struct TaskRowScheduleState: Equatable {
    var todayKey: String?
    var currentDayKey: String?
    var remindMinutes: Int?
    var weekdaysOnly: Bool?
    var streak: Int?

    init(
        todayKey: String? = nil,
        currentDayKey: String? = nil,
        remindMinutes: Int? = nil,
        weekdaysOnly: Bool? = nil,
        streak: Int? = nil
    ) {
        self.todayKey = todayKey
        self.currentDayKey = currentDayKey
        self.remindMinutes = remindMinutes
        self.weekdaysOnly = weekdaysOnly
        self.streak = streak
    }
}

/// 任务行内容与上下文（<= 5 参数）
struct TaskRowContentState: Equatable {
    var note: String?
    var notes: String?
    var subtasks: [SubtaskSnapshot]
    var attachments: TaskAttachmentContext?
    var classify: TaskClassifyContext?

    init(
        note: String? = nil,
        notes: String? = nil,
        subtasks: [SubtaskSnapshot] = [],
        attachments: TaskAttachmentContext? = nil,
        classify: TaskClassifyContext? = nil
    ) {
        self.note = note
        self.notes = notes
        self.subtasks = subtasks
        self.attachments = attachments
        self.classify = classify
    }

    static func == (lhs: TaskRowContentState, rhs: TaskRowContentState) -> Bool {
        lhs.note == rhs.note &&
        lhs.notes == rhs.notes &&
        lhs.subtasks == rhs.subtasks
    }
}

/// 任务行交互状态（<= 5 参数）
struct TaskRowInteractionState: Equatable {
    var selection: TaskRowSelectionState
    var dragPayload: String?
    var canSetRemind: Bool
    var canSkip: Bool
    var isEnabled: Bool?

    init(
        selection: TaskRowSelectionState = TaskRowSelectionState(),
        dragPayload: String? = nil,
        canSetRemind: Bool = false,
        canSkip: Bool = false,
        isEnabled: Bool? = nil
    ) {
        self.selection = selection
        self.dragPayload = dragPayload
        self.canSetRemind = canSetRemind
        self.canSkip = canSkip
        self.isEnabled = isEnabled
    }

    var isSelected: Bool {
        get { selection.isSelected }
        set { selection.isSelected = newValue }
    }

    var isExternalEditing: Bool {
        get { selection.isExternalEditing }
        set { selection.isExternalEditing = newValue }
    }
}

// MARK: - Task Row State

/// 任务行纯数据只读快照：用于 TaskRow 的高效解耦渲染与预览（<= 4 参数构造器）
struct TaskRowState: Identifiable, Equatable {
    var identity: TaskRowIdentityState
    var schedule: TaskRowScheduleState
    var content: TaskRowContentState
    var interaction: TaskRowInteractionState

    init(
        identity: TaskRowIdentityState,
        schedule: TaskRowScheduleState = TaskRowScheduleState(),
        content: TaskRowContentState = TaskRowContentState(),
        interaction: TaskRowInteractionState = TaskRowInteractionState()
    ) {
        self.identity = identity
        self.schedule = schedule
        self.content = content
        self.interaction = interaction
    }

    // MARK: - Identity Forwarding
    var id: UUID {
        get { identity.id }
        set { identity.id = newValue }
    }
    var title: String {
        get { identity.title }
        set { identity.title = newValue }
    }
    var isDone: Bool {
        get { identity.isDone }
        set { identity.isDone = newValue }
    }
    var isResident: Bool {
        get { identity.isResident }
        set { identity.isResident = newValue }
    }
    var isImportant: Bool {
        get { identity.isImportant }
        set { identity.isImportant = newValue }
    }
    var isUrgent: Bool {
        get { identity.isUrgent }
        set { identity.isUrgent = newValue }
    }

    // MARK: - Schedule Forwarding
    var todayKey: String? {
        get { schedule.todayKey }
        set { schedule.todayKey = newValue }
    }
    var currentDayKey: String? {
        get { schedule.currentDayKey }
        set { schedule.currentDayKey = newValue }
    }
    var remindMinutes: Int? {
        get { schedule.remindMinutes }
        set { schedule.remindMinutes = newValue }
    }
    var weekdaysOnly: Bool? {
        get { schedule.weekdaysOnly }
        set { schedule.weekdaysOnly = newValue }
    }
    var streak: Int? {
        get { schedule.streak }
        set { schedule.streak = newValue }
    }

    // MARK: - Content Forwarding
    var note: String? {
        get { content.note }
        set { content.note = newValue }
    }
    var notes: String? {
        get { content.notes }
        set { content.notes = newValue }
    }
    var subtasks: [SubtaskSnapshot] {
        get { content.subtasks }
        set { content.subtasks = newValue }
    }
    var attachments: TaskAttachmentContext? {
        get { content.attachments }
        set { content.attachments = newValue }
    }
    var classify: TaskClassifyContext? {
        get { content.classify }
        set { content.classify = newValue }
    }

    // MARK: - Interaction Forwarding
    var selection: TaskRowSelectionState {
        get { interaction.selection }
        set { interaction.selection = newValue }
    }
    var isSelected: Bool {
        get { interaction.selection.isSelected }
        set { interaction.selection.isSelected = newValue }
    }
    var isExternalEditing: Bool {
        get { interaction.selection.isExternalEditing }
        set { interaction.selection.isExternalEditing = newValue }
    }
    var dragPayload: String? {
        get { interaction.dragPayload }
        set { interaction.dragPayload = newValue }
    }
    var canSetRemind: Bool {
        get { interaction.canSetRemind }
        set { interaction.canSetRemind = newValue }
    }
    var canSkip: Bool {
        get { interaction.canSkip }
        set { interaction.canSkip = newValue }
    }
    var isEnabled: Bool? {
        get { interaction.isEnabled }
        set { interaction.isEnabled = newValue }
    }

    // MARK: - Equatable
    static func == (lhs: TaskRowState, rhs: TaskRowState) -> Bool {
        lhs.identity == rhs.identity &&
        lhs.schedule == rhs.schedule &&
        lhs.content == rhs.content &&
        lhs.interaction == rhs.interaction
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
