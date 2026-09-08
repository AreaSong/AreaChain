import Foundation
import SwiftData

extension DayBoardMutations {
    static func batchMoveTodos(_ ids: Set<UUID>, to dayKey: String, todos: [TodoItem]) {
        guard !ids.isEmpty else { return }
        persist {
            for todo in todos where ids.contains(todo.id) && todo.deletedAt == nil {
                todo.dayKey = dayKey
            }
        }
    }

    static func batchToggleDone(_ ids: Set<UUID>, markDone: Bool, todos: [TodoItem]) {
        guard !ids.isEmpty else { return }
        persist {
            for todo in todos where ids.contains(todo.id) && todo.deletedAt == nil {
                todo.isDone = markDone
                if markDone {
                    for sub in todo.subtasks where sub.deletedAt == nil && !sub.isDone {
                        sub.isDone = true
                    }
                }
            }
        }
    }

    static func batchSetProject(_ ids: Set<UUID>, projectID: UUID?, todos: [TodoItem], routines: [DailyRoutine]) {
        guard !ids.isEmpty else { return }
        persist {
            for todo in todos where ids.contains(todo.id) && todo.deletedAt == nil {
                todo.projectID = projectID
            }
            for routine in routines where ids.contains(routine.id) && routine.deletedAt == nil {
                routine.projectID = projectID
            }
        }
    }

    static func batchToggleTag(_ ids: Set<UUID>, tagID: UUID, todos: [TodoItem], routines: [DailyRoutine]) {
        guard !ids.isEmpty else { return }
        persist {
            for todo in todos where ids.contains(todo.id) && todo.deletedAt == nil {
                todo.tagIDs = TagIDList.toggling(todo.tagIDs, tagID)
            }
            for routine in routines where ids.contains(routine.id) && routine.deletedAt == nil {
                routine.tagIDs = TagIDList.toggling(routine.tagIDs, tagID)
            }
        }
    }

    static func batchTrash(_ ids: Set<UUID>, todos: [TodoItem], routines: [DailyRoutine]) {
        guard !ids.isEmpty else { return }
        let now = Date()
        persist {
            for todo in todos where ids.contains(todo.id) && todo.deletedAt == nil {
                todo.deletedAt = now
                for sub in todo.subtasks where sub.deletedAt == nil {
                    sub.deletedAt = now
                }
            }
            for routine in routines where ids.contains(routine.id) && routine.deletedAt == nil {
                routine.deletedAt = now
            }
        }
    }
}
