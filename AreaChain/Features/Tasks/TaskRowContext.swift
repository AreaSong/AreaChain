import Foundation
import SwiftData

struct CatalogChoice: Identifiable, Equatable {
    var id: UUID
    var name: String
}

// MARK: - Task Classify Sub-DTOs

/// 任务优先级标记（重要/紧急）
struct TaskPriorityFlags: Equatable {
    var isImportant: Bool
    var isUrgent: Bool

    init(isImportant: Bool = false, isUrgent: Bool = false) {
        self.isImportant = isImportant
        self.isUrgent = isUrgent
    }
}

/// 任务分类目录绑定（项目/标签/来源）
struct TaskCatalogBinding {
    var projectID: UUID?
    var tagIDs: String
    var projects: [CatalogChoice]
    var tags: [CatalogChoice]
    var sourceLabel: String?

    init(
        projectID: UUID? = nil,
        tagIDs: String = "",
        projects: [CatalogChoice] = [],
        tags: [CatalogChoice] = [],
        sourceLabel: String? = nil
    ) {
        self.projectID = projectID
        self.tagIDs = tagIDs
        self.projects = projects
        self.tags = tags
        self.sourceLabel = sourceLabel
    }
}

/// 任务分类交互回调
struct TaskClassifyActions {
    var onProject: (UUID?) -> Void
    var onToggleTag: (UUID) -> Void
    var onImportant: (Bool) -> Void
    var onUrgent: (Bool) -> Void

    init(
        onProject: @escaping (UUID?) -> Void,
        onToggleTag: @escaping (UUID) -> Void,
        onImportant: @escaping (Bool) -> Void,
        onUrgent: @escaping (Bool) -> Void
    ) {
        self.onProject = onProject
        self.onToggleTag = onToggleTag
        self.onImportant = onImportant
        self.onUrgent = onUrgent
    }
}

/// 任务行分类归属上下文（<= 3 参数）
struct TaskClassifyContext {
    var priority: TaskPriorityFlags
    var catalog: TaskCatalogBinding
    var actions: TaskClassifyActions

    init(
        priority: TaskPriorityFlags = TaskPriorityFlags(),
        catalog: TaskCatalogBinding = TaskCatalogBinding(),
        actions: TaskClassifyActions
    ) {
        self.priority = priority
        self.catalog = catalog
        self.actions = actions
    }

    // MARK: - Forwarding for ergonomic access and zero-breakage compatibility
    var isImportant: Bool { priority.isImportant }
    var isUrgent: Bool { priority.isUrgent }
    var projectID: UUID? { catalog.projectID }
    var tagIDs: String { catalog.tagIDs }
    var projects: [CatalogChoice] { catalog.projects }
    var tags: [CatalogChoice] { catalog.tags }
    var sourceLabel: String? { catalog.sourceLabel }
    var onProject: (UUID?) -> Void { actions.onProject }
    var onToggleTag: (UUID) -> Void { actions.onToggleTag }
    var onImportant: (Bool) -> Void { actions.onImportant }
    var onUrgent: (Bool) -> Void { actions.onUrgent }
}

struct TaskAttachmentContext {
    var items: [AttachmentRef]
    var onPickFile: () -> Void
    var onPaste: () -> Void
    var onCaptureScreen: (() -> Void)? = nil
}

@MainActor
enum CatalogChoices {
    static func projects(_ items: [ProjectItem]) -> [CatalogChoice] {
        ProjectTree.outline(items).map {
            CatalogChoice(id: $0.id, name: ProjectTree.pathLabel($0.id, in: items))
        }
    }

    static func tags(_ items: [TagItem], attachedIDs: String = "") -> [CatalogChoice] {
        Catalog.taskPickerTags(items, attachedIDs: attachedIDs).map {
            CatalogChoice(id: $0.id, name: $0.name)
        }
    }

    static func attachments(_ ownerID: UUID, in items: [AttachmentItem]) -> [AttachmentRef] {
        Catalog.liveAttachments(for: ownerID, in: items).map {
            AttachmentRef(id: $0.id, filename: $0.filename)
        }
    }

