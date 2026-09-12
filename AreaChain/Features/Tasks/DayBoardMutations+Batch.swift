import Foundation
import SwiftData

extension DayBoardMutations {
    @discardableResult
    static func batchMoveTodos(_ ids: Set<UUID>, to dayKey: String, todos: [TodoItem] = []) -> Bool {
        ModelChanges.attempt(in: todos.first?.modelContext) {
            try taskRepo(for: todos.first?.modelContext).batchMoveTodos(ids: ids, to: dayKey)
        }
    }

    @discardableResult
    static func batchToggleDone(_ ids: Set<UUID>, markDone: Bool, todos: [TodoItem] = []) -> Bool {
        ModelChanges.attempt(in: todos.first?.modelContext) {
            try taskRepo(for: todos.first?.modelContext).batchToggleDone(ids: ids, markDone: markDone)
        }
    }

    @discardableResult
    static func batchSetRoutineChecks(
        _ ids: Set<UUID>, markDone: Bool, on dayKey: String,
        routines: [DailyRoutine] = [], context: ModelContext? = nil
    ) -> Bool {
        let context = context ?? routines.first?.modelContext
        return ModelChanges.attempt(in: context) {
            try routineRepo(for: context).batchSetRoutineChecks(ids: ids, markDone: markDone, on: dayKey)
        }
    }

    @discardableResult
    static func batchSetCompletion(_ ids: Set<UUID>, markDone: Bool, on dayKey: String, context: ModelContext) -> Bool {
        ModelChanges.perform(in: context) {
            try taskRepo(for: context).batchToggleDone(ids: ids, markDone: markDone)
            try routineRepo(for: context).batchSetRoutineChecks(ids: ids, markDone: markDone, on: dayKey)
        }
    }

    @discardableResult
    static func reorderRoutines(_ items: [DailyRoutine], from source: IndexSet, to destination: Int) -> Bool {
        ModelChanges.attempt(in: items.first?.modelContext) {
            try routineRepo(for: items.first?.modelContext).reorderRoutines(from: source, to: destination)
        }
    }

    @discardableResult
    static func batchSetProject(
        _ ids: Set<UUID>, projectID: UUID?, todos: [TodoItem] = [], routines: [DailyRoutine] = []
    ) -> Bool {
        let context = todos.first?.modelContext ?? routines.first?.modelContext ?? Persistence.session.container.mainContext
        return ModelChanges.perform(in: context) {
            try taskRepo(for: context).batchSetProject(ids: ids, projectID: projectID)
            try routineRepo(for: context).batchSetProject(ids: ids, projectID: projectID)
        }
    }

    @discardableResult
    static func batchToggleTag(
        _ ids: Set<UUID>, tagID: UUID, todos: [TodoItem] = [], routines: [DailyRoutine] = []
    ) -> Bool {
        let context = todos.first?.modelContext ?? routines.first?.modelContext ?? Persistence.session.container.mainContext
        return ModelChanges.perform(in: context) {
            try taskRepo(for: context).batchToggleTag(ids: ids, tagID: tagID)
            try routineRepo(for: context).batchToggleTag(ids: ids, tagID: tagID)
        }
    }

    @discardableResult
    static func batchTrash(_ ids: Set<UUID>, todos: [TodoItem] = [], routines: [DailyRoutine] = []) -> Bool {
        let context = todos.first?.modelContext ?? routines.first?.modelContext ?? Persistence.session.container.mainContext
        return ModelChanges.perform(in: context) {
            try taskRepo(for: context).batchTrashTodos(ids: ids)
            try routineRepo(for: context).batchTrashRoutines(ids: ids)
        }
    }
}
