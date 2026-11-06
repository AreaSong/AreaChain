import Foundation
import SwiftData

extension TaskMutationService {
    @MainActor
    struct TitleDependencies {
        var repository: @MainActor (ModelContext) -> any TaskRepositoryProtocol
        var transaction: ModelChanges.Boundary
        var registerLocalModification: @MainActor (UUID) throws -> Void
        var requestReminderAccessIfNeeded: @MainActor (Int?) -> Void
        var validateBeforeTransaction: @MainActor () throws -> Void = {}

        static var production: Self {
            let shared = Dependencies.production
            return Self(repository: shared.repository, transaction: shared.transaction,
                        registerLocalModification: { _ in },
                        requestReminderAccessIfNeeded: shared.requestReminderAccessIfNeeded)
        }
    }

    /// targetID 是被修改对象，不是创建候选或命令输出。只有 saved 才确认最外层 save 已返回。
    @MainActor
    final class TitleModification {
        let targetID: UUID
        fileprivate(set) var transaction: ModelChanges.CommitFacts?
        fileprivate(set) var registrationFailed = false
        fileprivate(set) var reminderRequest: ModelChanges.CallFact = .notCalled
        fileprivate var savedLocally = false
        fileprivate var rejected = false
        fileprivate var emptyInput = false

        init(targetID: UUID) { self.targetID = targetID }

        var state: LocalState {
            if emptyInput { return .emptyInput }
            if savedLocally { return .saved }
            if transaction?.save == .called || transaction?.phase == .recoveryFailed { return .commitUnknown }
            if rejected || transaction?.phase == .rolledBack { return .notSubmitted }
            return .pending
        }
        var saved: Bool { state == .saved }
    }

    /// 兼容旧 UI：保留同值保存、旧标签资格与非空派生备注。
    static func editTitle(_ todo: TodoItem, rawInput: String, in context: ModelContext,
                          dependencies: TitleDependencies) -> TitleModification {
        let result = TitleModification(targetID: todo.id)
        guard let edit = TaskTitleEdit(rawInput) else { result.emptyInput = true; return result }
        return editTitle(todo, edit: edit, in: context, dependencies: dependencies) {
            InputAttachmentResolver.linkIfPresent(in: rawInput, ownerKind: .todo, ownerID: todo.id, context: context)
            return try InputTagResolver.mergingForTask(edit.tagNames, into: todo.tagIDs, in: context).encoded
        }
    }

    private static func editTitle(_ todo: TodoItem, edit: TaskTitleEdit, in context: ModelContext,
                                  dependencies: TitleDependencies,
                                  tags: () throws -> String) -> TitleModification {
        let result = TitleModification(targetID: todo.id)
        do {
            try dependencies.validateBeforeTransaction()
            try ModelChanges.transaction(in: context, boundary: dependencies.transaction,
                                         observe: { result.transaction = $0 }) {
                let repo = dependencies.repository(context)
                try repo.updateTodo(id: todo.id, title: edit.title, notes: edit.notes)
                if let priority = edit.priority {
                    try repo.setPriority(id: todo.id, isImportant: priority.isImportant, isUrgent: priority.isUrgent)
                }
                if let minutes = edit.remindMinutes { try repo.setRemind(id: todo.id, minutes: minutes) }
                let merged = try tags()
                try repo.replaceTagIDs(id: todo.id, tagIDs: merged)
                registerTitleCompletion(result, minutes: edit.remindMinutes, context: context,
                                        dependencies: dependencies)
            }
        } catch {
            result.rejected = true
            ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
        }
        return result
    }

    private static func registerTitleCompletion(_ result: TitleModification, minutes: Int?, context: ModelContext,
                                                dependencies: TitleDependencies) {
        ModelChanges.afterCommit(in: context) {
            result.savedLocally = true
            do { try dependencies.registerLocalModification(result.targetID) }
            catch {
                result.registrationFailed = true
                ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
            }
        }
        ModelChanges.afterPublication(in: context) {
            if minutes != nil { result.reminderRequest = .called }
            dependencies.requestReminderAccessIfNeeded(minutes)
            if minutes != nil { result.reminderRequest = .returned }
        }
    }
}
