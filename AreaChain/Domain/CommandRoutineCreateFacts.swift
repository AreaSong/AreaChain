import Foundation
import SwiftData

/// 原事实保留创建身份；显式 P-M2 才发布类型化输出，外部步骤仍单独判断。
struct CommandRoutineCreateFacts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum State: Equatable { case pending, notSubmitted, saved, unknown }
    let creationID: UUID
    var candidateID: UUID?
    var savedID: UUID?
    var savedRecord: PersistentIdentifier?
    var state: State = .pending
    var save = CommandTaskTitleFacts.Call.notCalled
    var rollback = CommandTaskTitleFacts.Call.notCalled
    var publication = CommandTaskTitleFacts.Call.notCalled
    var registrationFailed = false
    var publicationFailed = false
    var refreshRequested = false
    var notificationRequested: Bool?
    var calendarRequested: Bool?
    var authorizationRequest = CommandTaskTitleFacts.Call.notCalled
    var authorizationResult = CommandTaskTitleFacts.Authorization.unknown
    var savedTagEffects: [CommandTaskTagAssociation.Effect]?
    var savedRoutine: RoutineSnapshot?
    var createdObject: CommandObjectReference? {
        state == .saved && savedID == creationID && save == .returned ? .init(type: .routine, id: creationID) : nil
    }
    var description: String { "CommandRoutineCreateFacts(redacted)" }
    var debugDescription: String { description }

    func receipt(in run: CommandExecutionRun, attempt: CommandAttemptStamp) throws -> (Int, CommandExecutionResult?) {
        guard attempt.execution == run.stamp, attempt.phase == .local, run.permitsMember(attempt.unitID),
              let item = run.snapshot.items.first(where: { $0.id == attempt.unitID }), item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local,
              run.outputs[item.id] == nil
                || run.outputs[item.id] == createdObject && run.units[index].routineCreation?.state == .saved else { throw CommandExecutionError.stale }
        guard run.canRecordLocalFacts(attempt, unit: run.units[index], hasPrevious: run.units[index].routineCreation != nil) else {
            throw CommandExecutionError.stale
        }
        try CommandRoutineCreatePreview.validate(item, allowingDependencies: run.multiPlan != nil)
        guard candidateID == nil || candidateID == creationID,
              state == .saved || (savedID == nil && savedRoutine == nil && savedTagEffects == nil) else {
            throw CommandExecutionError.invalidResult
        }
        if let previous = run.units[index].routineCreation {
            guard previous.creationID == creationID, previous.savedRecord == nil || previous.savedRecord == savedRecord,
                  previous.state == .pending || previous.state == state else {
                throw CommandExecutionError.invalidResult
            }
        }
        switch state {
        case .pending: return (index, nil)
        case .saved:
            guard savedID == creationID, save == .returned, savedRoutine == nil || savedRoutine?.id == creationID else {
                throw CommandExecutionError.invalidResult
            }
            let output: [UUID: CommandObjectReference] = run.multiPlan?.outputCapability == .typedCreation
                ? [item.id: .init(type: .routine, id: creationID)] : [:]
            return (index, .committed(outputs: output, external: [.taskPublication, .notification, .calendar]))
        case .unknown: return (index, .commitUnknown)
        case .notSubmitted:
            guard save == .notCalled else { throw CommandExecutionError.invalidResult }
            return (index, .failedWithoutCommit)
        }
    }
}
