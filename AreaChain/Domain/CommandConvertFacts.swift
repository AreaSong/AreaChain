import Foundation

/// 转换没有 noChange：原对象必须仍是活对象；新建与原对象软删只有一次共同保存。
struct CommandConvertFacts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum State: Equatable { case pending, notSubmitted, saved, unknown }
    let acceptanceID: UUID
    let confirmationID: UUID
    let targets: CommandDraftTargets
    let impact: CommandConvertImpact
    /// 接受时分配的新对象身份；保存成功后才可作为回执里的“打开新对象”。
    let created: CommandObjectReference
    var state: State = .pending
    var save = CommandTaskTitleFacts.Call.notCalled
    var rollback = CommandTaskTitleFacts.Call.notCalled
    var publication = CommandTaskTitleFacts.Call.notCalled
    var registrationFailed = false
    var publicationFailed = false
    var conflict = false
    var deletedAt: Date?
    /// 沿原界面实现：只有待办转习惯在保存成功后额外请求一次日历刷新（经注入）。
    var calendarRefreshRequested = false
    var external: [CommandBatchFacts.External] = []
    var description: String { "CommandConvertFacts(\(state))" }
    var debugDescription: String { description }

    init(_ accepted: CommandConvertAcceptance, confirmation: CommandConvertConfirmation) {
        acceptanceID = accepted.id
        confirmationID = confirmation.id
        targets = accepted.preview.targets
        impact = accepted.preview.impact
        created = accepted.created
    }

    func receipt(in run: CommandExecutionRun, attempt: CommandAttemptStamp) throws -> (Int, CommandExecutionResult?) {
        guard attempt.execution == run.stamp, attempt.phase == .local, run.multiPlan == nil, run.permitsMember(attempt.unitID),
              let item = run.snapshot.items.first(where: { $0.id == attempt.unitID }), item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local else {
            throw CommandExecutionError.stale
        }
        guard run.canRecordLocalFacts(attempt, unit: run.units[index], hasPrevious: run.units[index].conversion != nil) else {
            throw CommandExecutionError.stale
        }
        try CommandConvertPreview.validate(item)
        guard item.draft.targets == targets, targets.objects == [impact.target], run.outputs[item.id] == nil,
              state == .saved || (external.isEmpty && deletedAt == nil && !calendarRefreshRequested) else {
            throw CommandExecutionError.invalidResult
        }
        if let previous = run.units[index].conversion {
            guard previous.acceptanceID == acceptanceID, previous.confirmationID == confirmationID,
                  previous.targets == targets, previous.impact == impact, previous.created == created,
                  previous.state == .pending || previous.state == state else { throw CommandExecutionError.invalidResult }
        }
        switch state {
        case .pending: return (index, nil)
        case .saved:
            guard save == .returned, deletedAt != nil else { throw CommandExecutionError.invalidResult }
            return (index, .committed(outputs: [:], external: [.taskPublication]))
        case .unknown: return (index, .commitUnknown)
        case .notSubmitted:
            guard save == .notCalled else { throw CommandExecutionError.invalidResult }
            return (index, .failedWithoutCommit)
        }
    }
}
