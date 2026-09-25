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
    var yesterdayUnfinishedCount: Int = 0
    var isYesterdayExpanded: Bool = false
    var selection: Binding<TaskSelection>? = nil
    var visibleIDsProvider: (() -> [UUID])? = nil
    var onToggleYesterday: (() -> Void)? = nil

    init(
        todayKey: String? = nil,
        filter: BoardFilter = BoardFilter(),
        allowsTodoDrag: Bool = false,
        dayKeyForID: ((UUID) -> String)? = nil,
        interaction: DayBoardInteraction = DayBoardInteraction(),
        yesterdayUnfinishedCount: Int = 0,
        isYesterdayExpanded: Bool = false,
        selection: Binding<TaskSelection>? = nil,
        visibleIDsProvider: (() -> [UUID])? = nil,
        onToggleYesterday: (() -> Void)? = nil
    ) {
        self.todayKey = todayKey
        self.filter = filter
        self.allowsTodoDrag = allowsTodoDrag
        self.dayKeyForID = dayKeyForID
        self.interaction = interaction
        self.yesterdayUnfinishedCount = yesterdayUnfinishedCount
        self.isYesterdayExpanded = isYesterdayExpanded
        self.selection = selection
        self.visibleIDsProvider = visibleIDsProvider
        self.onToggleYesterday = onToggleYesterday
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

    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State var showCompleted = false
    @State var focusedListID: String?
    @State private var internalSelection = TaskSelection()
    private var activeSelection: Binding<TaskSelection> {
        config.selection ?? $internalSelection
    }
    var taskSelection: TaskSelection {
        get { activeSelection.wrappedValue }
        nonmutating set { activeSelection.wrappedValue = newValue }
    }
    @State var pendingTrash: PendingTrash?
    @State var editingTaskID: UUID? = nil
    @State var hostWindow: NSWindow?
    @State var keyMonitor: Any? = nil
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if openItemsList.isEmpty && doneItemsList.isEmpty {
                emptyStateView
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
        .onChange(of: effectiveVisibleIDs) { _, ids in
            taskSelection.reconcile(with: ids)
        }
        .onDisappear(perform: tearDownKeyMonitor)
        .confirmMoveToTrash($pendingTrash)
        .animation(DaybookMotion.interactive(reduceMotion), value: openItemsList.map(\.id))
        .animation(DaybookMotion.interactive(reduceMotion), value: config.isYesterdayExpanded)
    }

    var effectiveVisibleIDs: [UUID] {
        config.visibleIDsProvider?() ?? orderedVisibleIDs
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if filter.isActive {
            DaybookEmptyState(
                title: "empty.filter",
                subtitle: "empty.filter.hint",
                systemImage: "line.3.horizontal.decrease",
                centerVertically: true
            )
        } else if config.yesterdayUnfinishedCount > 0 {
            if !config.isYesterdayExpanded {
                DaybookEmptyState(
                    title: "empty.yesterday.title",
                    subtitle: "empty.yesterday.hint",
                    systemImage: "clock.arrow.circlepath",
                    centerVertically: true
                )
            }
        } else {
            DaybookEmptyState(
                title: "empty.todos.title",
                subtitle: "empty.todos.hint",
                systemImage: "square.and.pencil",
                centerVertically: true
            )
        }
    }

    func selectTask(_ id: UUID, modifiers: TaskSelectionModifiers = []) {
        revealCompletedIfNeeded(id)
        var selection = taskSelection
        if selection.anchorID == nil && selection.ids.isEmpty {
            selection.focus(focusedTaskID?.wrappedValue ?? highlightedTaskID)
        }
        let visibleIDs = effectiveVisibleIDs
        selection.select(id, in: visibleIDs, modifiers: modifiers)
        taskSelection = selection
        focusedTaskID?.wrappedValue = selection.ids.contains(id)
            ? id : visibleIDs.first { selection.ids.contains($0) }
        BoardSelection.shared.inspectBoard(mappedDayKey(for: id))
        if modifiers.isEmpty {
            onInspect?(id)
            if let focusedListID, let reference = BoardItemReference(listID: focusedListID), reference.modelID == id {
                WorkspaceNavigation.shared.inspectedReference = reference
            }
        }
    }

    func focusTask(_ id: UUID?) {
        taskSelection.focus(id)
        focusedTaskID?.wrappedValue = id
        guard let id else {
            focusedListID = nil
            return
        }
        let stillVisible = focusedListID.map { listID in
            orderedVisibleRows.contains { $0.listID == listID }
        } ?? false
        let sameModel = focusedListID.flatMap(BoardItemReference.init(listID:))?.modelID == id
        if stillVisible && sameModel { return }
        focusedListID = orderedVisibleRows.first { $0.id == id }?.listID
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

    private func isRowSelected(_ row: BoardRow) -> Bool {
        let siblings = orderedVisibleRows.filter { $0.id == row.id }
        if siblings.count > 1 {
            return row.listID == focusedListID
        }
        return isRowSelected(row.id)
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

    var openItemsList: [BoardRow] {
        sortedRows(filtered(openRoutines.map(BoardRow.resident) + openTodos.map(BoardRow.todo)))
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
            Classification.matchesListedTodo(
                $0.classifyBits, dayKey: $0.dayKey, isDone: $0.isDone, todayKey: todayKey,
                filter: filter
            )
        }
    }

    private func filteredRoutines(_ list: [DailyRoutine]) -> [DailyRoutine] {
        guard filter.isActive else { return list }
        return list.filter {
            Classification.matchesListedRoutine($0.classifyBits, filter: filter)
        }
    }

    private func filtered(_ rows: [BoardRow]) -> [BoardRow] {
        guard filter.isActive else { return rows }
        return rows.filter { row in
            switch row {
            case .resident(let routine):
                return Classification.matchesListedRoutine(routine.classifyBits, filter: filter)
            case .todo(let todo):
                return Classification.matchesListedTodo(
                    todo.classifyBits, dayKey: todo.dayKey, isDone: todo.isDone, todayKey: todayKey,
                    filter: filter
                )
            }
        }
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
            tags: tags,
            attachments: attachments,
            context: modelContext
        )
    }

    private func rowSelection(for row: BoardRow) -> TaskRowSelectionState {
        TaskRowSelectionState(
            isSelected: isRowSelected(row),
            isExternalEditing: editingTaskID == row.id
        )
    }

    func residentRow(_ routine: DailyRoutine, isDone: Bool) -> some View {
        let visuallyDone = PendingCompletionManager.shared.isVisuallyDone(id: routine.id, actualDone: isDone)
        let schedule = RoutineScheduleContext(
            todayKey: todayKey,
            checkDayKey: dayKey,
            checks: checks,
            locale: locale
        )
        let display = RoutineRowDisplayOptions(
            isDone: visuallyDone,
            selection: rowSelection(for: .resident(routine))
        )
        let actions = RoutineRowActions(
            onSelect: {
                focusedListID = BoardItemReference.recurring(routine.id).id
                selectTask(routine.id, modifiers: $0)
            },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onToggle: { singleToggleSelected(id: routine.id) },
            onSkip: visuallyDone ? nil : {
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
        let visuallyDone = PendingCompletionManager.shared.isVisuallyDone(id: todo.id, actualDone: isDone)
        let display = TodoRowDisplayOptions(
            isDone: visuallyDone,
            selection: rowSelection(for: .todo(todo)),
            dragPayload: allowsTodoDrag ? TodoDragToken.encode(todo.id) : nil
        )
        let actions = TodoRowActions(
            onSelect: {
                focusedListID = BoardItemReference.todo(todo.id).id
                selectTask(todo.id, modifiers: $0)
            },
            onDelete: {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.trashTodo(todo)
                }
            },
            onToggle: { singleToggleSelected(id: todo.id) },
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
