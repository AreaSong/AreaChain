import SwiftData
import SwiftUI

struct TasksPage: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) var locale

    var todayKey: String
    var yesterdayKey: String
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var todos: [TodoItem]

    @State var showYesterday = false
    @State var showUpcoming = false
    @State var showCompleted = true
    @State var residentDraft = ""
    @State var pendingTrash: PendingTrash?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            leftoverChips
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    todayList
                    upcomingSection
                    completedSection
                    yesterdaySection
                }
            }
            .daybookScroll()
        }
        .confirmMoveToTrash($pendingTrash)
    }

    var snapshots: ([RoutineSnapshot], [CheckSnapshot], [TodoSnapshot]) {
        (routines.map(\.snapshot), checks.compactMap(\.snapshot), todos.map(\.snapshot))
    }

    var openRoutineModels: [DailyRoutine] {
        let ids = Set(DayBoardLogic.openRoutines(routines: snapshots.0, checks: snapshots.1, dayKey: todayKey).map(\.id))
        return routines.filter { ids.contains($0.id) }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var doneRoutineModels: [DailyRoutine] {
        let ids = Set(DayBoardLogic.completedRoutines(routines: snapshots.0, checks: snapshots.1, dayKey: todayKey).map(\.id))
        return routines.filter { ids.contains($0.id) }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var openTodoModels: [TodoItem] {
        let ids = Set(DayBoardLogic.openTodos(todos: snapshots.2, dayKey: todayKey).map(\.id))
        return todos.filter { ids.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
    }

    var doneTodoModels: [TodoItem] {
        let ids = Set(DayBoardLogic.completedTodos(todos: snapshots.2, dayKey: todayKey).map(\.id))
        return todos.filter { ids.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
    }

    var yesterdayItems: [UnfinishedItem] {
        DayBoardLogic.yesterdayUnfinished(
            routines: snapshots.0,
            checks: snapshots.1,
            todos: snapshots.2,
            yesterdayKey: yesterdayKey
        )
    }

    var upcomingModels: [TodoItem] {
        let ids = Set(DayBoardLogic.upcomingTodos(todos: snapshots.2, todayKey: todayKey).map(\.id))
        return todos
            .filter { ids.contains($0.id) }
            .sorted {
                if $0.dayKey != $1.dayKey { return $0.dayKey < $1.dayKey }
                return $0.createdAt < $1.createdAt
            }
    }

    var completedCount: Int { doneRoutineModels.count + doneTodoModels.count }

    var disabledRoutineModels: [DailyRoutine] {
        routines.filter { $0.deletedAt == nil && !$0.isEnabled }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var openDayItems: [BoardRow] {
        sortedRows(
            openRoutineModels.map(BoardRow.resident) + openTodoModels.map(BoardRow.todo)
        )
    }

    var doneDayItems: [BoardRow] {
        sortedRows(
            doneRoutineModels.map(BoardRow.resident) + doneTodoModels.map(BoardRow.todo)
        )
    }

    func sortedRows(_ rows: [BoardRow]) -> [BoardRow] {
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
}

enum BoardRow: Identifiable {
    case resident(DailyRoutine)
    case todo(TodoItem)

    var id: UUID {
        switch self {
        case .resident(let item): item.id
        case .todo(let item): item.id
        }
    }

    var remindMinutes: Int? {
        switch self {
        case .resident(let item): item.remindMinutes
        case .todo(let item): item.remindMinutes
        }
    }

    var createdAt: Date {
        switch self {
        case .resident(let item): item.createdAt
        case .todo(let item): item.createdAt
        }
    }
}
