import Foundation
import SwiftData

extension RoutineCommandAdapter {
    func tagCandidates(draft stamp: CommandDraftStamp, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession,
                       evidence: CommandTaskTagCatalog.Evidence? = nil) throws -> CommandTaskTagCandidates {
        try displaySession.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withRoutinePreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            let draft = host.session.plan.items.first(where: { $0.id == host.session.plan.editing })?.draft
                ?? host.session.operations.active
            guard host.session.execution == nil, host.session.operations.pending == nil,
                  let draft, draft.stamp == stamp, draft.commandID.rawValue == "routine.tags", supports(draft.commandID),
                  !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
                  draft.targets.selection == .single, draft.targets.objects.count == 1,
                  let target = draft.targets.objects.first, target.type == .routine, target.dayKey == nil else {
                throw RoutineCommandIssue.unsupportedPlan
            }
            _ = try environment.qualification(.init(command: draft.commandID, target: target, arguments: draft.arguments))
            let reader = environment.reader.catalogReader
            let catalog = try evidence.map(reader.validate) ?? reader.current()
            let rows = try SwiftDataRoutineRepository(context: environment.context).fetchRoutines(withID: target.id)
            guard rows.count == 1, rows[0].deletedAt == nil else { throw RoutineCommandIssue.stale }
            _ = try CommandTaskTitleTags.merge(rawIDs: rows[0].tagIDs, title: "", catalog: catalog)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession.validateDisplayHost(expecting: lease)
            return try CommandTaskTagCandidates(catalog: catalog)
        }
    }

    func verifyUnknown(_ operation: CommandOperationIdentity, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCreateVerification {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.validate(lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              run.operation(operation.operationID) == operation,
              let item = run.snapshot.items.first(where: { $0.id == operation.operationID }),
              let facts = run.units.first(where: { $0.members.contains(operation.operationID) })?.routine, facts.state == .unknown,
              let accepted = coordinator.routines.acceptances[item.draft.id],
              accepted.object == facts.object, coordinator.routines.wasInvoked(accepted.id) else { throw RoutineCommandIssue.stale }
        let preview = accepted.preview
        do {
            let source = try environment.qualification(.init(command: item.draft.commandID,
                target: preview.target, arguments: preview.arguments))
            guard source == preview.source else { return .unreadable }
            let reader = ModelContext(environment.context.container)
            reader.autosaveEnabled = false
            let rows = try SwiftDataRoutineRepository(context: reader).fetchRoutines(withID: facts.object.id)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            if rows.isEmpty { return .absent }
            if rows.count != 1 { return .ambiguous }
            _ = try CommandTaskTitleTags.merge(rawIDs: rows[0].tagIDs, title: "", catalog: environment.reader.catalogReader.current())
            return rows[0].deletedAt == nil ? .singleLive : .tombstone
        } catch { return .unreadable }
    }
}
