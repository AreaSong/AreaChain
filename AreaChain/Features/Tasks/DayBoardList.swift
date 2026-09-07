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

    @State private var showCompleted = true
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        Group {
            if openDayItems.isEmpty {
                Text("empty.todos")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
                    .padding(.vertical, 4)
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
                .buttonStyle(.plain)
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
        sortedRows(openRoutines.map(BoardRow.resident) + openTodos.map(BoardRow.todo))
    }

    private var doneDayItems: [BoardRow] {
        sortedRows(doneRoutines.map(BoardRow.resident) + doneTodos.map(BoardRow.todo))
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

    private func sortedRows(_ rows: [BoardRow]) -> [BoardRow] {
        rows.sorted { left, right in
            switch (left.remindMinutes, right.remindMinutes) {
            case let (a?, b?) where a != b:
                return a < b
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return left.createdAt < right.createdAt
            }
        }
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
            onSkip: isDone ? nil : { DayBoardMutations.skipRoutine(routine, on: dayKey, checks: checks, context: modelContext) }
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
            onRemindMinutes: { DayBoardMutations.setRemind(todo, minutes: $0) }
        )
    }
}
