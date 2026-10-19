import Foundation
import SwiftData

/// 只调用共享的 ItemConversionService；新建与软删处于同一次 ModelChanges，保存成功后才登记事实与私有发布。
@MainActor enum ConvertCommandTransaction {
    final class Result {
        var facts: CommandConvertFacts
        var transaction: ModelChanges.CommitFacts?
        init(_ facts: CommandConvertFacts) { self.facts = facts }
    }

    struct Conversion {
        let clock: ItemConversionService.Clock
        let refreshCalendar: () -> Void
    }

    static func apply(_ accepted: CommandConvertAcceptance, confirmation: CommandConvertConfirmation,
                      environment: BatchCommandEnvironment, conversion: Conversion,
                      register: @escaping (CommandConvertFacts) throws -> Void) -> CommandConvertFacts {
        let result = Result(.init(accepted, confirmation: confirmation))
        let impact = accepted.preview.impact
        var boundary = environment.dependencies.transaction
        boundary.publish = { [impact] in
            try environment.publish(changed: [impact.target, accepted.created]) { result.facts.external = $0 }
        }
        do {
            try ModelChanges.transaction(in: environment.context, boundary: boundary,
                                         observe: { result.transaction = $0 }) {
                let stamp = try convert(accepted, context: environment.context, clock: conversion.clock)
                try environment.dependencies.afterApply(impact.target)
                try verify(accepted, stamp: stamp, context: environment.context)
                ModelChanges.afterCommit(in: environment.context) {
                    result.facts.state = .saved
                    result.facts.save = .returned
                    result.facts.deletedAt = stamp
                    do {
                        try register(result.facts)
                        try environment.dependencies.registerLocalModification()
                    } catch {
                        result.facts.registrationFailed = true
                        boundary.reportFailure(error)
                    }
                }
            }
        } catch {
            result.facts.state = result.transaction?.save == .called || result.transaction?.phase == .recoveryFailed
                ? .unknown : .notSubmitted
            if result.facts.state == .notSubmitted { result.facts.deletedAt = nil }
            boundary.reportFailure(error)
        }
        result.facts.save = call(result.transaction?.save)
        result.facts.rollback = call(result.transaction?.rollback)
        result.facts.publication = call(result.transaction?.publication)
        result.facts.publicationFailed = result.transaction?.publicationFailed == true
        // 沿原界面实现：只有待办转习惯在保存成功后再请求一次日历刷新。
        if result.facts.state == .saved, accepted.preview.edit == .todoToRoutine {
            conversion.refreshCalendar()
            result.facts.calendarRefreshRequested = true
        }
        return result.facts
    }

    private static func convert(_ accepted: CommandConvertAcceptance, context: ModelContext,
                                clock: ItemConversionService.Clock) throws -> Date {
        let impact = accepted.preview.impact
        // 新身份此前不能存在：已存在说明另有写入，不能当作首次转换。
        guard try presence(accepted.created, context: context).isEmpty else { throw CommandConvertIssue.stale }
        switch accepted.preview.edit {
        case .todoToRoutine:
            let todo = try only(SwiftDataTaskRepository(context: context).fetchTodos(withID: impact.target.id), impact)
            _ = try ItemConversionService.applyTodoToRoutine(todo, routineID: accepted.createdID, in: context, clock: clock)
            guard let stamp = todo.deletedAt else { throw CommandConvertIssue.stale }
            return stamp
        case .routineToTodo:
            let routine = try only(SwiftDataRoutineRepository(context: context).fetchRoutines(withID: impact.target.id), impact)
            _ = try ItemConversionService.applyRoutineToTodo(routine, todoID: accepted.createdID, in: context, clock: clock)
            guard let stamp = routine.deletedAt else { throw CommandConvertIssue.stale }
            return stamp
        }
    }

    /// 保存前证明实际写入与预览的损失清单一致；任何扩大或缺失都整体回滚。
    private static func verify(_ accepted: CommandConvertAcceptance, stamp: Date, context: ModelContext) throws {
        let impact = accepted.preview.impact
        let owner = accepted.preview.edit == .todoToRoutine ? AttachmentOwner.routine : .todo
        let moved = Set(try OwnedAttachments.matching(ownerID: accepted.createdID, kind: owner, in: context)
            .filter { $0.deletedAt == nil }.map(\.persistentModelID))
        guard moved == impact.attachments else { throw CommandConvertIssue.stale }
        switch impact.losses {
        case .todoToRoutine(let losses):
            let todo = try only(SwiftDataTaskRepository(context: context).fetchTodos(withID: impact.target.id), impact)
            let routines = try SwiftDataRoutineRepository(context: context).fetchRoutines(withID: accepted.createdID)
            guard Set(todo.subtasks.filter { $0.deletedAt == stamp }.map(\.persistentModelID)) == impact.subtasks,
                  routines.count == 1, routines[0].deletedAt == nil, routines[0].weekdayMask == losses.weekdayMask,
                  routines[0].subtaskTemplates.count == losses.subtasks else { throw CommandConvertIssue.stale }
        case .routineToTodo(let losses):
            let routine = try only(SwiftDataRoutineRepository(context: context).fetchRoutines(withID: impact.target.id), impact)
            let todos = try SwiftDataTaskRepository(context: context).fetchTodos(withID: accepted.createdID)
            // 新子任务按 todo 关系从库里取，不依赖反向数组在保存前是否已刷新。
            let children = try todos.first.map { todo in
                try context.fetch(FetchDescriptor<SubtaskItem>()).filter { $0.todo === todo }
            } ?? []
            guard Set(routine.checks.map(\.persistentModelID)) == impact.checks, todos.count == 1,
                  todos[0].deletedAt == nil, todos[0].dayKey == losses.today,
                  children.count == losses.templates, children.allSatisfy({ $0.deletedAt == nil && !$0.isDone }) else {
                throw CommandConvertIssue.stale
            }
        }
    }

    static func presence(_ object: CommandObjectReference, context: ModelContext) throws -> [Date?] {
        switch object.type {
        case .todo: return try SwiftDataTaskRepository(context: context).fetchTodos(withID: object.id).map(\.deletedAt)
        case .routine: return try SwiftDataRoutineRepository(context: context).fetchRoutines(withID: object.id).map(\.deletedAt)
        default: throw CommandConvertIssue.invalidArguments
        }
    }

    private static func only<T: PersistentModel>(_ rows: [T], _ impact: CommandConvertImpact) throws -> T {
        guard rows.count == 1, rows[0].persistentModelID == impact.record else { throw CommandConvertIssue.stale }
        return rows[0]
    }

    private static func call(_ value: ModelChanges.CallFact?) -> CommandTaskTitleFacts.Call {
        switch value {
        case .called: return .called
        case .returned: return .returned
        default: return .notCalled
        }
    }
}
