import Foundation
import SwiftData

extension DayBoardMutations {
    static func batchMoveTodos(_ ids: Set<UUID>, to dayKey: String, todos: [TodoItem] = []) {
        guard !ids.isEmpty else { return }
        try? taskRepo(for: todos.first?.modelContext).batchMoveTodos(ids: ids, to: dayKey)
    }

    static func batchToggleDone(_ ids: Set<UUID>, markDone: Bool, todos: [TodoItem] = []) {
        guard !ids.isEmpty else { return }
        try? taskRepo(for: todos.first?.modelContext).batchToggleDone(ids: ids, markDone: markDone)
    }

    static func batchSetRoutineChecks(
        _ ids: Set<UUID>,
        markDone: Bool,
        on dayKey: String,
        routines: [DailyRoutine] = [],
        context: ModelContext? = nil
    ) {
        guard !ids.isEmpty else { return }
        let repo = routineRepo(for: context ?? routines.first?.modelContext)
        try? repo.batchSetRoutineChecks(ids: ids, markDone: markDone, on: dayKey)
    }

    static func reorderRoutines(_ items: [DailyRoutine], from source: IndexSet, to destination: Int) {
        try? routineRepo(for: items.first?.modelContext).reorderRoutines(from: source, to: destination)
    }

    static func batchSetProject(
        _ ids: Set<UUID>,
        projectID: UUID?,
        todos: [TodoItem] = [],
        routines: [DailyRoutine] = []
    ) {
        guard !ids.isEmpty else { return }
        let context = todos.first?.modelContext ?? routines.first?.modelContext
        try? taskRepo(for: context).batchSetProject(ids: ids, projectID: projectID)
        try? routineRepo(for: context).batchSetProject(ids: ids, projectID: projectID)
    }

    static func batchToggleTag(
        _ ids: Set<UUID>,
        tagID: UUID,
        todos: [TodoItem] = [],
        routines: [DailyRoutine] = []
    ) {
        guard !ids.isEmpty else { return }
        let context = todos.first?.modelContext ?? routines.first?.modelContext
        try? taskRepo(for: context).batchToggleTag(ids: ids, tagID: tagID)
        try? routineRepo(for: context).batchToggleTag(ids: ids, tagID: tagID)
    }

    static func batchTrash(
        _ ids: Set<UUID>,
        todos: [TodoItem] = [],
        routines: [DailyRoutine] = []
    ) {
        guard !ids.isEmpty else { return }
        let context = todos.first?.modelContext ?? routines.first?.modelContext
        try? taskRepo(for: context).batchTrashTodos(ids: ids)
        try? routineRepo(for: context).batchTrashRoutines(ids: ids)
    }
}
