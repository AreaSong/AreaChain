import Foundation
import SwiftData

extension TasksPage {
    func completeYesterday(_ item: UnfinishedItem, page: TasksPageViewModel? = nil) {
        let lookup = page ?? makePageModel()
        switch item.kind {
        case .todo:
            if let todo = lookup.todo(item.id) {
                DayBoardMutations.completeTodo(todo)
            }
        case .routine:
            if let routine = lookup.routine(item.id) {
                DayBoardMutations.markRoutineDone(routine, on: yesterdayKey)
            }
        }
    }

    func moveYesterdayTodo(_ item: UnfinishedItem, to dayKey: String, page: TasksPageViewModel? = nil) {
        guard item.kind == .todo, let todo = (page ?? makePageModel()).todo(item.id) else { return }
        DayBoardMutations.moveTodo(todo, to: dayKey)
    }

    func moveAllYesterdayTodosToToday(_ page: TasksPageViewModel? = nil) {
        let lookup = page ?? makePageModel()
        for item in lookup.yesterdayItems where item.kind == .todo {
            moveYesterdayTodo(item, to: todayKey, page: lookup)
        }
    }

    func deleteTodo(_ todo: TodoItem) {
        pendingTrash = PendingTrash(title: todo.title) {
            DayBoardMutations.trashTodo(todo)
        }
    }
}
