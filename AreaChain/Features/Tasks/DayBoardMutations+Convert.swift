import Foundation
import SwiftData

extension DayBoardMutations {
    @discardableResult
    static func setDue(_ todo: TodoItem, minutes: Int?) -> Bool {
        setDue(todo, minutes: minutes, save: { try $0.save() })
    }

    @discardableResult
    static func setDue(
        _ todo: TodoItem, minutes: Int?, save: @MainActor (ModelContext) throws -> Void
    ) -> Bool {
        persist(context: todo.modelContext, save: save) {
            TaskMutationService.assignDue(todo, minutes: minutes)
        }
    }

    @discardableResult
    static func applyManualOrder(_ entries: [ManualOrderEntry], context: ModelContext) -> Bool {
        let changed = entries
        return ModelChanges.perform(in: context) {
            let todos = try context.fetch(FetchDescriptor<TodoItem>())
            let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
            let todoMap = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
            let routineMap = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
            for entry in changed {
                if let todo = todoMap[entry.id] {
                    todo.sortOrder = entry.sortOrder
                } else if let routine = routineMap[entry.id] {
                    routine.sortOrder = entry.sortOrder
                }
            }
        }
    }

    /// 转换规则只在 ItemConversionService 一处；这里保留原签名供详情页调用。
    static func convertTodoToRoutine(_ todo: TodoItem) -> UUID? {
        ItemConversionService.convertTodoToRoutine(todo)
    }

    static func convertRoutineToTodo(_ routine: DailyRoutine) -> UUID? {
        ItemConversionService.convertRoutineToTodo(routine)
    }
}
