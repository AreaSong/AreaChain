import AppKit
import SwiftData
import SwiftUI

struct DayBoardList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

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

    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State private var showCompleted = false
    @State private var pendingTrash: PendingTrash?
    @State private var editingTaskID: UUID? = nil
    @State private var hostWindow: NSWindow?
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
                            .font(.system(size: 12))
                            .foregroundStyle(DaybookTheme.stamp)
                        Text("header.done")
                            .font(.system(size: 11, weight: .medium))
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
        .animation(ModernMotion.interactive(reduceMotion), value: openTodosList.map(\.id))
        .animation(ModernMotion.interactive(reduceMotion), value: openRoutinesList.map(\.id))
    }

    @State private var keyMonitor: Any? = nil

    private func setupKeyMonitor() {
        guard focusedTaskID != nil else { return }
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.shouldHandle(event) else { return event }

            let firstResponder = NSApp.keyWindow?.firstResponder
            let isTextViewEditing = (firstResponder as? NSTextView)?.isEditable == true

            if isTextViewEditing {
                if event.keyCode == 53 {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    return nil
                }
                if event.keyCode == 125, let tv = firstResponder as? NSTextView, tv.string.isEmpty {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    navigateSelection(delta: 1)
                    return nil
                }
                return event
            }

            switch event.keyCode {
            case 125:
                navigateSelection(delta: 1)
                return nil
            case 126:
                navigateSelection(delta: -1)
                return nil
            case 49:
                if let id = focusedTaskID?.wrappedValue {
                    toggleSelected(id: id)
                    return nil
                }
            case 36:
                if let id = focusedTaskID?.wrappedValue {
                    inspectSelected(id: id)
                    return nil
                }
            case 51:
                if let id = focusedTaskID?.wrappedValue {
                    deleteSelected(id: id)
                    return nil
                }
            case 14:
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
                guard mods.isEmpty else { break }
                if let id = focusedTaskID?.wrappedValue {
                    editingTaskID = id
                    return nil
                }
            case 53:
                if WorkspaceNavigation.shared.isInspectorPresented,
                   hostWindow === PanelWindowController.workspace.hostedWindow
                {
                    WorkspaceNavigation.shared.isInspectorPresented = false
                    return nil
                }
                if focusedTaskID?.wrappedValue != nil {
                    focusedTaskID?.wrappedValue = nil
                    onReturnToInput?()
                    return nil
                }
            default:
                break
            }
            return event
        }
    }

    private func shouldHandle(_ event: NSEvent) -> Bool {
        let mine = hostWindow
        let eventWindow = event.window
        if let mine, let eventWindow {
            return eventWindow === mine
        }
        return mine != nil && NSApp.keyWindow === mine
    }

    private func tearDownKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func navigateSelection(delta: Int) {
        let ids = orderedVisibleIDs
        guard !ids.isEmpty else { return }
        if let current = focusedTaskID?.wrappedValue, let idx = ids.firstIndex(of: current) {
            let nextIdx = idx + delta
            if nextIdx >= 0 && nextIdx < ids.count {
                focusedTaskID?.wrappedValue = ids[nextIdx]
            } else if nextIdx < 0 {
                focusedTaskID?.wrappedValue = nil
                onReturnToInput?()
            }
        } else {
            focusedTaskID?.wrappedValue = delta >= 0 ? ids.first : ids.last
        }
    }

    private var orderedVisibleIDs: [UUID] {
        var ids: [UUID] = []
        ids.append(contentsOf: openTodosList.map(\.id))
        ids.append(contentsOf: openRoutinesList.map(\.id))
        if showCompleted {
            ids.append(contentsOf: doneItemsList.map(\.id))
        }
        return ids
    }

    private func toggleSelected(id: UUID) {
        let ids = orderedVisibleIDs
        if let idx = ids.firstIndex(of: id) {
            if !showCompleted {
                if idx + 1 < ids.count {
                    focusedTaskID?.wrappedValue = ids[idx + 1]
                } else if idx > 0 {
                    focusedTaskID?.wrappedValue = ids[idx - 1]
                }
            }
        }
        if let todo = todos.first(where: { $0.id == id }) {
            DayBoardMutations.toggleTodo(todo)
            return
        }
        if let routine = routines.first(where: { $0.id == id }) {
            DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: checks, context: modelContext)
        }
    }

    private func deleteSelected(id: UUID) {
        let ids = orderedVisibleIDs
        if let idx = ids.firstIndex(of: id) {
            if idx + 1 < ids.count {
                focusedTaskID?.wrappedValue = ids[idx + 1]
            } else if idx > 0 {
                focusedTaskID?.wrappedValue = ids[idx - 1]
            } else {
                focusedTaskID?.wrappedValue = nil
                onReturnToInput?()
            }
        }
        if let todo = todos.first(where: { $0.id == id }) {
            pendingTrash = PendingTrash(title: todo.title) {
                DayBoardMutations.trashTodo(todo)
            }
            return
        }
        if let routine = routines.first(where: { $0.id == id }) {
            pendingTrash = PendingTrash(title: routine.title) {
                DayBoardMutations.trashRoutine(routine)
            }
        }
    }

    private func inspectSelected(id: UUID) {
        revealCompletedIfNeeded(id)
        if dayKey == todayKey {
            AppWindows.openWorkspace(tab: .today)
        } else {
            BoardSelection.shared.inspectBoard(dayKey)
            AppWindows.openWorkspace(tab: .calendar)
        }
        WorkspaceNavigation.shared.inspectTask(id)
    }

    private func selectTask(_ id: UUID) {
        focusedTaskID?.wrappedValue = id
        revealCompletedIfNeeded(id)
        onInspect?(id)
    }

    private func expandIfHighlighted() {
        if let highlightedTaskID {
            revealCompletedIfNeeded(highlightedTaskID)
        }
        if let focused = focusedTaskID?.wrappedValue {
            revealCompletedIfNeeded(focused)
        }
    }

    private func revealCompletedIfNeeded(_ id: UUID) {
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

    private var openTodosList: [TodoItem] {
        filteredTodos(openTodos)
    }

    private var openRoutinesList: [DailyRoutine] {
        filteredRoutines(openRoutines)
    }

    private var doneItemsList: [BoardRow] {
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
        let skipped = DayBoardLogic.isRoutineSkipped(routine.snapshot, checks: snapshots.1, on: dayKey)
        let streakResult = HabitStreakLogic.calculate(
            routine: routine.snapshot,
            checks: snapshots.1,
            todayKey: todayKey
        )
        return TaskRow(
            title: routine.title,
            isDone: isDone,
            isResident: true,
            note: isDone ? ResidentNote.done(routine, skipped: skipped, locale: locale) : ResidentNote.days(routine, locale: locale),
            streak: streakResult.currentStreak,
            remindMinutes: routine.remindMinutes,
            onToggle: { DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: checks, context: modelContext) },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onEdit: { DayBoardMutations.editRoutine(routine, title: $0) },
            onSkip: isDone ? nil : { DayBoardMutations.skipRoutine(routine, on: dayKey, checks: checks, context: modelContext) },
            onRemindMinutes: { DayBoardMutations.setRemind(routine, minutes: $0) },
            onDisable: { DayBoardMutations.persist { routine.isEnabled = false } },
            onEnable: { DayBoardMutations.persist { routine.isEnabled = true } },
            isImportant: routine.isImportant,
            isUrgent: routine.isUrgent,
            classify: CatalogChoices.classify(for: routine, projects: projects, tags: tags),
            attachments: CatalogChoices.attachments(
                ownerKind: .routine,
                ownerID: routine.id,
                items: attachments,
                context: modelContext
            ),
            notes: routine.notes,
            isSelected: isRowSelected(routine.id),
            isExternalEditing: editingTaskID == routine.id,
            onSelect: { selectTask(routine.id) },
            onEndEditing: { editingTaskID = nil },
            isEnabled: routine.isEnabled
        )
    }

    private func todoRow(_ todo: TodoItem, isDone: Bool) -> some View {
        TaskRow(
            title: todo.title,
            isDone: isDone,
            remindMinutes: todo.remindMinutes,
            todayKey: todayKey,
            currentDayKey: todo.dayKey,
            onToggle: { DayBoardMutations.toggleTodo(todo) },
            onDelete: {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.trashTodo(todo)
                }
            },
            onEdit: { DayBoardMutations.editTodo(todo, title: $0) },
            onMoveToDay: { DayBoardMutations.moveTodo(todo, to: $0) },
            onRemindMinutes: { DayBoardMutations.setRemind(todo, minutes: $0) },
            classify: CatalogChoices.classify(for: todo, projects: projects, tags: tags),
            attachments: CatalogChoices.attachments(
                ownerKind: .todo,
                ownerID: todo.id,
                items: attachments,
                context: modelContext
            ),
            notes: todo.notes,
            subtasks: todo.subtasks
                .filter { $0.deletedAt == nil }
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .compactMap { $0.snapshot },
            onToggleSubtask: { subID in
                if let sub = todo.subtasks.first(where: { $0.id == subID }) {
                    DayBoardMutations.toggleSubtask(sub)
                }
            },
            dragPayload: allowsTodoDrag ? TodoDragToken.encode(todo.id) : nil,
            isSelected: isRowSelected(todo.id),
            isExternalEditing: editingTaskID == todo.id,
            onSelect: { selectTask(todo.id) },
            onEndEditing: { editingTaskID = nil }
        )
    }
}
