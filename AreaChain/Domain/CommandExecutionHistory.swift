import Foundation

/// 每次新尝试开始前保存上一尝试的完整事实；历史不是可重新提交的草稿。
struct CommandAttemptRecord: Equatable {
    let number: UInt64
    let phase: CommandExecutionPhase
    let state: CommandOperationState
    let local: CommandLocalCommit
    let receipt: CommandExecutionReceipt?
    let validationFailedBeforeInvocation: Bool
    let effects: [CommandExternalEffect: CommandExternalResult]
    let taskCreation: CommandTaskCreateFacts?
    let taskTitle: CommandTaskTitleFacts?
    let taskField: CommandTaskFieldFacts?
    let subtask: CommandSubtaskFacts?
    let routine: CommandRoutineFacts?
    let routineCreation: CommandRoutineCreateFacts?
    let batch: CommandBatchFacts?
    let preferenceWrite: CommandPreferenceWriteFacts?
    let preferenceGroupCommit: CommandPreferenceGroupCommit?
    let preferencePresentation: CommandPreferencePresentation?
    let preferenceGroupPresentation: CommandPreferenceGroupPresentation?
    let preferenceVerification: CommandExecutionReceipt?
}

extension CommandExecutionUnit {
    var hasConfirmedLocalSuccess: Bool {
        guard state == .succeeded, local != .unknown, effects.values.allSatisfy({ $0 == .succeeded }) else { return false }
        if local == .committed {
            if let facts = taskCreation { return facts.state == .saved && facts.save == .returned }
            if let facts = taskTitle { return facts.state == .saved && facts.save == .returned }
            if let facts = taskField { return facts.state == .saved && facts.save == .returned }
            if let facts = subtask { return facts.state == .saved && facts.save == .returned }
            if let facts = routine { return facts.state == .saved && facts.save == .returned }
            if let facts = routineCreation { return facts.state == .saved && facts.save == .returned }
            if let facts = batch { return facts.state == .saved && facts.save == .returned }
            if let facts = preferenceWrite { return facts.write == .returned && facts.readback == .matches }
            if case .committed = preferenceGroupCommit { return true }
            return false
        }
        return taskTitle?.state == .noChange || taskField?.state == .noChange || subtask?.state == .noChange
            || routine?.state == .noChange || batch?.state == .noChange || preferenceGroupCommit == .noChange
            || receipt?.result == .noChange
    }

    mutating func archiveAttempt() {
        guard attempt > 0, history.last?.number != attempt else { return }
        history.append(.init(number: attempt, phase: currentPhase, state: state, local: local, receipt: receipt,
            validationFailedBeforeInvocation: validationFailedBeforeInvocation, effects: effects,
            taskCreation: taskCreation, taskTitle: taskTitle, taskField: taskField,
            subtask: subtask, routine: routine, routineCreation: routineCreation, batch: batch,
            preferenceWrite: preferenceWrite, preferenceGroupCommit: preferenceGroupCommit,
            preferencePresentation: preferencePresentation, preferenceGroupPresentation: preferenceGroupPresentation,
            preferenceVerification: preferenceVerification))
    }

    var hasSafeLocalFailure: Bool {
        guard local == .notSubmitted, [.failed, .conflict, .notExecuted].contains(state) else { return false }
        if validationFailedBeforeInvocation { return true }
        if let facts = taskCreation { return facts.state == .notSubmitted && facts.save == .notCalled
            && (facts.candidateID == nil || facts.rollback == .returned) }
        if let facts = taskTitle { return facts.state == .notSubmitted && facts.save == .notCalled }
        if let facts = taskField { return facts.state == .notSubmitted && facts.save == .notCalled }
        if let facts = subtask { return facts.state == .notSubmitted && facts.save == .notCalled }
        if let facts = routine { return facts.state == .notSubmitted && facts.save == .notCalled }
        if let facts = routineCreation { return facts.state == .notSubmitted && facts.save == .notCalled }
        if let facts = batch { return facts.state == .notSubmitted && facts.save == .notCalled }
        if let facts = preferenceWrite { return facts.write == .notCalled }
        return preferenceGroupCommit == .notCommitted
    }

