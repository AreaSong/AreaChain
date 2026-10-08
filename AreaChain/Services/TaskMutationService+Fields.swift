import Foundation
import SwiftData

extension TaskMutationService {
    @MainActor final class FieldModification {
        let targetID: UUID
        fileprivate(set) var transaction: ModelChanges.CommitFacts?
        fileprivate(set) var registrationFailed = false
        fileprivate(set) var reminderRequest = ModelChanges.CallFact.notCalled
        fileprivate(set) var savedTagEffects: [CommandTaskTagAssociation.Effect]?
        fileprivate(set) var savedTagIDs: [UUID]?
        fileprivate(set) var completedSubtaskIDs: [UUID]?
        fileprivate var savedLocally = false
        fileprivate var rejected = false
        init(targetID: UUID) { self.targetID = targetID }
        var state: LocalState {
            if savedLocally { return .saved }
            if transaction?.save == .called || transaction?.phase == .recoveryFailed { return .commitUnknown }
            if rejected || transaction?.phase == .rolledBack { return .notSubmitted }
            return .pending
        }
    }

    /// 字段修改与标签实体效果在同一事务内；提交前由适配核对不可编辑接受证据。
    static func editField(_ todo: TodoItem, accepted: CommandTaskFieldAcceptance, in context: ModelContext,
                          dependencies: TitleDependencies) -> FieldModification {
        let result = FieldModification(targetID: todo.id)
        let edit = accepted.preview.edit
        do {
            try dependencies.validateBeforeTransaction()
            try ModelChanges.transaction(in: context, boundary: dependencies.transaction,
                                         observe: { result.transaction = $0 }) {
                let repository = dependencies.repository(context)
                try applyField(todo, accepted: accepted, repository: repository, context: context)
                ModelChanges.afterCommit(in: context) {
                    result.savedLocally = true
                    result.savedTagEffects = accepted.preview.tags?.actions.final.map(\.effect)
                    if accepted.preview.tags != nil { result.savedTagIDs = TagIDList.parse(todo.tagIDs) }
                    result.completedSubtaskIDs = accepted.preview.completion?.affected.map(\.id)
                    do { try dependencies.registerLocalModification(todo.id) }
                    catch {
                        result.registrationFailed = true
                        ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
                    }
                }
                ModelChanges.afterPublication(in: context) {
                    if case .reminder(let minutes) = edit, let minutes {
                        result.reminderRequest = .called
                        dependencies.requestReminderAccessIfNeeded(minutes)
                        result.reminderRequest = .returned
                    }
                }
            }
        } catch {
            result.rejected = true
            ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
        }
        return result
    }

    /// 旧 setDue 的表示规则；此入口只赋值，保存时机继续由各调用者决定。
    static func assignDue(_ todo: TodoItem, minutes: Int?) {
        todo.dueMinutes = RemindMinutes.clamped(minutes)
    }

    private static func applyField(_ todo: TodoItem, accepted: CommandTaskFieldAcceptance,
                                   repository: any TaskRepositoryProtocol, context: ModelContext) throws {
        switch accepted.preview.edit {
        case .move(let day): try repository.moveTodo(id: todo.id, to: day)
        case .priority(let important, let urgent):
            try repository.setPriority(id: todo.id, isImportant: important, isUrgent: urgent)
        case .reminder(let minutes): try repository.setRemind(id: todo.id, minutes: minutes)
        case .due(let minutes): assignDue(todo, minutes: minutes)
        case .completion(let done):
            // 保留旧单目标的已完成短路；重开不触及子项，不调用日用撤销栈。
            guard todo.isDone != done else { return }
            if done { try repository.completeTodo(id: todo.id) }
            else { try repository.toggleTodo(id: todo.id) }
        case .tags, .createTag:
            guard let tags = accepted.preview.tags else { throw TaskFieldCommandIssue.stale }
            _ = try InputTagResolver.apply(tags.actions, creationIDs: accepted.tagCreationIDs, in: context)
            let ids = try tags.final.map { target -> UUID in
                switch target {
                case .existing(let row):
                    guard let id = row.id else { throw TaskFieldCommandIssue.stale }; return id
                case .newName(_, let key):
                    guard let id = accepted.tagCreationIDs[key] else { throw TaskFieldCommandIssue.stale }; return id
                }
            }
            try repository.replaceTagIDs(id: todo.id, tagIDs: TagIDList.encode(ids))
        }
    }
}
