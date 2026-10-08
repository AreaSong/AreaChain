import Foundation
import SwiftData

extension RoutineMutationService {
    @MainActor final class CreationResult {
        let creationID: UUID
        fileprivate(set) var candidateID: UUID?
        fileprivate(set) var savedID: UUID?
        fileprivate(set) var transaction: ModelChanges.CommitFacts?
        fileprivate(set) var registrationFailed = false
        fileprivate(set) var reminderRequest = ModelChanges.CallFact.notCalled
        fileprivate(set) var savedRoutine: RoutineSnapshot?
        fileprivate(set) var savedTagEffects: [CommandTaskTagAssociation.Effect]?
        fileprivate var rejected = false
        init(_ id: UUID) { creationID = id }
        var state: CommandRoutineCreateFacts.State {
            if savedID != nil { return .saved }
            if transaction?.save == .called || transaction?.phase == .recoveryFailed { return .unknown }
            if rejected || transaction?.phase == .rolledBack { return .notSubmitted }
            return .pending
        }
    }

    /// 直接采用已接受的字段；原两种新增 UI 保留自己的解析与 Bool 时序。
    static func create(_ accepted: CommandRoutineCreateAcceptance, in context: ModelContext,
                       clock: RoutineCommandEnvironment.Creation, dependencies: Dependencies) -> CreationResult {
        let result = CreationResult(accepted.creationID)
        do {
            let repository = dependencies.repository(context)
            guard repository.routineMutationContext === context else { throw RoutineCommandIssue.invalidRepository }
            try dependencies.validateBeforeTransaction()
            try ModelChanges.transaction(in: context, boundary: dependencies.transaction, observe: { result.transaction = $0 }) {
                let params = try creationParameters(accepted, context: context, clock: clock)
                let routine = try repository.addRoutine(params)
                guard routine.id == accepted.creationID, routine.modelContext === context, routine.checks.isEmpty else {
                    throw RoutineCreateIssue.identityCollision
                }
                result.candidateID = routine.id
                registerCreation(result, routine: routine, accepted: accepted, context: context, dependencies: dependencies)
            }
        } catch {
            result.rejected = true
            ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
        }
        return result
    }

    private static func creationParameters(_ accepted: CommandRoutineCreateAcceptance, context: ModelContext,
                                            clock: RoutineCommandEnvironment.Creation) throws -> CreateRoutineParams {
        let preview = accepted.preview
        let fields = preview.composition
        guard preview.canAccept, let flags = fields.priorityFlags else { throw RoutineCreateIssue.invalidInput }
        let now = clock.now()
        guard DayKey.from(now, calendar: clock.calendar) == preview.createdDayKey else { throw RoutineCreateIssue.dateChanged }
        let tags = try InputTagResolver.apply(fields.tags, creationIDs: accepted.tagCreationIDs, in: context)
        return .init(title: fields.title, sortOrder: preview.sortOrder, weekdayMask: preview.weekdayMask,
                     remindMinutes: fields.reminder.value, tagIDs: tags, isImportant: flags.isImportant, isUrgent: flags.isUrgent,
                     createdDayKey: preview.createdDayKey, creationID: accepted.creationID, createdAt: now)
    }

    private static func registerCreation(_ result: CreationResult, routine: DailyRoutine,
                                         accepted: CommandRoutineCreateAcceptance, context: ModelContext, dependencies: Dependencies) {
        ModelChanges.afterCommit(in: context) {
            result.savedID = routine.id
            result.savedRoutine = routine.snapshot
            result.savedTagEffects = accepted.preview.composition.tags.final.map(\.effect)
            do { try dependencies.registerLocalModification(routine.id) }
            catch {
                result.registrationFailed = true
                ModelChanges.reportFailure(error, in: context, boundary: dependencies.transaction)
            }
        }
        ModelChanges.afterPublication(in: context) {
            guard let minutes = routine.remindMinutes else { return }
            result.reminderRequest = .called
            dependencies.requestReminderAccessIfNeeded(minutes)
            result.reminderRequest = .returned
        }
    }
}
