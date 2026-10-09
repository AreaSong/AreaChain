import Foundation
import SwiftData

extension SubtaskCommandAdapter {
    func tagCandidates(draft stamp: CommandDraftStamp, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession,
                       evidence: CommandTaskTagCatalog.Evidence? = nil) throws -> CommandTaskTagCandidates {
        try displaySession.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withSubtaskPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            let draft = host.session.plan.items.first(where: { $0.id == host.session.plan.editing })?.draft
                ?? host.session.operations.active
            guard host.session.execution == nil, host.session.operations.pending == nil,
                  let draft, draft.stamp == stamp, ["subtask.create", "subtask.tags"].contains(draft.commandID.rawValue),
                  !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary else {
                throw SubtaskCommandIssue.unsupportedPlan
            }
            let (parent, target) = try Self.selection(draft)
            let family = try environment.reader.family(parent: parent, target: target)
            _ = try environment.qualification(.init(command: draft.commandID, parent: .init(type: .todo, id: family.0.id),
                                                    target: target, arguments: draft.arguments))
            let reader = environment.reader.catalogReader
            let catalog = try evidence.map(reader.validate) ?? reader.current()
            _ = try CommandTaskTitleTags.merge(rawIDs: family.0.tagIDs, title: "", catalog: catalog)
            if let child = family.1 { _ = try CommandTaskTitleTags.merge(rawIDs: child.tagIDs, title: "", catalog: catalog) }
            _ = try environment.reader.family(parent: parent, target: target)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession.validateDisplayHost(expecting: lease)
            return try CommandTaskTagCandidates(catalog: catalog)
        }
    }

    private static func selection(_ draft: CommandDraft) throws -> (CommandObjectReference?, CommandObjectReference?) {
        if draft.commandID.rawValue == "subtask.create" {
            guard draft.targets == .none,
                  case .object(let parent) = draft.arguments.first(where: { $0.parameter == .parent })?.value,
                  parent.type == .todo, parent.dayKey == nil else { throw SubtaskCommandIssue.invalidArguments }
            return (parent, nil)
        }
        guard draft.targets.selection == .single, draft.targets.objects.count == 1,
              let target = draft.targets.objects.first, target.type == .subtask, target.dayKey == nil else {
            throw SubtaskCommandIssue.invalidArguments
        }
        return (nil, target)
    }

    /// 只读原固定身份的当前存在性，不把相同值变成历史提交证明或重放许可。
    func verifyUnknown(_ operation: CommandOperationIdentity, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCreateVerification {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.validate(lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              run.operation(operation.operationID) == operation,
              let item = run.snapshot.items.first(where: { $0.id == operation.operationID }),
              let facts = run.units.first(where: { $0.members.contains(operation.operationID) })?.subtask, facts.state == .unknown,
              let accepted = coordinator.subtasks.acceptances[item.draft.id],
              accepted.object == facts.object, coordinator.subtasks.wasInvoked(accepted.id) else { throw SubtaskCommandIssue.stale }
        let preview = accepted.preview
        do {
            let source = try environment.qualification(.init(command: item.draft.commandID,
                parent: .init(type: .todo, id: facts.parentID), target: preview.input.target, arguments: preview.arguments))
            guard source == preview.source else { return .unreadable }
            let reader = ModelContext(environment.context.container)
            reader.autosaveEnabled = false
            let id = facts.object.id
            let rows = try reader.fetch(FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id }))
            try coordinator.validate(lease)
            try displaySession?.validateDisplayHost(expecting: lease)
            if rows.isEmpty { return .absent }
            if rows.count != 1 { return .ambiguous }
            guard let parent = rows[0].todo, parent.id == facts.parentID, parent.deletedAt == nil,
                  try SwiftDataTaskRepository(context: reader).fetchTodos(withID: facts.parentID).count == 1 else { return .unreadable }
            _ = try TaskFamilyCommandIdentity.children(of: parent, in: reader)
            let catalog = try environment.reader.catalogReader.current()
            _ = try CommandTaskTitleTags.merge(rawIDs: rows[0].tagIDs, title: "", catalog: catalog)
            _ = try CommandTaskTitleTags.merge(rawIDs: parent.tagIDs, title: "", catalog: catalog)
            return rows[0].deletedAt == nil ? .singleLive : .tombstone
        } catch { return .unreadable }
    }
}
