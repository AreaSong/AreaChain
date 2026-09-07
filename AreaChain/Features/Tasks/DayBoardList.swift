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

    @State private var showCompleted = true
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        Group {
            if openDayItems.isEmpty {
                DaybookEmptyState(
                    title: filter.isActive ? "empty.filter" : "empty.todos",
                    systemImage: filter.isActive ? "line.3.horizontal.decrease" : "square.and.pencil"
                )
            } else {
                ForEach(openDayItems) { row in
                    dayRow(row, isDone: false)
                }
            }
            if completedCount > 0 {
                Button {
                    showCompleted.toggle()
                } label: {
                    SectionStamp(
                        title: showCompleted
                            ? "stamp.completed.collapse \(completedCount)"
                            : "stamp.completed \(completedCount)"
                    )
                }
                .buttonStyle(DaybookQuietButtonStyle())
                .accessibilityAddTraits(showCompleted ? .isSelected : [])
            }
            if showCompleted {
                ForEach(doneDayItems) { row in
                    dayRow(row, isDone: true)
                }
            }
        }
        .confirmMoveToTrash($pendingTrash)
    }

    private var snapshots: ([RoutineSnapshot], [CheckSnapshot], [TodoSnapshot]) {
        (routines.map(\.snapshot), checks.compactMap(\.snapshot), todos.map(\.snapshot))
    }

    private var completedCount: Int { doneDayItems.count }

    private var openDayItems: [BoardRow] {
        sortedRows(filtered(openRoutines.map(BoardRow.resident) + openTodos.map(BoardRow.todo)))
    }

    private var doneDayItems: [BoardRow] {
        sortedRows(filtered(doneRoutines.map(BoardRow.resident) + doneTodos.map(BoardRow.todo)))
    }

    private var openRoutines: [DailyRoutine] {
        let ids = Set(DayBoardLogic.openRoutines(routines: snapshots.0, checks: snapshots.1, dayKey: dayKey).map(\.id))
        return routines.filter { ids.contains($0.id) }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var doneRoutines: [DailyRoutine] {
        let ids = Set(
            DayBoardLogic.completedRoutines(routines: snapshots.0, checks: snapshots.1, dayKey: dayKey).map(\.id)
        )
        return routines.filter { ids.contains($0.id) }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var openTodos: [TodoItem] {
        let ids = Set(DayBoardLogic.openTodos(todos: snapshots.2, dayKey: dayKey).map(\.id))
        return todos.filter { ids.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
    }

    private var doneTodos: [TodoItem] {
        let ids = Set(DayBoardLogic.completedTodos(todos: snapshots.2, dayKey: dayKey).map(\.id))
        return todos.filter { ids.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
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