    mutating func clearLocalAttemptFacts() {
        taskCreation = nil
        taskTitle = nil
        taskField = nil
        subtask = nil
        routine = nil
        routineCreation = nil
        batch = nil
        preferenceWrite = nil
        preferenceGroupCommit = nil
        preferencePresentation = nil
        preferenceGroupPresentation = nil
        preferenceVerification = nil
        conflicts = []
        validationFailedBeforeInvocation = false
    }
}

/// 只由原协调者在原尝试具有确定未提交事实时签发；接受仍需再次真实读取。
struct CommandMultiPlanRetryPermit: Equatable {
    let attempt: CommandAttemptStamp
    let item: CommandPlanItemStamp
    let oldAcceptanceID: UUID
    fileprivate init(attempt: CommandAttemptStamp, item: CommandPlanItemStamp, oldAcceptanceID: UUID) {
        self.attempt = attempt
        self.item = item
        self.oldAcceptanceID = oldAcceptanceID
    }
    func matches(item: CommandPlanItemStamp, acceptance: UUID) -> Bool {
        self.item == item && oldAcceptanceID == acceptance
    }
}

extension CommandHandoffCoordinator {
    /// 修订仅重用原链中确定未提交的接受身份；新 item stamp 不会给其他运行的接受续期。
    func revisionAcceptancePermit(item: CommandPlanItem, assemblyID: UUID,
                                  expecting lease: CommandHostLease) throws -> CommandMultiPlanRetryPermit? {
        guard item.executionOrigin?.returnID != nil else { return nil }
        try validate(lease)
        let session = try host(lease.ownership.hostID).session
        let plan = session.execution?.snapshot.stamp ?? session.plan.stamp
        try validatePlanOrigins([item], plan: plan, assemblyID: assemblyID, owner: lease.ownership)
        let acceptance: UUID?
        switch item.draft.commandID.rawValue {
        case "todo.create": acceptance = taskCreations.preparations[item.draft.id]?.id
        case "todo.title": acceptance = taskTitles.acceptances[item.draft.id]?.id
        case "subtask.create", "subtask.title", "subtask.completion", "subtask.tags": acceptance = subtasks.acceptances[item.draft.id]?.id
        case "routine.create": acceptance = taskCreations.routinePreparations[item.draft.id]?.id
        default:
            if TaskFieldEdit.commands.contains(item.draft.commandID.rawValue) { acceptance = taskFields.acceptances[item.draft.id]?.id }
            else if CommandRoutineEdit.allCommands.contains(item.draft.commandID.rawValue) { acceptance = routines.acceptances[item.draft.id]?.id }
            else { acceptance = batches.acceptances[item.draft.id]?.id }
        }
        guard let acceptance else { return nil }
        for record in revisionChain(lease.ownership.hostID) {
            guard record.assemblyID == assemblyID,
                  let unit = record.run.units.first(where: { $0.members.contains(item.id) }), unit.hasSafeLocalFailure,
                  let authorization = multiPlans.authorizations.values.first(where: {
                      $0.attempt.execution == record.run.stamp && $0.itemID == item.id && $0.acceptanceID == acceptance
                  }) else { continue }
            return .init(attempt: authorization.attempt, item: item.stamp, oldAcceptanceID: acceptance)
        }
        return nil
    }

    func multiPlanRetryPermit(_ attempt: CommandAttemptStamp, assemblyID: UUID,
                             expecting lease: CommandHostLease) throws -> CommandMultiPlanRetryPermit {
        try validate(lease)
        let host = try host(lease.ownership.hostID)
        guard let run = host.session.execution, run.stamp == attempt.execution,
              !run.hasUnknownCommit, !run.isBusy, !hasInvocation(lease.ownership),
              multiPlans.assemblies[run.stamp] == assemblyID, run.attempt(attempt.unitID) == attempt,
              let unit = run.units.first(where: { $0.id == attempt.unitID }), unit.hasSafeLocalFailure,
              let item = run.snapshot.items.first(where: { unit.members.contains($0.id) }) else {
            throw CommandMultiPlanIssue.recoveryUnavailable
        }
        let authorization = multiPlans.authorizations[attempt]
        guard authorization != nil || unit.validationFailedBeforeInvocation else { throw CommandMultiPlanIssue.recoveryUnavailable }
        return .init(attempt: attempt, item: item.stamp, oldAcceptanceID: authorization?.acceptanceID ?? UUID())
    }
}
