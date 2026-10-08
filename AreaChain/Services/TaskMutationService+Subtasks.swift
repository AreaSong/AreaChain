import Foundation
import SwiftData

extension TaskMutationService {
    @MainActor struct SubtaskDependencies {
        var repository: (ModelContext) -> any TaskRepositoryProtocol
        var transaction: ModelChanges.Boundary
        var registerLocalModification: (UUID) throws -> Void
        var validateBeforeTransaction: () throws -> Void = {}
    }

    @MainActor final class SubtaskModification {
        let accepted: CommandSubtaskAcceptance
        fileprivate(set) var transaction: ModelChanges.CommitFacts?
        fileprivate(set) var registrationFailed = false
        fileprivate(set) var savedTagEffects: [CommandTaskTagAssociation.Effect]?
        fileprivate(set) var savedTagIDs: [UUID]?
        fileprivate(set) var savedTitle: String?
        fileprivate(set) var savedCompletion: Bool?
        fileprivate var savedLocally = false
        fileprivate var rejected = false
        init(_ accepted: CommandSubtaskAcceptance) { self.accepted = accepted }
        var state: CommandSubtaskFacts.State {
            if savedLocally { return .saved }
            if transaction?.save == .called || transaction?.phase == .recoveryFailed { return .unknown }
            if rejected || transaction?.phase == .rolledBack { return .notSubmitted }
            return .pending
        }
    }

    /// 子项与所需标签共用原最外层事务；原行/检查器的撤销与提交行为仍由旧入口拥有。
    static func mutateSubtask(_ accepted: CommandSubtaskAcceptance, in context: ModelContext,
                              dependencies: SubtaskDependencies) -> SubtaskModification {
        let result = SubtaskModification(accepted)
        do {
            let repository = dependencies.repository(context)
            guard repository.subtaskMutationContext === context else { throw SubtaskCommandIssue.invalidFamily }
            try dependencies.validateBeforeTransaction()
            try ModelChanges.transaction(in: context, boundary: dependencies.transaction,
                                         observe: { result.transaction = $0 }) {
                let subtask = try applySubtask(accepted, repository: repository, context: context)
                ModelChanges.afterCommit(in: context) {
                    result.savedLocally = true
                    result.savedTagEffects = accepted.preview.tags.map { tags in
                        tags.actions.final.filter { $0.effect != .associateLive || !tags.original.contains($0.target) }.map(\.effect)
                    }
                    if accepted.preview.tags != nil { result.savedTagIDs = TagIDList.parse(subtask.tagIDs) }
                    switch accepted.preview.input.edit {
                    case .create, .title: result.savedTitle = subtask.title
                    case .completion: result.savedCompletion = subtask.isDone
                    case .tags: break
                    }
                    do { try dependencies.registerLocalModification(subtask.id) }
                    catch {
                        result.registrationFailed = true
                        ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
                    }
                }
            }
        } catch {
            result.rejected = true
            ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
        }
        return result
    }

    private static func applySubtask(_ accepted: CommandSubtaskAcceptance, repository: any TaskRepositoryProtocol,
                                     context: ModelContext) throws -> SubtaskItem {
        let tags = try subtaskTags(accepted, in: context)
        let id = accepted.object.id
        let subtask: SubtaskItem
        switch accepted.preview.input.edit {
        case .create(let edit):
            subtask = try repository.addSubtask(.init(parentID: accepted.preview.parent.id, title: edit.title,
                                                      tagIDs: tags ?? "", creationID: id))
        case .title(let edit):
            guard let tags else { throw SubtaskCommandIssue.stale }
            try repository.updateSubtask(id: id, update: .title(edit.title, tagIDs: tags))
            subtask = try TaskFamilyCommandIdentity.subtask(id, in: context)
        case .completion(let enabled):
            try repository.updateSubtask(id: id, update: .completion(enabled))
            subtask = try TaskFamilyCommandIdentity.subtask(id, in: context)
        case .tags:
            guard let tags else { throw SubtaskCommandIssue.stale }
            try repository.updateSubtask(id: id, update: .tags(tags))
            subtask = try TaskFamilyCommandIdentity.subtask(id, in: context)
        }
        guard subtask.id == id, subtask.modelContext === context, subtask.todo?.id == accepted.preview.parent.id,
              subtask.todo.map(ObjectIdentifier.init) == accepted.preview.parent.record else { throw SubtaskCommandIssue.invalidFamily }
        return subtask
    }

    private static func subtaskTags(_ accepted: CommandSubtaskAcceptance, in context: ModelContext) throws -> String? {
        guard let tags = accepted.preview.tags else { return nil }
        _ = try InputTagResolver.apply(tags.actions, creationIDs: accepted.tagCreationIDs, in: context)
        let ids = try tags.final.map { target -> UUID in
            switch target {
            case .existing(let row):
                guard let id = row.id else { throw SubtaskCommandIssue.stale }; return id
            case .newName(_, let key):
                guard let id = accepted.tagCreationIDs[key] else { throw SubtaskCommandIssue.stale }; return id
            }
        }
        return TagIDList.encode(ids)
    }
}
