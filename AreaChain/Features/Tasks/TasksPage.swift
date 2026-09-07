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
    @State var showCompleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            leftoverChips
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    routineSection
                    todaySection
                    upcomingSection
                    completedSection
                    yesterdaySection
                }
            }
        }
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
}
