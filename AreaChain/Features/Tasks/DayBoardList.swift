import AppKit
import SwiftData
import SwiftUI

/// 任务面板焦点与检查器交互配置（<= 5 属性）
struct DayBoardInteraction {
    var focusedTaskID: Binding<UUID?>? = nil
    var highlightedTaskID: UUID? = nil
    var onInspect: ((UUID) -> Void)? = nil
    var onReturnToInput: (() -> Void)? = nil
    var isKeyboardEnabled: () -> Bool = { true }

    init(
        focusedTaskID: Binding<UUID?>? = nil,
        highlightedTaskID: UUID? = nil,
        onInspect: ((UUID) -> Void)? = nil,
        onReturnToInput: (() -> Void)? = nil,
        isKeyboardEnabled: @escaping () -> Bool = { true }
    ) {
        self.focusedTaskID = focusedTaskID
        self.highlightedTaskID = highlightedTaskID
        self.onInspect = onInspect
        self.onReturnToInput = onReturnToInput
        self.isKeyboardEnabled = isKeyboardEnabled
    }
}

/// 日看板配置选项（<= 5 属性）
struct DayBoardListConfig {
    var todayKey: String? = nil
    var filter: BoardFilter = BoardFilter()
    var allowsTodoDrag: Bool = false
    var dayKeyForID: ((UUID) -> String)? = nil
    var interaction: DayBoardInteraction = DayBoardInteraction()

    init(
        todayKey: String? = nil,
        filter: BoardFilter = BoardFilter(),
        allowsTodoDrag: Bool = false,
        dayKeyForID: ((UUID) -> String)? = nil,
        interaction: DayBoardInteraction = DayBoardInteraction()
    ) {
        self.todayKey = todayKey
        self.filter = filter
        self.allowsTodoDrag = allowsTodoDrag
        self.dayKeyForID = dayKeyForID
        self.interaction = interaction
    }

    var focusedTaskID: Binding<UUID?>? { interaction.focusedTaskID }
    var highlightedTaskID: UUID? { interaction.highlightedTaskID }
    var onInspect: ((UUID) -> Void)? { interaction.onInspect }
    var onReturnToInput: (() -> Void)? { interaction.onReturnToInput }
}

