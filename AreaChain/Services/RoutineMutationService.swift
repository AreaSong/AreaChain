import Foundation
import SwiftData

/// 习惯标题仍走原仓储；保留同值保存与解析语义。
@MainActor enum RoutineMutationService {
    @MainActor struct Dependencies {
        var repository: (ModelContext) -> any RoutineRepositoryProtocol
        var transaction: ModelChanges.Boundary
        var registerLocalModification: (UUID) throws -> Void
        var requestReminderAccessIfNeeded: (Int?) -> Void
        var validateBeforeTransaction: () throws -> Void = {}
    }

    enum State: Equatable {
        case pending, notSubmitted, unknown, saved
    }

    @MainActor final class Modification {
        let object: CommandObjectReference
        fileprivate(set) var transaction: ModelChanges.CommitFacts?
        fileprivate(set) var registrationFailed = false
        fileprivate(set) var reminderRequest = ModelChanges.CallFact.notCalled
        /// 同步事务调用正常返回；嵌套时仅表示工作已接受，不证明外层已经保存。
        fileprivate(set) var callSucceeded = false
        fileprivate var savedLocally = false
        fileprivate var rejected = false
        init(_ routine: DailyRoutine, object: CommandObjectReference? = nil) {
            self.object = object ?? .init(type: .routine, id: routine.id)
        }
        var state: State {
            if savedLocally { return .saved }
            if transaction?.save == .called || transaction?.phase == .recoveryFailed { return .unknown }
            if rejected || transaction?.phase == .rolledBack { return .notSubmitted }
            return .pending
        }
        var saved: Bool { state == .saved }
    }

    static func editTitle(_ routine: DailyRoutine, rawInput: String, in context: ModelContext,
                          dependencies: Dependencies) -> Modification {
        let result = Modification(routine)
        guard let title = TaskTitleEdit(rawInput) else {
            result.rejected = true
            return result
        }
        do {
            let repository = dependencies.repository(context)
            try dependencies.validateBeforeTransaction()
            try ModelChanges.transaction(in: context, boundary: dependencies.transaction, observe: { result.transaction = $0 }) {
                try repository.updateRoutine(id: routine.id, title: title.title, notes: title.notes)
                if let priority = title.priority {
                    try repository.setPriority(id: routine.id, isImportant: priority.isImportant, isUrgent: priority.isUrgent)
                }
                if let minutes = title.remindMinutes { try repository.setRemind(id: routine.id, minutes: minutes) }
                let tags = try InputTagResolver.mergingForTask(title.tagNames, into: routine.tagIDs, in: context).encoded
                try repository.replaceTagIDs(id: routine.id, tagIDs: tags)
                ModelChanges.afterCommit(in: context) {
                    result.savedLocally = true
                    do { try dependencies.registerLocalModification(routine.id) }
                    catch {
                        result.registrationFailed = true
                        ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
                    }
                }
                ModelChanges.afterPublication(in: context) {
                    if let minutes = title.remindMinutes {
                        result.reminderRequest = .called
                        dependencies.requestReminderAccessIfNeeded(minutes)
                        result.reminderRequest = .returned
                    }
                }
            }
            result.callSucceeded = true
        } catch {
            result.rejected = true
            ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
        }
        return result
    }
}
