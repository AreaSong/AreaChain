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

    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State private var showCompleted = false
    @State private var pendingTrash: PendingTrash?
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
        .confirmMoveToTrash($pendingTrash)
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
        return TaskRow(
            title: routine.title,
            isDone: isDone,
            isResident: true,
            note: isDone ? ResidentNote.done(routine, skipped: skipped, locale: locale) : ResidentNote.days(routine, locale: locale),
            remindMinutes: routine.remindMinutes,
            onToggle: { DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: checks, context: modelContext) },
            onSkip: isDone ? nil : { DayBoardMutations.skipRoutine(routine, on: dayKey, checks: checks, context: modelContext) },
            isImportant: routine.isImportant,
            isUrgent: routine.isUrgent
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
                    DayBoardMutations.persist { todo.deletedAt = .now }
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
            dragPayload: allowsTodoDrag ? TodoDragToken.encode(todo.id) : nil
        )
    }
}
