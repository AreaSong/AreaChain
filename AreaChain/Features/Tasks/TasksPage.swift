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
    @State var pendingTrash: PendingTrash?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            leftoverChips
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    DayBoardList(
                        dayKey: todayKey,
                        todayKey: todayKey,
                        routines: routines,
                        checks: checks,
                        todos: todos
                    )
                    upcomingSection
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
