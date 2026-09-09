import AppKit
import SwiftData
import SwiftUI

struct DayBoardList: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) var locale

    var dayKey: String
    var todayKey: String
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var todos: [TodoItem]
    var filter: BoardFilter = BoardFilter()
    var allowsTodoDrag: Bool = false
    var focusedTaskID: Binding<UUID?>? = nil
    var highlightedTaskID: UUID? = nil
    var onInspect: ((UUID) -> Void)? = nil
    var onReturnToInput: (() -> Void)? = nil
    var dayKeyForID: ((UUID) -> String)? = nil

    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State var showCompleted = false
    @State var pendingTrash: PendingTrash?
    @State var editingTaskID: UUID? = nil
    @State var hostWindow: NSWindow?
    @State var keyMonitor: Any? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if openTodosList.isEmpty && openRoutinesList.isEmpty && doneItemsList.isEmpty {
                DaybookEmptyState(
                    title: filter.isActive ? "empty.filter" : "empty.todos",
                    systemImage: filter.isActive ? "line.3.horizontal.decrease" : "square.and.pencil"
                )
            } else {
                if !openTodosList.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionStamp(title: "stamp.todos", icon: "checklist", count: openTodosList.count)
                        ForEach(openTodosList) { todo in
                            todoRow(todo, isDone: false)
                        }
                    }
                }
                if !openRoutinesList.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionStamp(title: "stamp.routines", icon: "repeat", count: openRoutinesList.count)
                        ForEach(openRoutinesList) { routine in
                            residentRow(routine, isDone: false)
                        }
                    }
                }
                if openTodosList.isEmpty && openRoutinesList.isEmpty && !doneItemsList.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DaybookType.subtitle)
                            .foregroundStyle(DaybookTheme.stamp)
                        Text("header.done")
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookTheme.muted)
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !doneItemsList.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        withAnimation(DaybookMotion.animation(reduceMotion)) {
                            showCompleted.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DaybookTheme.muted)
                            SectionStamp(
                                title: showCompleted
                                    ? "stamp.completed.collapse \(doneItemsList.count)"
                                    : "stamp.completed \(doneItemsList.count)",
                                icon: "checkmark.circle"
                            )
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(showCompleted ? [.isSelected] : [])

                    if showCompleted {
                        ForEach(doneItemsList) { row in
                            dayRow(row, isDone: true)
                        }
                    }
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .background(KeyWindowHost { hostWindow = $0 })
        .onKeyPress(.downArrow) {
            guard focusedTaskID != nil else { return .ignored }
            navigateSelection(delta: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard focusedTaskID != nil else { return .ignored }
            navigateSelection(delta: -1)
            return .handled
        }
        .onKeyPress(.space) {
            if let id = focusedTaskID?.wrappedValue {
                toggleSelected(id: id)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            if let id = focusedTaskID?.wrappedValue {
                deleteSelected(id: id)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if let id = focusedTaskID?.wrappedValue {
                inspectSelected(id: id)
                return .handled
            }
            return .ignored
        }
        .onAppear {
            setupKeyMonitor()
            expandIfHighlighted()
        }
        .onChange(of: highlightedTaskID) { _, _ in
            expandIfHighlighted()
        }
        .onDisappear(perform: tearDownKeyMonitor)
        .confirmMoveToTrash($pendingTrash)
        .animation(DaybookMotion.interactive(reduceMotion), value: openTodosList.map(\.id))
        .animation(DaybookMotion.interactive(reduceMotion), value: openRoutinesList.map(\.id))
    }

    func selectTask(_ id: UUID) {
        focusedTaskID?.wrappedValue = id
        revealCompletedIfNeeded(id)
        BoardSelection.shared.inspectBoard(dayKey)
        onInspect?(id)
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
        focusedTaskID?.wrappedValue == id || highlightedTaskID == id
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
    private func dayRow(_ row: BoardRow, isDone: Bool) -> some View {
        switch row {
        case .resident(let routine):
            residentRow(routine, isDone: isDone)
        case .todo(let todo):
            todoRow(todo, isDone: isDone)
        }
    }

    private func residentRow(_ routine: DailyRoutine, isDone: Bool) -> some View {
        TaskRowFactory.routine(
            routine,
            isDone: isDone,
            todayKey: todayKey,
            checkDayKey: dayKey,
            checks: checks,
            context: modelContext,
            locale: locale,
            projects: projects,
            tags: tags,
            attachments: attachments,
            isSelected: isRowSelected(routine.id),
            isExternalEditing: editingTaskID == routine.id,
            onSelect: { selectTask(routine.id) },
            onEndEditing: { editingTaskID = nil },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onSkip: isDone ? nil : {
                DayBoardMutations.skipRoutine(routine, on: dayKey, checks: checks, context: modelContext)
            }
        )
    }

    private func todoRow(_ todo: TodoItem, isDone: Bool) -> some View {
        TaskRowFactory.todo(
            todo,
            isDone: isDone,
            todayKey: todayKey,
            projects: projects,
            tags: tags,
            attachments: attachments,
            context: modelContext,
            isSelected: isRowSelected(todo.id),
            isExternalEditing: editingTaskID == todo.id,
            dragPayload: allowsTodoDrag ? TodoDragToken.encode(todo.id) : nil,
            onSelect: { selectTask(todo.id) },
            onEndEditing: { editingTaskID = nil },
            onDelete: {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.trashTodo(todo)
                }
            }
        )
    }
}
