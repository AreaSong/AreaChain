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

    static func batchSetRoutineChecks(
        _ ids: Set<UUID>,
        markDone: Bool,
        on dayKey: String,
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        context: ModelContext
    ) {
        guard !ids.isEmpty else { return }
        persist {
            for routine in routines where ids.contains(routine.id) && routine.deletedAt == nil {
                if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == dayKey }) {
                    if markDone {
                        check.isDone = true
                    } else {
                        check.isDone = false
                        check.isSkipped = false
                    }
                } else if markDone {
                    context.insert(RoutineCheck(dayKey: dayKey, isDone: true, routine: routine))
                }
            }
        }
    }

    static func reorderRoutines(_ items: [DailyRoutine], from source: IndexSet, to destination: Int) {
        persist {
            Catalog.reindexRoutines(items, from: source, to: destination)
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
        let now = SoftDelete.stamp()
        let attachments = ownedAttachments(todos.first?.modelContext ?? routines.first?.modelContext)
        persist {
            for todo in todos where ids.contains(todo.id) && todo.deletedAt == nil {
                todo.deletedAt = now
                SoftDelete.stampLiveSubtasks(todo.subtasks, at: now)
                SoftDelete.stampAttachments(ownerID: todo.id, at: now, attachments: attachments)
            }
            for routine in routines where ids.contains(routine.id) && routine.deletedAt == nil {
                routine.deletedAt = now
                SoftDelete.stampAttachments(ownerID: routine.id, at: now, attachments: attachments)
            }
        }
    }
}
