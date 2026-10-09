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
