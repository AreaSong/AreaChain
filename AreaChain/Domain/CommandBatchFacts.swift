import Foundation

/// 整份写集随 Run 保留；成员没有独立提交状态，回滚后不能把前半批算作成功。
struct CommandBatchFacts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum State: Equatable { case pending, notSubmitted, noChange, saved, unknown }
    struct External: Equatable {
        let target: CommandObjectReference
        var refreshRequested = false
        var notificationRequested: Bool?
        var calendarRequested: Bool?
        var notification: CommandExternalResult = .unknown
        var calendar: CommandExternalResult = .unknown
    }
    let acceptanceID: UUID
    let targets: CommandDraftTargets
    let impacts: [CommandBatchTargetImpact]
    let writeSet: CommandBatchWriteSet?
    let checkCreationIDs: [CommandObjectReference: UUID]
    var state: State = .pending
    var save = CommandTaskTitleFacts.Call.notCalled
    var rollback = CommandTaskTitleFacts.Call.notCalled
    var publication = CommandTaskTitleFacts.Call.notCalled
    var registrationFailed = false
    var publicationFailed = false
    var conflict = false
    var external: [External] = []
    var changedCount: Int { impacts.filter { !$0.noChange }.count }
    var description: String { "CommandBatchFacts(targets: \(targets.objects.count))" }
    var debugDescription: String { description }

    init(_ accepted: CommandBatchAcceptance) {
        acceptanceID = accepted.id
        targets = accepted.preview.targets
        impacts = accepted.preview.impacts
        writeSet = accepted.preview.writeSet
        checkCreationIDs = accepted.checkCreationIDs
    }

    func receipt(in run: CommandExecutionRun, attempt: CommandAttemptStamp) throws -> (Int, CommandExecutionResult?) {
        guard attempt.execution == run.stamp, attempt.phase == .local, run.permitsMember(attempt.unitID),
              let item = run.snapshot.items.first(where: { $0.id == attempt.unitID }), item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local else {
            throw CommandExecutionError.stale
        }
        guard run.canRecordLocalFacts(attempt, unit: run.units[index], hasPrevious: run.units[index].batch != nil) else {
            throw CommandExecutionError.stale
        }
        try CommandBatchPreview.validate(item, allowingDependencies: run.multiPlan != nil)
        guard item.draft.targets == targets, impacts.map(\.target) == targets.objects, run.outputs[item.id] == nil,
              state == .saved || external.isEmpty else { throw CommandExecutionError.invalidResult }
        if let previous = run.units[index].batch {
            guard previous.acceptanceID == acceptanceID, previous.targets == targets, previous.impacts == impacts,
                  previous.writeSet == writeSet, previous.checkCreationIDs == checkCreationIDs,
                  previous.state == .pending || previous.state == state else { throw CommandExecutionError.invalidResult }
        }
        switch state {
        case .pending: return (index, nil)
        case .noChange:
            guard changedCount == 0, save == .notCalled, rollback == .notCalled, publication == .notCalled,
                  !registrationFailed, !publicationFailed, !conflict else { throw CommandExecutionError.invalidResult }
            return (index, .noChange)
        case .saved:
            guard changedCount > 0, save == .returned else { throw CommandExecutionError.invalidResult }
            return (index, .committed(outputs: [:], external: [.taskPublication]))
        case .unknown: return (index, .commitUnknown)
        case .notSubmitted:
            guard save == .notCalled else { throw CommandExecutionError.invalidResult }
            return (index, .failedWithoutCommit)
        }
    }
}
