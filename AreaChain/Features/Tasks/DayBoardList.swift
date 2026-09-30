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
        let identity = makeListIdentity()
        VStack(alignment: .leading, spacing: 4) {
            if identity.openRows.isEmpty && identity.doneRows.isEmpty {
                emptyStateView
            } else {
                openItemsSection(identity)
            }

            if !identity.doneRows.isEmpty {
                completedSection(identity)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .background(KeyWindowHost { hostWindow = $0 })
        .onAppear {
            setupKeyMonitor()
            expandIfHighlighted(identity)
        }
        .onChange(of: focusedTaskID == nil) { _, missing in
            if missing {
                tearDownKeyMonitor()
            } else {
                setupKeyMonitor()
            }
        }
        .onChange(of: highlightedTaskID) { _, _ in
            expandIfHighlighted(makeListIdentity())
        }
        .onChange(of: focusedTaskID?.wrappedValue) { _, id in
            if let id, taskSelection.ids.contains(id) { return }
            taskSelection.focus(id)
        }
        .onChange(of: identity.visibleIDs(showCompleted: showCompleted)) { previous, next in
            taskSelection.dropRemoved(from: previous, to: next)
        }
        .onDisappear(perform: tearDownKeyMonitor)
        .confirmMoveToTrash($pendingTrash)
        .animation(DaybookMotion.interactive(reduceMotion), value: identity.openIDs)
        .animation(DaybookMotion.interactive(reduceMotion), value: config.isYesterdayExpanded)
        .environment(\.boardReorderEntries, allowsTodoDrag ? [] : reorderEntries(identity))
    }

    private func reorderEntries(_ identity: DayBoardListIdentity) -> [ManualOrderEntry] {
        identity.openRows.map { row in
            switch row {
            case .todo(let todo):
                ManualOrderEntry(id: todo.id, dayKey: dayKey, sortOrder: todo.sortOrder)
            case .resident(let routine):
                ManualOrderEntry(id: routine.id, dayKey: dayKey, sortOrder: routine.sortOrder)
            }
        }
    }

    func makeListIdentity() -> DayBoardListIdentity {
        DayBoardListIdentity.make(
            dayKey: dayKey,
            todayKey: todayKey,
            filter: filter,
            routines: routines,
            checks: checks,
            todos: todos,
            catalogs: TaskCatalogContext(tags: tags, attachments: attachments, context: modelContext),
            includeDoneStreaks: showCompleted
        )
    }

    var effectiveVisibleIDs: [UUID] { makeListIdentity().visibleIDs(showCompleted: showCompleted) }

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
        let identity = makeListIdentity()
        let revealDone = identity.doneRows.contains { $0.id == id }
        if revealDone {
            showCompleted = true
        }
        var selection = taskSelection
        if selection.anchorID == nil && selection.ids.isEmpty {
            selection.focus(focusedTaskID?.wrappedValue ?? highlightedTaskID)
        }
        let visibleIDs = identity.visibleIDs(showCompleted: showCompleted || revealDone)
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
        let rows = makeListIdentity().visibleRows(showCompleted: showCompleted)
        let stillVisible = focusedListID.map { listID in
            rows.contains { $0.listID == listID }
        } ?? false
        let sameModel = focusedListID.flatMap(BoardItemReference.init(listID:))?.modelID == id
        if stillVisible && sameModel { return }
        focusedListID = rows.first { $0.id == id }?.listID
    }

    func expandIfHighlighted(_ identity: DayBoardListIdentity? = nil) {
        let rows = identity ?? makeListIdentity()
        if let highlightedTaskID {
            revealCompletedIfNeeded(highlightedTaskID, identity: rows)
        }
        if let focused = focusedTaskID?.wrappedValue {
            revealCompletedIfNeeded(focused, identity: rows)
        }
    }

    func revealCompletedIfNeeded(_ id: UUID, identity: DayBoardListIdentity? = nil) {
        let rows = identity ?? makeListIdentity()
        if rows.doneRows.contains(where: { $0.id == id }) {
            showCompleted = true
        }
    }

    private func isRowSelected(_ row: BoardRow, identity: DayBoardListIdentity) -> Bool {
        let siblings = identity.visibleRows(showCompleted: showCompleted).filter { $0.id == row.id }
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

    @ViewBuilder
    func dayRow(_ row: BoardRow, isDone: Bool, identity: DayBoardListIdentity) -> some View {
        switch row {
        case .resident(let routine):
            residentRow(routine, isDone: isDone, identity: identity)
        case .todo(let todo):
            todoRow(todo, isDone: isDone, identity: identity)
        }
    }

    private func rowSelection(for row: BoardRow, identity: DayBoardListIdentity) -> TaskRowSelectionState {
        TaskRowSelectionState(
            isSelected: isRowSelected(row, identity: identity),
            isExternalEditing: editingTaskID == row.id
        )
    }

    func residentRow(_ routine: DailyRoutine, isDone: Bool, identity: DayBoardListIdentity) -> some View {
        let visuallyDone = PendingCompletionManager.shared.isVisuallyDone(id: routine.id, actualDone: isDone)
        let schedule = RoutineScheduleContext(
            todayKey: todayKey,
            checkDayKey: dayKey,
            checks: checks,
            locale: locale,
            lookups: identity.routineLookups(for: routine.id)
        )
        let display = RoutineRowDisplayOptions(
            isDone: visuallyDone,
            selection: rowSelection(for: .resident(routine), identity: identity)
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
            onToggle: { persistToggleSelected(id: routine.id) },
            onSkip: visuallyDone ? nil : {
                DayBoardMutations.skipRoutine(routine, on: dayKey, checks: checks, context: modelContext)
            },
            onEndEditing: { editingTaskID = nil }
        )
        return TaskRowFactory.routine(RoutineRowContext(
            routine: routine,
            schedule: schedule,
            catalogs: identity.catalogs,
            display: RoutineRowDisplayOptions(
                isDone: display.isDone,
                selection: display.selection,
                note: display.note,
                usesDefaultNote: display.usesDefaultNote,
                allowsCompletion: display.allowsCompletion,
                dragPayload: allowsTodoDrag ? nil : BoardReorderToken.encode(routine.id)
            ),
            actions: actions
        ))
    }

    func todoRow(_ todo: TodoItem, isDone: Bool, identity: DayBoardListIdentity) -> some View {
        let visuallyDone = PendingCompletionManager.shared.isVisuallyDone(id: todo.id, actualDone: isDone)
        let display = TodoRowDisplayOptions(
            isDone: visuallyDone,
            selection: rowSelection(for: .todo(todo), identity: identity),
            dragPayload: allowsTodoDrag ? TodoDragToken.encode(todo.id) : BoardReorderToken.encode(todo.id)
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
            onToggle: { persistToggleSelected(id: todo.id) },
            onEndEditing: { editingTaskID = nil }
        )
        return TaskRowFactory.todo(TodoRowContext(
            todo: todo,
            todayKey: todayKey,
            catalogs: identity.catalogs,
            display: display,
            actions: actions
        ))
    }
}
