import Foundation
import SwiftData

extension ConvertCommandAdapter {
    /// 只读核对未知结果：用接受时的新 UUID 与原对象软删状态读同一容器的新 context。
    /// 原 unknown 回执不提升、不清除、不恢复可重放资格；只有确定结果才解除对该对象的再次转换阻止。
    func verifyUnknown(_ operation: CommandOperationIdentity, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession? = nil) throws -> CommandConvertVerification {
        try displaySession?.validateDisplayHost(expecting: lease)
        let (environment, _) = try assembled()
        try coordinator.validate(lease)
        let run = try coordinator.host(lease.ownership.hostID).session.execution
        guard let run, run.operation(operation.operationID) == operation,
              let unit = run.units.first(where: { $0.members.contains(operation.operationID) }),
              let facts = unit.conversion, facts.state == .unknown, let attempt = run.attempt(unit.id),
              let item = run.snapshot.items.first(where: { $0.id == operation.operationID }),
              let accepted = coordinator.conversions.acceptances[item.draft.id], accepted.id == facts.acceptanceID,
              accepted.created == facts.created, coordinator.conversions.wasInvoked(accepted.id) else {
            throw CommandConvertIssue.stale
        }
        let reader = ModelContext(environment.context.container)
        reader.autosaveEnabled = false
        func presence(_ object: CommandObjectReference) -> CommandConvertVerification.Presence {
            guard let rows = try? ConvertCommandTransaction.presence(object, context: reader) else { return .unreadable }
            guard !rows.isEmpty else { return .absent }
            guard rows.count == 1 else { return .ambiguous }
            return rows[0] == nil ? .live : .deleted
        }
        let original: CommandConvertVerification.Presence
        do {
            let source = try environment.source(facts.impact.target)
            original = source.protection == .ordinary ? presence(facts.impact.target) : .unreadable
        } catch { original = .unreadable }
        try displaySession?.validateDisplayHost(expecting: lease)
        let verification = CommandConvertVerification(operation: operation, attempt: attempt, originalFacts: facts,
                                                       created: presence(facts.created), original: original)
        coordinator.conversions.resolve(verification)
        return verification
    }
}
