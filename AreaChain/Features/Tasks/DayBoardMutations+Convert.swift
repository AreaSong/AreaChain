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

    /// 混排顺序的写入只在 ManualOrderService 一处；这里保留原签名供拖放调用。
    @discardableResult
    static func applyManualOrder(_ entries: [ManualOrderEntry], context: ModelContext) -> Bool {
        ModelChanges.perform(in: context) { try ManualOrderService.apply(entries, in: context) }
    }

    /// 转换规则只在 ItemConversionService 一处；这里保留原签名供详情页调用。
    static func convertTodoToRoutine(_ todo: TodoItem) -> UUID? {
        ItemConversionService.convertTodoToRoutine(todo)
    }

    static func convertRoutineToTodo(_ routine: DailyRoutine) -> UUID? {
        ItemConversionService.convertRoutineToTodo(routine)
    }
}
