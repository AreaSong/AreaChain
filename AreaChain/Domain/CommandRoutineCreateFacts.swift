import Foundation

/// 类型化新建事实不进入 Run.outputs；保留原身份也不授权依赖执行或重放。
struct CommandRoutineCreateFacts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum State: Equatable { case pending, notSubmitted, saved, unknown }
    let creationID: UUID
    var candidateID: UUID?
    var savedID: UUID?
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
        guard attempt.execution == run.stamp, attempt.phase == .local, run.snapshot.items.count == 1,
              let item = run.snapshot.items.first, item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local,
              run.outputs.isEmpty else { throw CommandExecutionError.stale }
        try CommandRoutineCreatePreview.validate(item)
        guard candidateID == nil || candidateID == creationID,
              state == .saved || (savedID == nil && savedRoutine == nil && savedTagEffects == nil) else {
            throw CommandExecutionError.invalidResult
        }
        if let previous = run.units[index].routineCreation {
            guard previous.creationID == creationID, previous.state == .pending || previous.state == state else {
                throw CommandExecutionError.invalidResult
            }
        }
        switch state {
        case .pending: return (index, nil)
        case .saved:
            guard savedID == creationID, save == .returned, savedRoutine == nil || savedRoutine?.id == creationID else {
                throw CommandExecutionError.invalidResult
            }
            return (index, .committed(outputs: [:], external: [.taskPublication, .notification, .calendar]))
        case .unknown: return (index, .commitUnknown)
        case .notSubmitted:
            guard save == .notCalled else { throw CommandExecutionError.invalidResult }
            return (index, .failedWithoutCommit)
        }
    }
}