    static func classify(
        for routine: DailyRoutine,
        projects: [ProjectItem],
        tags: [TagItem]
    ) -> TaskClassifyContext {
        let priority = TaskPriorityFlags(
            isImportant: routine.isImportant,
            isUrgent: routine.isUrgent
        )
        let catalog = TaskCatalogBinding(
            projectID: routine.projectID,
            tagIDs: routine.tagIDs,
            projects: Self.projects(projects),
            tags: Self.tags(tags, attachedIDs: routine.tagIDs),
            sourceLabel: routine.sourceBundleID.isEmpty ? nil : BundleDisplay.name(for: routine.sourceBundleID)
        )
        let actions = TaskClassifyActions(
            onProject: { id in DayBoardMutations.persist { routine.projectID = id } },
            onToggleTag: { id in DayBoardMutations.persist { routine.tagIDs = TagIDList.toggling(routine.tagIDs, id) } },
            onImportant: { value in DayBoardMutations.persist { routine.isImportant = value } },
            onUrgent: { value in DayBoardMutations.persist { routine.isUrgent = value } }
        )
        return TaskClassifyContext(priority: priority, catalog: catalog, actions: actions)
    }

    static func classify(
        for todo: TodoItem,
        projects: [ProjectItem],
        tags: [TagItem]
    ) -> TaskClassifyContext {
        let priority = TaskPriorityFlags(
            isImportant: todo.isImportant,
            isUrgent: todo.isUrgent
        )
        let catalog = TaskCatalogBinding(
            projectID: todo.projectID,
            tagIDs: todo.tagIDs,
            projects: Self.projects(projects),
            tags: Self.tags(tags, attachedIDs: todo.tagIDs),
            sourceLabel: todo.sourceBundleID.isEmpty ? nil : BundleDisplay.name(for: todo.sourceBundleID)
        )
        let actions = TaskClassifyActions(
            onProject: { id in DayBoardMutations.persist { todo.projectID = id } },
            onToggleTag: { id in DayBoardMutations.persist { todo.tagIDs = TagIDList.toggling(todo.tagIDs, id) } },
            onImportant: { value in DayBoardMutations.persist { todo.isImportant = value } },
            onUrgent: { value in DayBoardMutations.persist { todo.isUrgent = value } }
        )
        return TaskClassifyContext(priority: priority, catalog: catalog, actions: actions)
    }

    static func attachments(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        items: [AttachmentItem],
        context: ModelContext
    ) -> TaskAttachmentContext {
        TaskAttachmentContext(
            items: attachments(ownerID, in: items),
            onPickFile: {
                AttachmentActions.pickImage(ownerKind: ownerKind, ownerID: ownerID, context: context)
            },
            onPaste: {
                _ = AttachmentActions.pasteImage(ownerKind: ownerKind, ownerID: ownerID, context: context)
            },
            onCaptureScreen: {
                AttachmentActions.captureScreen(ownerKind: ownerKind, ownerID: ownerID, context: context)
            }
        )
    }
}

// MARK: - Task Catalog Context

/// 任务行目录与持久化上下文依赖（解耦各 Caller 重复传递 projects/tags/attachments/modelContext）
struct TaskCatalogContext {
    var projects: [ProjectItem]
    var tags: [TagItem]
    var attachments: [AttachmentItem]
    var context: ModelContext

    init(
        projects: [ProjectItem],
        tags: [TagItem],
        attachments: [AttachmentItem],
        context: ModelContext
    ) {
        self.projects = projects
        self.tags = tags
        self.attachments = attachments
        self.context = context
    }

    @MainActor
    func classify(for routine: DailyRoutine) -> TaskClassifyContext {
        CatalogChoices.classify(for: routine, projects: projects, tags: tags)
    }

    @MainActor
    func classify(for todo: TodoItem) -> TaskClassifyContext {
        CatalogChoices.classify(for: todo, projects: projects, tags: tags)
    }

    @MainActor
    func attachments(ownerKind: AttachmentOwner, ownerID: UUID) -> TaskAttachmentContext {
        CatalogChoices.attachments(ownerKind: ownerKind, ownerID: ownerID, items: attachments, context: context)
    }
}

// MARK: - Selection State

/// 任务行选中与就地编辑状态
struct TaskRowSelectionState: Equatable {
    var isSelected: Bool
    var isExternalEditing: Bool

    init(
        isSelected: Bool = false,
        isExternalEditing: Bool = false
    ) {
        self.isSelected = isSelected
        self.isExternalEditing = isExternalEditing
    }
}

// MARK: - Todo Row DTOs

/// 待办任务行动作闭包
struct TodoRowActions {
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onEndEditing: (() -> Void)?

    init(
        onSelect: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onEndEditing: (() -> Void)? = nil
    ) {
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onEndEditing = onEndEditing
    }
}

/// 待办任务行呈现配置
struct TodoRowDisplayOptions {
    var isDone: Bool
    var selection: TaskRowSelectionState
    var dragPayload: String?
    var note: String?
    var includeSubtasks: Bool

    init(
        isDone: Bool,
        selection: TaskRowSelectionState = TaskRowSelectionState(),
        dragPayload: String? = nil,
        note: String? = nil,
        includeSubtasks: Bool = true
    ) {
        self.isDone = isDone
        self.selection = selection
        self.dragPayload = dragPayload
        self.note = note
        self.includeSubtasks = includeSubtasks
    }

