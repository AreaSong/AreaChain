import Foundation
import SwiftData

extension CommandHandoffCoordinator {
    /// 原协调者的保存事实、接受和真实调用共同签发；当前库存在同 UUID 不构成证明。
    func multiPlanOutput(_ reference: CommandCreationReference, in run: CommandExecutionRun) throws -> CommandCreationOutput {
        guard try host(run.snapshot.stamp.hostID).session.execution == run,
              run.multiPlan != nil, !run.hasUnknownCommit,
              let assembly = multiPlans.assemblies[run.stamp],
              let item = run.snapshot.items.first(where: { $0.stamp == reference.producer }),
              let object = run.creationOutput(for: reference),
              let unit = run.units.first(where: { $0.id == item.id }) else { throw CommandExecutionError.requiresVerification }
        let evidence = try creationEvidence(item, unit: unit, run: run)
        guard evidence.object == object,
              let authorization = multiPlans.authorizations.values.first(where: {
                  $0.attempt.execution == run.stamp && $0.itemID == item.id && $0.acceptanceID == evidence.acceptance
                      && $0.assemblyID == assembly && $0.attempt.phase == .local
              }), wasAttemptInvoked(authorization.attempt),
              unit.history.contains(where: { $0.number == authorization.attempt.number && $0.phase == .local && $0.local == .committed }) else {
            throw CommandExecutionError.requiresVerification
        }
        return .init(execution: run.stamp, producer: item.stamp, draft: item.draft.stamp, creationAcceptanceID: evidence.acceptance,
                     localAttempt: authorization.attempt, assemblyID: assembly, environmentID: evidence.environment,
                     contextID: evidence.context, storageID: evidence.storage, record: evidence.record, object: object)
    }

    private struct CreationEvidence {
        let acceptance: UUID
        let environment: UUID
        let context: ObjectIdentifier
        let storage: ObjectIdentifier
        let record: PersistentIdentifier
        let object: CommandObjectReference
    }

    private func creationEvidence(_ item: CommandPlanItem, unit: CommandExecutionUnit,
                                  run: CommandExecutionRun) throws -> CreationEvidence {
        switch item.draft.commandID.rawValue {
        case "todo.create":
            guard let prepared = taskCreations.preparations[item.draft.id], prepared.item == item.stamp,
                  prepared.draft == item.draft.stamp,
                  prepared.plan == run.snapshot.stamp, taskCreations.wasInvoked(prepared.id),
                  let facts = unit.taskCreation, facts.state == .saved, facts.save == .returned,
                  facts.savedID == prepared.creationID, facts.creationID == prepared.creationID,
                  let record = facts.savedRecord else { throw CommandExecutionError.requiresVerification }
            return .init(acceptance: prepared.id, environment: prepared.environmentID, context: prepared.contextID,
                         storage: prepared.storageID, record: record, object: .init(type: .todo, id: prepared.creationID))
        case "subtask.create":
            guard run.multiPlan?.outputCapability == .typedCreation,
                  let accepted = subtasks.acceptances[item.draft.id], accepted.preview.item == item.stamp,
                  accepted.preview.draft == item.draft.stamp,
                  accepted.preview.plan == run.snapshot.stamp, subtasks.wasInvoked(accepted.id),
                  let facts = unit.subtask, facts.state == .saved, facts.save == .returned, facts.isCreation,
                  facts.object == accepted.object, facts.parentID == accepted.preview.parent.id,
                  let record = facts.savedRecord else { throw CommandExecutionError.requiresVerification }
            let source = accepted.preview.source
            return .init(acceptance: accepted.id, environment: source.environmentID, context: source.contextID,
                         storage: source.storageID, record: record, object: accepted.object)
        case "routine.create":
            guard run.multiPlan?.outputCapability == .typedCreation,
                  let accepted = taskCreations.routinePreparations[item.draft.id], accepted.preview.item == item.stamp,
                  accepted.preview.draft == item.draft.stamp,
                  accepted.preview.plan == run.snapshot.stamp, taskCreations.wasInvoked(accepted.id),
                  let facts = unit.routineCreation, facts.state == .saved, facts.save == .returned,
                  facts.creationID == accepted.creationID, facts.savedID == accepted.creationID,
                  let record = facts.savedRecord else { throw CommandExecutionError.requiresVerification }
            let source = accepted.preview.source
            return .init(acceptance: accepted.id, environment: source.environmentID, context: source.contextID,
                         storage: source.storageID, record: record, object: accepted.object)
        default: throw CommandMultiPlanIssue.unsupported
        }
    }

    func validateConsumption(_ consumption: CommandCreationConsumption?, item: CommandPlanItem, run: CommandExecutionRun) throws {
        guard let consumption else {
            guard item.links.results.isEmpty else { throw CommandMultiPlanIssue.stale }
            return
        }
        try consumption.validate(in: run, item: item)
        guard let reference = item.links.results[consumption.parameter],
              try multiPlanOutput(reference, in: run) == consumption.output else { throw CommandMultiPlanIssue.stale }
    }
}
