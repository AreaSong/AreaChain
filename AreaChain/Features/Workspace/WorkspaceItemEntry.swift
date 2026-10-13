import Foundation
import SwiftUI

enum WorkspaceItemEntry: Identifiable {
    case todo(TodoItem, checkDayKey: String, subtaskIDs: Set<UUID>?)
    case routine(
        DailyRoutine,
        checkDayKey: String,
        allowsCompletion: Bool,
        overdueCount: Int,
        noteDayKey: String?
    )

    var id: String {
        switch self {
        case .todo(let todo, _, _):
            return BoardItemReference.todo(todo.id).id
        case .routine(let routine, _, _, _, _):
            return BoardItemReference.recurring(routine.id).id
        }
    }

    var modelID: UUID {
        switch self {
        case .todo(let todo, _, _):
            return todo.id
        case .routine(let routine, _, _, _, _):
            return routine.id
        }
    }

    var checkDayKey: String {
        switch self {
        case .todo(_, let day, _):
            return day
        case .routine(_, let day, _, _, _):
            return day
        }
    }

    var allowsCompletion: Bool {
        switch self {
        case .todo:
            return true
        case .routine(_, _, let allowed, _, _):
            return allowed
        }
    }

    var reference: BoardItemReference {
        switch self {
        case .todo(let todo, _, _):
            return .todo(todo.id)
        case .routine(let routine, _, _, _, _):
            return .recurring(routine.id)
        }
    }
}

struct WorkspaceItemGroup: Identifiable {
    var id: String
    var title: LocalizedStringKey?
    var entries: [WorkspaceItemEntry]
    /// 日期分组的显示名。和 `title` 可以同时出现：标题是段名，这行是那一天。
    var titleText: String? = nil
    /// 段头计数。日期分组的第一天用全部一次性事项的数量，而不是当天的行数。
    var sectionCount: Int? = nil
}

struct RoutineCompletionPrompt {
    var allowed: Bool
    var overdue: Int
    var noteDay: String?
}
