import Foundation

extension CommandHandoffCoordinator {
    func withConvertPreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        conversions.preparing[lease.ownership.hostID] = lease.ownership
        defer { conversions.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    /// 转换只走单项 Run；多项计划授权、输出依赖与重放许可都不能取得此入口。
    func convertAcceptance(_ request: TaskTitleCommandRequest) throws -> (CommandConvertAcceptance, CommandConvertConfirmation) {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.multiPlan == nil, run.snapshot.items.count == 1,
              run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              request.attempt.number == 1, run.permitsMember(request.operation.operationID),
              let unit = run.units.first(where: { $0.id == request.attempt.unitID }),
              unit.state == .running, unit.local == .notSubmitted,
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let item = run.snapshot.items.first(where: { $0.id == request.operation.operationID }),
              let accepted = conversions.acceptances[item.draft.id] else { throw CommandConvertIssue.stale }
        let confirmation = try conversions.confirmation(for: accepted)
        _ = try accepted.preview.frozenItem(in: run, lease: request.lease)
        return (accepted, confirmation)
    }

    func claimConvert(_ request: TaskTitleCommandRequest) throws -> CommandRuntimeInvocation {
        let (accepted, _) = try convertAcceptance(request)
        guard !conversions.wasInvoked(accepted.id) else { throw CommandConvertIssue.alreadyInvoked }
        let invocation = try claimRuntimeInvocation(request.operation, attempt: request.attempt, expecting: request.lease)
        conversions.markInvoked(accepted.id)
        return invocation
    }

    func recordConvert(_ invocation: CommandRuntimeInvocation, facts: CommandConvertFacts) throws {
        let current = try taskMutationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first(where: { $0.id == invocation.operation.operationID }),
              let accepted = conversions.acceptances[item.draft.id], accepted.id == facts.acceptanceID,
              accepted.preview.item == item.stamp, accepted.preview.targets == facts.targets,
              accepted.preview.impact == facts.impact, accepted.created == facts.created,
              conversions.confirmations[accepted.id]?.id == facts.confirmationID,
              conversions.wasInvoked(accepted.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordConvert(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }
}
