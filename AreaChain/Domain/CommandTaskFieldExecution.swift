import Foundation

extension CommandHandoffCoordinator {
    func withTaskFieldPreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        taskFields.preparing[lease.ownership.hostID] = lease.ownership
        defer { taskFields.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    func taskFieldAcceptance(_ request: TaskTitleCommandRequest) throws -> CommandTaskFieldAcceptance {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              run.units.count == 1, run.units[0].state == .running, run.units[0].local == .notSubmitted,
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let item = run.snapshot.items.first,
              let accepted = taskFields.acceptances[item.draft.id] else { throw TaskFieldCommandIssue.stale }
        _ = try accepted.preview.frozenItem(in: run, lease: request.lease)
        return accepted
    }

    func claimTaskField(_ request: TaskTitleCommandRequest) throws -> CommandRuntimeInvocation {
        let accepted = try taskFieldAcceptance(request)
        guard !taskFields.wasInvoked(accepted.id) else { throw TaskFieldCommandIssue.alreadyInvoked }
        let invocation = try claimRuntimeInvocation(request.operation, attempt: request.attempt, expecting: request.lease)
        taskFields.markInvoked(accepted.id)
        return invocation
    }

    func recordTaskField(_ invocation: CommandRuntimeInvocation, facts: CommandTaskFieldFacts) throws {
        let current = try taskMutationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first,
              let accepted = taskFields.acceptances[item.draft.id], accepted.preview.item == item.stamp,
              accepted.preview.target.id == facts.targetID, taskFields.wasInvoked(accepted.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordTaskField(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }

    func finishTaskField(_ invocation: CommandRuntimeInvocation,
                         external: [CommandExternalEffect: CommandExternalResult]) throws {
        try finishTaskMutation(invocation, external: external)
    }
}

extension CommandTaskFieldFacts {
    func receipt(in run: CommandExecutionRun, attempt: CommandAttemptStamp) throws -> (Int, CommandExecutionResult?) {
        guard attempt.execution == run.stamp, attempt.phase == .local, run.snapshot.items.count == 1,
              let item = run.snapshot.items.first, item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local else {
            throw CommandExecutionError.stale
        }
        try CommandTaskFieldPreview.validate(item)
        guard item.draft.targets.objects.first?.id == targetID, run.outputs.isEmpty else { throw CommandExecutionError.invalidResult }
        if let previous = run.units[index].taskField {
            guard previous.targetID == targetID, previous.state == .pending || previous.state == state else {
                throw CommandExecutionError.invalidResult
            }
        }
        guard run.units[index].receipt == nil else { return (index, nil) }
        switch state {
        case .pending: return (index, nil)
        case .noChange:
            guard save == .notCalled, publication == .notCalled,
                  !refreshRequested, authorizationRequest == .notCalled else { throw CommandExecutionError.invalidResult }
            return (index, .noChange)
        case .saved:
            guard save == .returned else { throw CommandExecutionError.invalidResult }
            return (index, .committed(outputs: [:], external: [.taskPublication, .notification, .calendar]))
        case .unknown: return (index, .commitUnknown)
        case .notSubmitted:
            guard save == .notCalled else { throw CommandExecutionError.invalidResult }
            return (index, .failedWithoutCommit)
        }
    }
}