struct DayBoardList: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) var locale

    var dayKey: String
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var todos: [TodoItem]
    var config: DayBoardListConfig

    // 兼容现有内部属性与扩展访问
    var todayKey: String { config.todayKey ?? dayKey }
    var filter: BoardFilter { config.filter }
    var allowsTodoDrag: Bool { config.allowsTodoDrag }
    var focusedTaskID: Binding<UUID?>? { config.interaction.focusedTaskID }
    var highlightedTaskID: UUID? { config.interaction.highlightedTaskID }
    var onInspect: ((UUID) -> Void)? { config.interaction.onInspect }
    var onReturnToInput: (() -> Void)? { config.interaction.onReturnToInput }
    var dayKeyForID: ((UUID) -> String)? { config.dayKeyForID }

    init(
        dayKey: String,
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem],
        config: DayBoardListConfig = DayBoardListConfig()
    ) {
        self.dayKey = dayKey
        self.routines = routines
        self.checks = checks
        self.todos = todos
        self.config = config
    }

    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State var showCompleted = false
    @State var taskSelection = TaskSelection()
    @State var pendingTrash: PendingTrash?
    @State var editingTaskID: UUID? = nil
    @State var hostWindow: NSWindow?
    @State var keyMonitor: Any? = nil
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Group {
            if openTodosList.isEmpty && openRoutinesList.isEmpty && doneItemsList.isEmpty {
                DaybookEmptyState(
                    title: filter.isActive ? "empty.filter" : "empty.todos",
                    systemImage: filter.isActive ? "line.3.horizontal.decrease" : "square.and.pencil"
                )
            } else {
                openItemsSection
            }

            if !doneItemsList.isEmpty {
                completedSection
            }
        }
        .focusable()
        .focusEffectDisabled()
        .background(KeyWindowHost { hostWindow = $0 })
        .modifier(DayBoardKeyNavigationModifier(
            interaction: config.interaction,
            onNavigate: { navigateSelection(delta: $0) },
            onToggle: { toggleSelected(id: $0) },
            onDelete: { deleteSelected(id: $0) },
            onInspect: { inspectSelected(id: $0) }
        ))
        .onAppear {
            setupKeyMonitor()
            expandIfHighlighted()
        }
        .onChange(of: highlightedTaskID) { _, _ in
            expandIfHighlighted()
        }
        .onChange(of: focusedTaskID?.wrappedValue) { _, id in
            if let id, taskSelection.ids.contains(id) { return }
            taskSelection.focus(id)
        }
        .onChange(of: orderedVisibleIDs) { _, ids in
            taskSelection.reconcile(with: ids)
        }
        .onDisappear(perform: tearDownKeyMonitor)
        .confirmMoveToTrash($pendingTrash)
        .animation(DaybookMotion.interactive(reduceMotion), value: openTodosList.map(\.id))
        .animation(DaybookMotion.interactive(reduceMotion), value: openRoutinesList.map(\.id))
    }

    func selectTask(_ id: UUID, modifiers: TaskSelectionModifiers = []) {
        revealCompletedIfNeeded(id)
        var selection = taskSelection
        if selection.anchorID == nil && selection.ids.isEmpty {
            selection.focus(focusedTaskID?.wrappedValue ?? highlightedTaskID)
        }
        let visibleIDs = orderedVisibleIDs
        selection.select(id, in: visibleIDs, modifiers: modifiers)
        taskSelection = selection
        focusedTaskID?.wrappedValue = selection.ids.contains(id)
            ? id : visibleIDs.first { selection.ids.contains($0) }
        BoardSelection.shared.inspectBoard(dayKey)
        if modifiers.isEmpty { onInspect?(id) }
    }

    func focusTask(_ id: UUID?) {
        taskSelection.focus(id)
        focusedTaskID?.wrappedValue = id
    }

    func expandIfHighlighted() {
        if let highlightedTaskID {
            revealCompletedIfNeeded(highlightedTaskID)
        }
        if let focused = focusedTaskID?.wrappedValue {
            revealCompletedIfNeeded(focused)
        }
    }

    func revealCompletedIfNeeded(_ id: UUID) {
        if doneItemsList.contains(where: { $0.id == id }) {
            showCompleted = true
        }
    }

    private func isRowSelected(_ id: UUID) -> Bool {
        if taskSelection.anchorID != nil || !taskSelection.ids.isEmpty {
            return taskSelection.ids.contains(id)
        }
        return focusedTaskID?.wrappedValue == id || highlightedTaskID == id
    }

    private var snapshots: ([RoutineSnapshot], [CheckSnapshot], [TodoSnapshot]) {
        (routines.map(\.snapshot), checks.compactMap(\.snapshot), todos.map(\.snapshot))
    }

    var openTodosList: [TodoItem] {
        filteredTodos(openTodos)
    }

    var openRoutinesList: [DailyRoutine] {
        filteredRoutines(openRoutines)
    }

    var doneItemsList: [BoardRow] {
        sortedRows(filtered(doneRoutines.map(BoardRow.resident) + doneTodos.map(BoardRow.todo)))
    }

    private var openRoutines: [DailyRoutine] {
        let ids = Set(DayBoardLogic.openRoutines(routines: snapshots.0, checks: snapshots.1, dayKey: dayKey).map(\.id))
        let items = routines.filter { ids.contains($0.id) }
        return items.sorted {
            Classification.precedes(
                BoardSortKey(isImportant: $0.isImportant, isUrgent: $0.isUrgent, remindMinutes: $0.remindMinutes, createdAt: $0.createdAt),
                BoardSortKey(isImportant: $1.isImportant, isUrgent: $1.isUrgent, remindMinutes: $1.remindMinutes, createdAt: $1.createdAt)
            )
        }
    }

    private var doneRoutines: [DailyRoutine] {
        let ids = Set(
            DayBoardLogic.completedRoutines(routines: snapshots.0, checks: snapshots.1, dayKey: dayKey).map(\.id)
        )
        return routines.filter { ids.contains($0.id) }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var openTodos: [TodoItem] {
        let ids = Set(DayBoardLogic.openTodos(todos: snapshots.2, dayKey: dayKey).map(\.id))
        let items = todos.filter { ids.contains($0.id) }
        return items.sorted {
            Classification.precedes(
                BoardSortKey(isImportant: $0.isImportant, isUrgent: $0.isUrgent, remindMinutes: $0.remindMinutes, createdAt: $0.createdAt),
                BoardSortKey(isImportant: $1.isImportant, isUrgent: $1.isUrgent, remindMinutes: $1.remindMinutes, createdAt: $1.createdAt)
            )
        }
    }

    private var doneTodos: [TodoItem] {
        let ids = Set(DayBoardLogic.completedTodos(todos: snapshots.2, dayKey: dayKey).map(\.id))
        return todos.filter { ids.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
    }

    private func filteredTodos(_ list: [TodoItem]) -> [TodoItem] {
        guard filter.isActive else { return list }
        return list.filter {
            Classification.matches($0.classifyBits, filter: filter, projectIDs: allowedProjects)
        }
    }

    private func filteredRoutines(_ list: [DailyRoutine]) -> [DailyRoutine] {
        guard filter.isActive else { return list }
        return list.filter {
            Classification.matches($0.classifyBits, filter: filter, projectIDs: allowedProjects)
        }
    }

    private func filtered(_ rows: [BoardRow]) -> [BoardRow] {
        guard filter.isActive else { return rows }
        return rows.filter { row in
            switch row {
            case .resident(let routine):
                Classification.matches(routine.classifyBits, filter: filter, projectIDs: allowedProjects)
            case .todo(let todo):
                Classification.matches(todo.classifyBits, filter: filter, projectIDs: allowedProjects)
            }
        }
    }

    private var allowedProjects: Set<UUID>? {
        filter.projectID.map { ProjectTree.subtreeIDs(root: $0, in: projects) }
    }

    private func sortedRows(_ rows: [BoardRow]) -> [BoardRow] {
        rows.sorted { Classification.precedes($0.boardSortKey, $1.boardSortKey) }
    }

    @ViewBuilder
    func dayRow(_ row: BoardRow, isDone: Bool) -> some View {
        switch row {
        case .resident(let routine):
            residentRow(routine, isDone: isDone)
        case .todo(let todo):
            todoRow(todo, isDone: isDone)
        }
    }

    private var catalogContext: TaskCatalogContext {
        TaskCatalogContext(
            projects: projects,
            tags: tags,
            attachments: attachments,
            context: modelContext
        )
    }

    private func rowSelection(for id: UUID) -> TaskRowSelectionState {
        TaskRowSelectionState(
            isSelected: isRowSelected(id),
            isExternalEditing: editingTaskID == id
        )
    }

    func residentRow(_ routine: DailyRoutine, isDone: Bool) -> some View {
        let schedule = RoutineScheduleContext(
            todayKey: todayKey,
            checkDayKey: dayKey,
            checks: checks,
            locale: locale
        )
        let display = RoutineRowDisplayOptions(
            isDone: isDone,
            selection: rowSelection(for: routine.id)
        )
        let actions = RoutineRowActions(
            onSelect: { selectTask(routine.id, modifiers: $0) },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onToggle: nil,
            onSkip: isDone ? nil : {
                DayBoardMutations.skipRoutine(routine, on: dayKey, checks: checks, context: modelContext)
            },
            onEndEditing: { editingTaskID = nil }
        )
        return TaskRowFactory.routine(RoutineRowContext(
            routine: routine,
            schedule: schedule,
            catalogs: catalogContext,
            display: display,
            actions: actions
        ))
    }

    func todoRow(_ todo: TodoItem, isDone: Bool) -> some View {
        let display = TodoRowDisplayOptions(
            isDone: isDone,
            selection: rowSelection(for: todo.id),
            dragPayload: allowsTodoDrag ? TodoDragToken.encode(todo.id) : nil
        )
        let actions = TodoRowActions(
            onSelect: { selectTask(todo.id, modifiers: $0) },
            onDelete: {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.trashTodo(todo)
                }
            },
            onEndEditing: { editingTaskID = nil }
        )
        return TaskRowFactory.todo(TodoRowContext(
            todo: todo,
            todayKey: todayKey,
            catalogs: catalogContext,
            display: display,
            actions: actions
        ))
    }
}
