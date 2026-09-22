import Foundation
import SwiftData

extension TasksPage {
    func completeYesterday(_ item: UnfinishedItem) {
        switch item.kind {
        case .todo:
            if let todo = todos.first(where: { $0.id == item.id }) {
                DayBoardMutations.completeTodo(todo)
            }
        case .routine:
            if let routine = routines.first(where: { $0.id == item.id }) {
                DayBoardMutations.markRoutineDone(routine, on: yesterdayKey)
            }
        }
    }

    func moveYesterdayTodo(_ item: UnfinishedItem, to dayKey: String) {
        guard item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) else { return }
        DayBoardMutations.moveTodo(todo, to: dayKey)
    }

    func moveAllYesterdayTodosToToday() {
        for item in yesterdayItems where item.kind == .todo {
            moveYesterdayTodo(item, to: todayKey)
        }
    }

    func deleteTodo(_ todo: TodoItem) {
        pendingTrash = PendingTrash(title: todo.title) {
            DayBoardMutations.trashTodo(todo)
        }
    }
}
