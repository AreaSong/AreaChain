import Foundation
import SwiftData

struct ReminderCatalogLoad: Equatable {
    var requests: [ReminderRequest]
    var routineRows: Int
    var todoRows: Int
    var checkRows: Int
    var fetchCalls: Int
}

enum ReminderCatalogStore {
    /// 只拉 catalog 会用到的行：有提醒的活习惯/待办，以及今天起的打卡。
    static func load(from context: ModelContext, todayKey: String) -> ReminderCatalogLoad {
        let routines = (try? context.fetch(routineDescriptor)) ?? []
        let todos = (try? context.fetch(todoDescriptor)) ?? []
        let checks = (try? context.fetch(checkDescriptor(todayKey: todayKey))) ?? []
        let requests = ReminderPlanning.catalog(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            todayKey: todayKey
        )
        return ReminderCatalogLoad(
            requests: requests,
            routineRows: routines.count,
            todoRows: todos.count,
            checkRows: checks.count,
            fetchCalls: 3
        )
    }

    private static var routineDescriptor: FetchDescriptor<DailyRoutine> {
        FetchDescriptor(predicate: #Predicate<DailyRoutine> { routine in
            routine.deletedAt == nil && routine.isEnabled == true && routine.remindMinutes != nil
        })
    }

    private static var todoDescriptor: FetchDescriptor<TodoItem> {
        FetchDescriptor(predicate: #Predicate<TodoItem> { todo in
            todo.deletedAt == nil && todo.remindMinutes != nil
        })
    }

    private static func checkDescriptor(todayKey: String) -> FetchDescriptor<RoutineCheck> {
        FetchDescriptor(predicate: #Predicate<RoutineCheck> { check in
            check.dayKey >= todayKey
        })
    }
}
