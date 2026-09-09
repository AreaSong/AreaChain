import Foundation
import SwiftData

extension TasksPage {
    func completeYesterday(_ item: UnfinishedItem) {
        DayBoardMutations.persist {
            switch item.kind {
            case .todo:
                todos.first { $0.id == item.id }?.isDone = true
            case .routine:
                guard let routine = routines.first(where: { $0.id == item.id }) else { return }
                if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == yesterdayKey }) {
                    check.isDone = true
                } else {
                    modelContext.insert(RoutineCheck(dayKey: yesterdayKey, isDone: true, routine: routine))
                }
            }
        }
    }

    func moveYesterdayTodo(_ item: UnfinishedItem, to dayKey: String) {
        guard item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) else { return }
        DayBoardMutations.moveTodo(todo, to: dayKey)
    }

    func deleteTodo(_ todo: TodoItem) {
        pendingTrash = PendingTrash(title: todo.title) {
            DayBoardMutations.trashTodo(todo)
        }
    }
}
