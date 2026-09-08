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

    @Query(sort: \ProjectItem.sortOrder) var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) var tags: [TagItem]
    @Query var attachments: [AttachmentItem]

    var maxScrollHeight: CGFloat? = nil

    @State var showYesterday = false
    @State var showUpcoming = false
    @State var pendingTrash: PendingTrash?
    @State var boardFilter = BoardFilter()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            leftoverChips
            BoardFilterBar(
                filter: boardFilter,
                projects: CatalogChoices.projects(projects),
                tags: CatalogChoices.tags(tags),
                bundleIDs: todayBundleIDs,
                onChange: { boardFilter = $0 }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    DayBoardList(
                        dayKey: todayKey,
                        todayKey: todayKey,
                        routines: routines,
                        checks: checks,
                        todos: todos,
                        filter: boardFilter
                    )
                    upcomingSection
                    yesterdaySection
                }
                .padding(.vertical, 2)
            }
            .daybookScroll()
            .frame(maxWidth: .infinity, maxHeight: maxScrollHeight ?? .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    var todayBundleIDs: [String] {
        let routineIDs = DayBoardLogic.routines(for: todayKey, in: snapshots.0).map(\.sourceBundleID)
        let todoIDs = DayBoardLogic.todos(for: todayKey, in: snapshots.2).map(\.sourceBundleID)
        return Array(Set((routineIDs + todoIDs).filter { !$0.isEmpty })).sorted()
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

    var boardSortKey: BoardSortKey {
        switch self {
        case .resident(let item):
            BoardSortKey(
                isImportant: item.isImportant,
                isUrgent: item.isUrgent,
                remindMinutes: item.remindMinutes,
                createdAt: item.createdAt
            )
        case .todo(let item):
            BoardSortKey(
                isImportant: item.isImportant,
                isUrgent: item.isUrgent,
                remindMinutes: item.remindMinutes,
                createdAt: item.createdAt
            )
        }
    }
}
