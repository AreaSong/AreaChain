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

/// 任务分类目录绑定（标签/来源）
struct TaskCatalogBinding {
    var tagIDs: String
    var tags: [CatalogChoice]
    var sourceLabel: String?

    init(
        tagIDs: String = "",
        tags: [CatalogChoice] = [],
        sourceLabel: String? = nil
    ) {
        self.tagIDs = tagIDs
        self.tags = tags
        self.sourceLabel = sourceLabel
    }
}

/// 任务分类交互回调
struct TaskClassifyActions {
    var onToggleTag: (UUID) -> Void
    var onImportant: (Bool) -> Void
    var onUrgent: (Bool) -> Void

    init(
        onToggleTag: @escaping (UUID) -> Void,
        onImportant: @escaping (Bool) -> Void,
        onUrgent: @escaping (Bool) -> Void
    ) {
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
    var tagIDs: String { catalog.tagIDs }
    var tags: [CatalogChoice] { catalog.tags }
    var sourceLabel: String? { catalog.sourceLabel }
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
    static func tags(_ items: [TagItem], attachedIDs: String = "") -> [CatalogChoice] {
        Catalog.taskPickerTags(items, attachedIDs: attachedIDs).map {
            CatalogChoice(id: $0.id, name: $0.name)
        }
    }

    static func attachments(_ ownerID: UUID, in items: [AttachmentItem], ownerKind: AttachmentOwner? = nil) -> [AttachmentRef] {
        Catalog.liveAttachments(for: ownerID, in: items, ownerKind: ownerKind).map {
            $0.reference
        }
    }

    static func classify(
        for routine: DailyRoutine,
        tags: [TagItem]
    ) -> TaskClassifyContext {
        let priority = TaskPriorityFlags(
            isImportant: routine.isImportant,
            isUrgent: routine.isUrgent
        )
        let catalog = TaskCatalogBinding(
            tagIDs: routine.tagIDs,
            tags: Self.tags(tags, attachedIDs: routine.tagIDs),
            sourceLabel: routine.sourceBundleID.isEmpty ? nil : BundleDisplay.name(for: routine.sourceBundleID)
        )
        let actions = TaskClassifyActions(
            onToggleTag: { DayBoardMutations.toggleTag(for: routine, tagID: $0) },
            onImportant: { value in
                DayBoardMutations.applyQuadrant(QuadrantSlot.of(important: value, urgent: routine.isUrgent), to: routine)
            },
            onUrgent: { value in
                DayBoardMutations.applyQuadrant(QuadrantSlot.of(important: routine.isImportant, urgent: value), to: routine)
            }
        )
        return TaskClassifyContext(priority: priority, catalog: catalog, actions: actions)
    }

    static func classify(
        for todo: TodoItem,
        tags: [TagItem]
    ) -> TaskClassifyContext {
        let priority = TaskPriorityFlags(
            isImportant: todo.isImportant,
            isUrgent: todo.isUrgent
        )
        let catalog = TaskCatalogBinding(
            tagIDs: todo.tagIDs,
            tags: Self.tags(tags, attachedIDs: todo.tagIDs),
            sourceLabel: todo.sourceBundleID.isEmpty ? nil : BundleDisplay.name(for: todo.sourceBundleID)
        )
        let actions = TaskClassifyActions(
            onToggleTag: { DayBoardMutations.toggleTag(for: todo, tagID: $0) },
            onImportant: { value in
                DayBoardMutations.applyQuadrant(QuadrantSlot.of(important: value, urgent: todo.isUrgent), to: todo)
            },
            onUrgent: { value in
                DayBoardMutations.applyQuadrant(QuadrantSlot.of(important: todo.isImportant, urgent: value), to: todo)
            }
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
            items: attachments(ownerID, in: items, ownerKind: ownerKind),
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

/// 任务行目录与持久化上下文依赖（解耦各调用方重复传递 tags/attachments/modelContext）
struct TaskCatalogContext {
    var tags: [TagItem]
    var attachments: [AttachmentItem]
    var context: ModelContext

    init(
        tags: [TagItem],
        attachments: [AttachmentItem],
        context: ModelContext
    ) {
        self.tags = tags
        self.attachments = attachments
        self.context = context
    }

    @MainActor
    func classify(for routine: DailyRoutine) -> TaskClassifyContext {
        CatalogChoices.classify(for: routine, tags: tags)
    }

    @MainActor
    func classify(for todo: TodoItem) -> TaskClassifyContext {
        CatalogChoices.classify(for: todo, tags: tags)
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
    var onSelect: (TaskSelectionModifiers) -> Void
    var onDelete: () -> Void
    var onToggle: (() -> Void)?
    var onEndEditing: (() -> Void)?

    init(
        onSelect: @escaping (TaskSelectionModifiers) -> Void,
        onDelete: @escaping () -> Void,
        onToggle: (() -> Void)? = nil,
        onEndEditing: (() -> Void)? = nil
    ) {
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onToggle = onToggle
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
    var visibleSubtaskIDs: Set<UUID>?

    init(
        isDone: Bool,
        selection: TaskRowSelectionState = TaskRowSelectionState(),
        dragPayload: String? = nil,
        note: String? = nil,
        includeSubtasks: Bool = true,
        visibleSubtaskIDs: Set<UUID>? = nil
    ) {
        self.isDone = isDone
        self.selection = selection
        self.dragPayload = dragPayload
        self.note = note
        self.includeSubtasks = includeSubtasks
        self.visibleSubtaskIDs = visibleSubtaskIDs
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
        self.visibleSubtaskIDs = nil
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
    var onSelect: (TaskSelectionModifiers) -> Void
    var onDelete: () -> Void
    var onToggle: (() -> Void)?
    var onSkip: (() -> Void)?
    var onEndEditing: (() -> Void)?

    init(
        onSelect: @escaping (TaskSelectionModifiers) -> Void,
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
    var allowsCompletion: Bool

    init(
        isDone: Bool,
        selection: TaskRowSelectionState = TaskRowSelectionState(),
        note: String? = nil,
        usesDefaultNote: Bool = true,
        allowsCompletion: Bool = true
    ) {
        self.isDone = isDone
        self.selection = selection
        self.note = note
        self.usesDefaultNote = usesDefaultNote
        self.allowsCompletion = allowsCompletion
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
        self.allowsCompletion = true
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
    var onSelect: (TaskSelectionModifiers) -> Void
    var onMoveToDay: ((String) -> Void)?

    init(
        onToggle: @escaping () -> Void,
        onSelect: @escaping (TaskSelectionModifiers) -> Void,
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