    init(
        isDone: Bool,
        isSelected: Bool,
        note: String? = nil,
        includeSubtasks: Bool = true
    ) {
        self.isDone = isDone
        self.selection = TaskRowSelectionState(isSelected: isSelected)
        self.dragPayload = nil
        self.note = note
        self.includeSubtasks = includeSubtasks
    }
}

/// 待办任务行构造上下文
struct TodoRowContext {
    var todo: TodoItem
    var todayKey: String
    var catalogs: TaskCatalogContext
    var display: TodoRowDisplayOptions
    var actions: TodoRowActions

    init(
        todo: TodoItem,
        todayKey: String,
        catalogs: TaskCatalogContext,
        display: TodoRowDisplayOptions,
        actions: TodoRowActions
    ) {
        self.todo = todo
        self.todayKey = todayKey
        self.catalogs = catalogs
        self.display = display
        self.actions = actions
    }
}

// MARK: - Routine Row DTOs

/// 常驻习惯日程与打卡上下文
struct RoutineScheduleContext {
    var todayKey: String
    var checkDayKey: String
    var checks: [RoutineCheck]
    var locale: Locale

    init(
        todayKey: String,
        checkDayKey: String,
        checks: [RoutineCheck],
        locale: Locale = .current
    ) {
        self.todayKey = todayKey
        self.checkDayKey = checkDayKey
        self.checks = checks
        self.locale = locale
    }
}

/// 常驻习惯行动作闭包
struct RoutineRowActions {
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onToggle: (() -> Void)?
    var onSkip: (() -> Void)?
    var onEndEditing: (() -> Void)?

    init(
        onSelect: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onToggle: (() -> Void)? = nil,
        onSkip: (() -> Void)? = nil,
        onEndEditing: (() -> Void)? = nil
    ) {
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onToggle = onToggle
        self.onSkip = onSkip
        self.onEndEditing = onEndEditing
    }
}

/// 常驻习惯行呈现配置
struct RoutineRowDisplayOptions {
    var isDone: Bool
    var selection: TaskRowSelectionState
    var note: String?
    var usesDefaultNote: Bool

    init(
        isDone: Bool,
        selection: TaskRowSelectionState = TaskRowSelectionState(),
        note: String? = nil,
        usesDefaultNote: Bool = true
    ) {
        self.isDone = isDone
        self.selection = selection
        self.note = note
        self.usesDefaultNote = usesDefaultNote
    }

    init(
        isDone: Bool,
        isSelected: Bool,
        note: String? = nil,
        usesDefaultNote: Bool = true
    ) {
        self.isDone = isDone
        self.selection = TaskRowSelectionState(isSelected: isSelected)
        self.note = note
        self.usesDefaultNote = usesDefaultNote
    }
}

/// 常驻习惯行构造上下文
struct RoutineRowContext {
    var routine: DailyRoutine
    var schedule: RoutineScheduleContext
    var catalogs: TaskCatalogContext
    var display: RoutineRowDisplayOptions
    var actions: RoutineRowActions

    init(
        routine: DailyRoutine,
        schedule: RoutineScheduleContext,
        catalogs: TaskCatalogContext,
        display: RoutineRowDisplayOptions,
        actions: RoutineRowActions
    ) {
        self.routine = routine
        self.schedule = schedule
        self.catalogs = catalogs
        self.display = display
        self.actions = actions
    }
}

// MARK: - Leftover Fallback Row DTOs

/// 昨日未完成兜底行动作闭包
struct LeftoverRowActions {
    var onToggle: () -> Void
    var onSelect: () -> Void
    var onMoveToDay: ((String) -> Void)?

    init(
        onToggle: @escaping () -> Void,
        onSelect: @escaping () -> Void,
        onMoveToDay: ((String) -> Void)? = nil
    ) {
        self.onToggle = onToggle
        self.onSelect = onSelect
        self.onMoveToDay = onMoveToDay
    }
}

/// 昨日未完成兜底行构造上下文
struct LeftoverRowContext {
    var item: UnfinishedItem
    var todayKey: String
    var yesterdayKey: String
    var isSelected: Bool
    var actions: LeftoverRowActions

    init(
        item: UnfinishedItem,
        todayKey: String,
        yesterdayKey: String,
        isSelected: Bool,
        actions: LeftoverRowActions
    ) {
        self.item = item
        self.todayKey = todayKey
        self.yesterdayKey = yesterdayKey
        self.isSelected = isSelected
        self.actions = actions
    }
}
