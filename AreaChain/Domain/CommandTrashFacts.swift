import Foundation

/// 回收没有 noChange：目标必须仍是活对象，整份固定集合只有一次共同保存。
struct CommandTrashFacts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum State: Equatable { case pending, notSubmitted, saved, unknown }
    let acceptanceID: UUID
    let confirmationID: UUID
    let targets: CommandDraftTargets
    let impacts: [CommandTrashTargetImpact]
    var state: State = .pending
    var save = CommandTaskTitleFacts.Call.notCalled
    var rollback = CommandTaskTitleFacts.Call.notCalled
    var publication = CommandTaskTitleFacts.Call.notCalled
    var registrationFailed = false
    var publicationFailed = false
    var conflict = false
    var deletedAt: [CommandObjectReference: Date] = [:]
    var external: [CommandBatchFacts.External] = []
    var counts: CommandTrashCounts { .init(impacts) }
    var description: String { "CommandTrashFacts(targets: \(targets.objects.count))" }
    var debugDescription: String { description }

    init(_ accepted: CommandTrashAcceptance, confirmation: CommandTrashConfirmation) {
        acceptanceID = accepted.id
        confirmationID = confirmation.id
        targets = accepted.preview.targets
        impacts = accepted.preview.impacts
    }

    func receipt(in run: CommandExecutionRun, attempt: CommandAttemptStamp) throws -> (Int, CommandExecutionResult?) {
        guard attempt.execution == run.stamp, attempt.phase == .local, run.multiPlan == nil, run.permitsMember(attempt.unitID),
              let item = run.snapshot.items.first(where: { $0.id == attempt.unitID }), item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local else {
            throw CommandExecutionError.stale
        }
        guard run.canRecordLocalFacts(attempt, unit: run.units[index], hasPrevious: run.units[index].trash != nil) else {
            throw CommandExecutionError.stale
        }
        try CommandTrashPreview.validate(item)
        guard item.draft.targets == targets, impacts.map(\.target) == targets.objects, run.outputs[item.id] == nil,
              state == .saved || (external.isEmpty && deletedAt.isEmpty) else { throw CommandExecutionError.invalidResult }
        if let previous = run.units[index].trash {
            guard previous.acceptanceID == acceptanceID, previous.confirmationID == confirmationID,
                  previous.targets == targets, previous.impacts == impacts,
                  previous.state == .pending || previous.state == state else { throw CommandExecutionError.invalidResult }
        }
        switch state {
        case .pending: return (index, nil)
        case .saved:
            guard save == .returned, Set(deletedAt.keys) == Set(targets.objects) else { throw CommandExecutionError.invalidResult }
            return (index, .committed(outputs: [:], external: [.taskPublication]))
        case .unknown: return (index, .commitUnknown)
        case .notSubmitted:
            guard save == .notCalled else { throw CommandExecutionError.invalidResult }
            return (index, .failedWithoutCommit)
        }
    }
}
