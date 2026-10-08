import Foundation
import SwiftData

extension RoutineCommandAdapter {
    func creationTagCandidates(draft stamp: CommandDraftStamp, expecting lease: CommandHostLease,
                               displaySession: ContentQueryReadSession,
                               evidence: CommandTaskTagCatalog.Evidence? = nil) throws -> CommandTaskTagCandidates {
        try displaySession.validateDisplayHost(expecting: lease)
        let environment = try assembledCreation()
        return try coordinator.withTaskCreatePreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            let draft = host.session.plan.items.first(where: { $0.id == host.session.plan.editing })?.draft
                ?? host.session.operations.active
            guard host.session.execution == nil, host.session.operations.pending == nil,
                  let draft, draft.stamp == stamp, draft.commandID.rawValue == "routine.create", draft.targets == .none,
                  draft.baseline == CommandDraftBaseline(), !draft.blocksUnprotectedExport,
                  draft.protectionRequirement == .ordinary else { throw RoutineCreateIssue.invalidInput }
            _ = try environment.creationQualification(draft.arguments)
            let reader = environment.reader.catalogReader
            let catalog = try evidence.map(reader.validate) ?? reader.current()
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession.validateDisplayHost(expecting: lease)
            return try CommandTaskTagCandidates(catalog: catalog)
        }
    }

    /// 仅核验原 unknown 身份当前是否存在；不修复、不发布、不把存在性升格为提交成功。
    func verifyCreation(_ operation: CommandOperationIdentity, expecting lease: CommandHostLease,
                        displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCreateVerification {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembledCreation()
        try coordinator.validate(lease)
        let run = try coordinator.host(lease.ownership.hostID).session.execution
        guard run?.operation(operation.operationID) == operation, let item = run?.snapshot.items.first,
              let facts = run?.units.first?.routineCreation, facts.state == .unknown,
              let accepted = coordinator.taskCreations.routinePreparations[item.draft.id],
              accepted.preview.item == operation.item, accepted.creationID == facts.creationID,
              accepted.preview.source.environmentID == environment.id, coordinator.taskCreations.wasInvoked(accepted.id) else {
            throw RoutineCreateIssue.stale
        }
        do {
            let reader = ModelContext(environment.context.container)
            reader.autosaveEnabled = false
            let rows = try SwiftDataRoutineRepository(context: reader).fetchRoutines(withID: facts.creationID)
            if rows.isEmpty { return .absent }
            if rows.count != 1 { return .ambiguous }
            return rows[0].deletedAt == nil ? .singleLive : .tombstone
        } catch { return .unreadable }
    }
}
