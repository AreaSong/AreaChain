import Foundation
import SwiftData

extension TaskCreateCommandAdapter {
    /// 旧 prepare/submit 不消费扩展能力；未来 UI 必须展示这份预览，再显式调用 accept。
    func preview(plan: CommandPlanStamp, expecting lease: CommandHostLease) throws -> CommandTaskCreatePreview {
        let environment = try assembledComposition()
        return try coordinator.withTaskCreatePreparation(expecting: lease) {
            _ = try coordinator.taskCreatePlan(plan, expecting: lease, composed: true)
            let source = try readSource(environment)
            try validateSource(source)
            let catalog = try environment.tagCatalog.prepare()
            _ = try coordinator.taskCreatePlan(plan, expecting: lease, composed: true)
            try environment.validateClean()
            return try CommandTaskCreatePreview.prepare(in: coordinator.host(lease.ownership.hostID),
                                                         source: source, catalog: catalog)
        }
    }

    /// 接受的是整份具体效果和版本，而非持久布尔值；登记后不自动换预览或重新分配身份。
    func accept(_ preview: CommandTaskCreatePreview, expecting lease: CommandHostLease) throws -> CommandTaskCreatePreparation {
        let environment = try assembledComposition()
        return try coordinator.withTaskCreatePreparation(expecting: lease) {
            let item = try coordinator.taskCreatePlan(preview.binding.plan, expecting: lease, composed: true)
            let source = try readSource(environment)
            let catalog = try environment.tagCatalog.validate(preview.binding.catalog)
            try coordinator.validate(lease)
            try preview.validateCurrent(in: coordinator.host(lease.ownership.hostID), source: source, catalog: catalog)
            guard preview.transactionPlan != nil else { throw TaskCreateCommandIssue.invalidInput }
            try environment.validateClean()
            let prepared = try coordinator.taskCreations.reserve(item: item, plan: preview.binding.plan, lease: lease,
                evidence: .init(environmentID: environment.id, contextID: ObjectIdentifier(environment.context),
                    storageID: ObjectIdentifier(environment.context.container), source: source, preview: preview))
            try requireAbsent(prepared.creationID, environment: environment)
            try requireTagIDsAbsent(prepared, catalog: catalog)
            return prepared
        }
    }

    func submit(accepted: CommandTaskCreatePreparation, expecting lease: CommandHostLease) throws -> CommandTaskCreateFacts {
        let environment = try assembledComposition()
        try coordinator.withTaskCreatePreparation(expecting: lease) {
            guard let preview = accepted.preview, accepted.lease == lease,
                  coordinator.taskCreations.preparations[accepted.draft.draftID] == accepted,
                  !coordinator.taskCreations.wasInvoked(accepted.id) else { throw TaskCreateCommandIssue.stale }
            _ = try coordinator.taskCreatePlan(accepted.plan, expecting: lease, composed: true)
            try revalidate(accepted, environment: environment)
            try coordinator.validate(lease)
            try preview.validateCurrent(in: coordinator.host(lease.ownership.hostID), source: accepted.source,
                                         catalog: environment.tagCatalog.validate(preview.binding.catalog))
        }
        return try submitPrepared(accepted, expecting: lease)
    }

    func requireTagIDsAbsent(_ prepared: CommandTaskCreatePreparation, catalog: CommandTaskTagCatalog) throws {
        let ids = Array(prepared.tagCreationIDs.values)
        guard Set(ids).count == ids.count, !ids.contains(prepared.creationID),
              !catalog.records.contains(where: { row in row.id.map(ids.contains) ?? false }) else {
            throw TaskCreateCommandIssue.identityCollision
        }
    }

    private func assembledComposition() throws -> TaskCreateCommandEnvironment {
        guard capability == .ordinaryComposition else { throw TaskCreateCommandIssue.unassembled }
        return try assembled()
    }
}
