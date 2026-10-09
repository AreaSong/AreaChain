import Foundation
import SwiftData

/// 习惯标题与字段仍走原仓储；命令只增加严格接受值，旧 UI 保持同值保存与解析语义。
@MainActor enum RoutineMutationService {
    @MainActor struct Dependencies {
        var repository: (ModelContext) -> any RoutineRepositoryProtocol
        var transaction: ModelChanges.Boundary
        var registerLocalModification: (UUID) throws -> Void
        var requestReminderAccessIfNeeded: (Int?) -> Void
        var validateBeforeTransaction: () throws -> Void = {}
    }

    @MainActor final class Modification {
        let object: CommandObjectReference
        fileprivate(set) var transaction: ModelChanges.CommitFacts?
        fileprivate(set) var registrationFailed = false
        fileprivate(set) var savedTagEffects: [CommandTaskTagAssociation.Effect]?
        fileprivate(set) var savedTagIDs: [UUID]?
        fileprivate(set) var savedValues: [RoutineField: RoutineFieldValue]?
        fileprivate(set) var reminderRequest = ModelChanges.CallFact.notCalled
        /// 同步事务调用正常返回；嵌套时仅表示工作已接受，不证明外层已经保存。
        fileprivate(set) var callSucceeded = false
        fileprivate var savedLocally = false
        fileprivate var rejected = false
        init(_ routine: DailyRoutine, object: CommandObjectReference? = nil) { self.object = object ?? .init(type: .routine, id: routine.id) }
        var state: CommandRoutineFacts.State {
            if savedLocally { return .saved }
            if transaction?.save == .called || transaction?.phase == .recoveryFailed { return .unknown }
            if rejected || transaction?.phase == .rolledBack { return .notSubmitted }
            return .pending
        }
        var saved: Bool { state == .saved }
    }

    static func editTitle(_ routine: DailyRoutine, rawInput: String, in context: ModelContext,
                          dependencies: Dependencies) -> Modification {
        guard let title = TaskTitleEdit(rawInput) else {
            let result = Modification(routine)
            result.rejected = true
            return result
        }
        return mutate(routine, edit: .title(title), accepted: nil, in: context, dependencies: dependencies)
    }

    static func edit(_ routine: DailyRoutine, accepted: CommandRoutineAcceptance, in context: ModelContext,
                     dependencies: Dependencies) -> Modification {
        mutate(routine, edit: accepted.preview.edit, accepted: accepted, in: context, dependencies: dependencies)
    }

    private static func mutate(_ routine: DailyRoutine, edit: CommandRoutineEdit, accepted: CommandRoutineAcceptance?,
                               in context: ModelContext, dependencies: Dependencies) -> Modification {
        let result = Modification(routine, object: accepted?.object)
        do {
            let repository = dependencies.repository(context)
            if let accepted {
                guard accepted.object == result.object, accepted.preview.record == routine.persistentModelID,
                      routine.modelContext === context, repository.routineMutationContext === context else {
                    throw RoutineCommandIssue.invalidRepository
                }
            }
            try dependencies.validateBeforeTransaction()
            try ModelChanges.transaction(in: context, boundary: dependencies.transaction, observe: { result.transaction = $0 }) {
                try apply(routine, edit: edit, accepted: accepted, repository: repository, context: context)
                register(result, routine: routine, edit: edit, accepted: accepted, context: context, dependencies: dependencies)
            }
            result.callSucceeded = true
        } catch {
            result.rejected = true
            ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
        }
        return result
    }

    private static func apply(_ routine: DailyRoutine, edit: CommandRoutineEdit, accepted: CommandRoutineAcceptance?,
                              repository: any RoutineRepositoryProtocol, context: ModelContext) throws {
        switch edit {
        case .enabled, .occurrence:
            guard let accepted else { throw RoutineCommandIssue.stale }
            try repository.applyRoutineState(accepted)
        case .title(let title):
            try repository.updateRoutine(id: routine.id, title: title.title, notes: title.notes)
            if let priority = title.priority {
                try repository.setPriority(id: routine.id, isImportant: priority.isImportant, isUrgent: priority.isUrgent)
            }
            if let minutes = title.remindMinutes { try repository.setRemind(id: routine.id, minutes: minutes) }
            let tags = try accepted.map { try applyTags($0, in: context) }
                ?? InputTagResolver.merging(title.tagNames, into: routine.tagIDs, in: context)
            try repository.replaceTagIDs(id: routine.id, tagIDs: tags)
        case .weekdays(let mask): try repository.setWeekdayMask(id: routine.id, mask: mask)
        case .reminder(let minutes): try repository.setRemind(id: routine.id, minutes: minutes)
        case .priority(let important, let urgent):
            try repository.setPriority(id: routine.id, isImportant: important, isUrgent: urgent)
        case .tags:
            guard let accepted else { throw RoutineCommandIssue.stale }
            try repository.replaceTagIDs(id: routine.id, tagIDs: applyTags(accepted, in: context))
        }
    }

    private static func applyTags(_ accepted: CommandRoutineAcceptance, in context: ModelContext) throws -> String {
        guard let tags = accepted.preview.tags else { throw RoutineCommandIssue.stale }
        _ = try InputTagResolver.apply(tags.actions, creationIDs: accepted.tagCreationIDs, in: context)
        let ids = try tags.final.map { target -> UUID in
            switch target {
            case .existing(let row):
                guard let id = row.id else { throw RoutineCommandIssue.stale }; return id
            case .newName(_, let key):
                guard let id = accepted.tagCreationIDs[key] else { throw RoutineCommandIssue.stale }; return id
            }
        }
        return TagIDList.encode(ids)
    }

    private static func register(_ result: Modification, routine: DailyRoutine, edit: CommandRoutineEdit,
                                 accepted: CommandRoutineAcceptance?, context: ModelContext, dependencies: Dependencies) {
        ModelChanges.afterCommit(in: context) {
            result.savedLocally = true
            result.savedValues = RoutineCommandReader.values(routine, edit: edit)
            if let tags = accepted?.preview.tags {
                result.savedTagIDs = TagIDList.parse(routine.tagIDs)
                result.savedTagEffects = tags.actions.final.filter {
                    $0.effect != .associateLive || !tags.original.contains($0.target)
                }.map(\.effect)
            }
            do { try dependencies.registerLocalModification(routine.id) }
            catch {
                result.registrationFailed = true
                ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
            }
        }
        ModelChanges.afterPublication(in: context) {
            let minutes: Int?
            switch edit {
            case .title(let title): minutes = title.remindMinutes
            case .reminder(let reminder): minutes = reminder
            default: return
            }
            if minutes != nil { result.reminderRequest = .called }
            dependencies.requestReminderAccessIfNeeded(minutes)
            if minutes != nil { result.reminderRequest = .returned }
        }
    }
}
