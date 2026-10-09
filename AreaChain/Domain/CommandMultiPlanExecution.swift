import Foundation

extension CommandHandoffCoordinator {
    /// 已显式装配的服务在全计划预览被接受后调用；封存一次，参数仍唯一归原 Run。
    func startMultiPlan(_ identity: CommandMultiPlanIdentity, assemblyID: UUID,
                        expecting lease: CommandHostLease) throws -> CommandExecutionStamp {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        var session = try host(lease.ownership.hostID).session
        try session.sealMultiPlan(identity, runID: UUID())
        guard let run = session.execution else { throw CommandMultiPlanIssue.stale }
        multiPlans.assemblies[run.stamp] = assemblyID
        publishPreferenceSession(session, from: lease)
        return run.stamp
    }

    func authorizeMultiPlanMember(_ authorization: CommandMultiPlanAuthorization) throws {
        try validate(authorization.lease)
        let session = try host(authorization.lease.ownership.hostID).session
        guard let run = session.execution, run.multiPlan != nil, !run.hasUnknownCommit,
              multiPlans.assemblies[run.stamp] == authorization.assemblyID,
              run.attempt(authorization.attempt.unitID) == authorization.attempt,
              run.units.contains(where: { $0.id == authorization.attempt.unitID && $0.members.contains(authorization.itemID) }),
              run.units.first(where: { $0.id == authorization.attempt.unitID })?.state == .running,
              !hasInvocation(authorization.lease.ownership),
              multiPlans.authorizations[authorization.attempt] == nil else { throw CommandMultiPlanIssue.stale }
        multiPlans.authorizations[authorization.attempt] = authorization
    }
}

extension CommandHandoffCoordinator {
    /// 只登记本适配尚未调用时的真实读取失败；没有事务或外部效果可以被它宣称成功。
    func failMultiPlanRead(_ unitID: UUID, assemblyID: UUID, expecting lease: CommandHostLease) throws {
        try validate(lease)
        var session = try host(lease.ownership.hostID).session
        guard let run = session.execution, multiPlans.assemblies[run.stamp] == assemblyID,
              !run.hasUnknownCommit, !hasInvocation(lease.ownership),
              run.units.first(where: { $0.state == .ready })?.id == unitID else { throw CommandMultiPlanIssue.stale }
        let attempt = try session.beginNextProtocolStep(expecting: run.stamp)
        guard attempt.unitID == unitID, attempt.phase == .local,
              multiPlans.authorizations[attempt] == nil else { throw CommandMultiPlanIssue.stale }
        try session.recordMultiPlanReadFailure(attempt)
        publishPreferenceSession(session, from: lease)
    }
}

extension CommandHandoffCoordinator {
    func withMultiPlanPreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        multiPlans.preparing[lease.ownership.hostID] = lease.ownership
        defer { multiPlans.preparing[lease.ownership.hostID] = nil }
        let value = try work()
        try validate(lease)
        return value
    }
}
