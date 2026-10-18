import Foundation
import SwiftData

/// 只调用原仓储软删；全部目标处于同一次 ModelChanges，保存成功后才登记事实与私有发布。
@MainActor enum TrashCommandTransaction {
    final class Result {
        var facts: CommandTrashFacts
        var transaction: ModelChanges.CommitFacts?
        init(_ facts: CommandTrashFacts) { self.facts = facts }
    }

    static func apply(_ accepted: CommandTrashAcceptance, confirmation: CommandTrashConfirmation,
                      environment: BatchCommandEnvironment,
                      register: @escaping (CommandTrashFacts) throws -> Void) -> CommandTrashFacts {
        let result = Result(.init(accepted, confirmation: confirmation))
        let preview = accepted.preview
        var boundary = environment.dependencies.transaction
        // 子任务没有自己的提醒或日历；刷新沿所属待办。
        let refreshed = preview.impacts.map { $0.parent ?? $0.target }
        boundary.publish = { try environment.publish(changed: refreshed) { result.facts.external = $0 } }
        do {
            try preview.validateLimit()
            try ModelChanges.transaction(in: environment.context, boundary: boundary,
                                         observe: { result.transaction = $0 }) {
                try softDelete(preview, dependencies: environment.dependencies)
                let stamps = try verify(preview, context: environment.context)
                ModelChanges.afterCommit(in: environment.context) {
                    result.facts.state = .saved
                    result.facts.save = .returned
                    result.facts.deletedAt = stamps
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
            if result.facts.state == .notSubmitted { result.facts.deletedAt = [:] }
            boundary.reportFailure(error)
        }
        result.facts.save = call(result.transaction?.save)
        result.facts.rollback = call(result.transaction?.rollback)
        result.facts.publication = call(result.transaction?.publication)
        result.facts.publicationFailed = result.transaction?.publicationFailed == true
        return result.facts
    }

    /// 批量按类型分开传 ID：同一 UUID 的待办与习惯不能互相波及。
    private static func softDelete(_ preview: CommandTrashPreview,
                                   dependencies: BatchCommandEnvironment.Dependencies) throws {
        let targets = preview.targets.objects
        switch preview.edit {
        case .todo: try dependencies.tasks.deleteTodo(id: targets[0].id, soft: true)
        case .subtask: try dependencies.tasks.deleteSubtask(id: targets[0].id, soft: true)
        case .routine: try dependencies.routines.deleteRoutine(id: targets[0].id, soft: true)
        case .batch:
            let todos = Set(targets.filter { $0.type == .todo }.map(\.id))
            let routines = Set(targets.filter { $0.type == .routine }.map(\.id))
            if !todos.isEmpty { try dependencies.tasks.batchTrashTodos(ids: todos) }
            if !routines.isEmpty { try dependencies.routines.batchTrashRoutines(ids: routines) }
        }
        for target in targets { try dependencies.afterApply(target) }
    }

    /// 保存前证明实际删除戳只落在冻结集合上；任何扩大或缺失都整体回滚。
    private static func verify(_ preview: CommandTrashPreview,
                               context: ModelContext) throws -> [CommandObjectReference: Date] {
        var stamps: [CommandObjectReference: Date] = [:]
        for impact in preview.impacts {
            let stamp: Date?
            switch impact.target.type {
            case .todo:
                let todo = try only(SwiftDataTaskRepository(context: context).fetchTodos(withID: impact.target.id), impact)
                stamp = todo.deletedAt
                guard let stamp, Set(todo.subtasks.filter { $0.deletedAt == stamp }.map(\.persistentModelID)) == impact.subtasks,
                      try attachments(todo.id, kind: .todo, stamp: stamp, context: context) == impact.attachments else {
                    throw CommandTrashIssue.stale
                }
            case .routine:
                let routine = try only(SwiftDataRoutineRepository(context: context).fetchRoutines(withID: impact.target.id), impact)
                stamp = routine.deletedAt
                guard let stamp, try attachments(routine.id, kind: .routine, stamp: stamp, context: context) == impact.attachments else {
                    throw CommandTrashIssue.stale
                }
            case .subtask:
                let id = impact.target.id
                stamp = try only(context.fetch(FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id })), impact).deletedAt
            default: throw CommandTrashIssue.stale
            }
            guard let stamp else { throw CommandTrashIssue.stale }
            stamps[impact.target] = stamp
        }
        return stamps
    }

    private static func only<T: PersistentModel>(_ rows: [T], _ impact: CommandTrashTargetImpact) throws -> T {
        guard rows.count == 1, rows[0].persistentModelID == impact.record else { throw CommandTrashIssue.stale }
        return rows[0]
    }

    private static func attachments(_ owner: UUID, kind: AttachmentOwner, stamp: Date,
                                    context: ModelContext) throws -> Set<PersistentIdentifier> {
        Set(try OwnedAttachments.matching(ownerID: owner, kind: kind, in: context)
            .filter { $0.deletedAt == stamp }.map(\.persistentModelID))
    }

    private static func call(_ value: ModelChanges.CallFact?) -> CommandTaskTitleFacts.Call {
        switch value {
        case .called: return .called
        case .returned: return .returned
        default: return .notCalled
        }
    }
}
