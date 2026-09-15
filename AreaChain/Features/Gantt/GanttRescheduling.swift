import SwiftData

@MainActor
enum GanttRescheduling {
    @discardableResult
    static func commit(
        _ moves: [GanttTodoMove], todos: [TodoItem], context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) -> Bool {
        guard !moves.isEmpty else { return true }
        // 拖动期间发生改期、完成或删除时，不用旧快照覆盖较新的任务状态。
        guard moves.allSatisfy({ move in
            todos.contains {
                $0.id == move.id && $0.dayKey == move.originalDay && !$0.isDone && $0.deletedAt == nil
                    && $0.modelContext === context
            }
        }) else { return false }
        let repository = DayBoardMutations.taskRepo(for: context)
        return ModelChanges.perform(in: context, save: save) {
            for move in moves {
                try repository.moveTodo(id: move.id, to: move.destinationDay)
            }
        }
    }
}
