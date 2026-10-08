import Foundation
import SwiftData

extension TaskFieldCommandAdapter {
    func tagCandidates(draft stamp: CommandDraftStamp, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession,
                       evidence: CommandTaskTagCatalog.Evidence? = nil) throws -> CommandTaskTagCandidates {
        try displaySession.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withTaskFieldPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            let draft = host.session.plan.items.first(where: { $0.id == host.session.plan.editing })?.draft
                ?? host.session.operations.active
            guard host.session.execution == nil, host.session.operations.pending == nil,
                  let draft, draft.stamp == stamp, draft.commandID.rawValue == "todo.tags", supports(draft.commandID),
                  !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
                  draft.targets.selection == .single, draft.targets.objects.count == 1,
                  let target = draft.targets.objects.first, target.type == .todo, target.dayKey == nil else {
                throw TaskFieldCommandIssue.unsupportedPlan
            }
            let source = try environment.source(target.id)
            guard source.protection == .ordinary, source.notes == .absent else { throw TaskTitleCommandIssue.notesNotSupported }
            let reader = environment.fieldReader.catalogReader
            let catalog = try evidence.map(reader.validate) ?? reader.current()
            let rows = try SwiftDataTaskRepository(context: environment.context).fetchTodos(withID: target.id)
            guard rows.count == 1, rows[0].deletedAt == nil else { throw TaskFieldCommandIssue.stale }
            _ = try CommandTaskTitleTags.merge(rawIDs: rows[0].tagIDs, title: "", catalog: catalog)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession.validateDisplayHost(expecting: lease)
            return try CommandTaskTagCandidates(catalog: catalog)
        }
    }
}
