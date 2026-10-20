import SwiftData

@MainActor
enum GanttRescheduling {
    @discardableResult
    static func commit(
        _ moves: [GanttTodoMove], todos: [TodoItem], context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) -> Bool {
        guard !moves.isEmpty else { return true }
        // 资格核对与写入都在共享入口（GanttRescheduleService），gantt.shift 用同一份。
        guard GanttRescheduleService.eligible(moves, todos: todos, context: context) else { return false }
        let repository = DayBoardMutations.taskRepo(for: context)
        return ModelChanges.perform(in: context, save: save) {
            try GanttRescheduleService.apply(moves, repository: repository)
        }
    }
}
