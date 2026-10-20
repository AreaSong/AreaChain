import Foundation
import SwiftData

/// 只读核验固定目标与随之进回收站的活子项/附件；不调用任何仓储写入口。
@MainActor final class TrashCommandReader {
    unowned let environment: BatchCommandEnvironment
    init(environment: BatchCommandEnvironment) { self.environment = environment }

    func prepare(in host: CommandOwnedHost) throws -> CommandTrashPreview {
        let item = try CommandTrashPreview.input(in: host)
        return try read(item, lease: host.lease, plan: host.session.plan.stamp)
    }

    /// 任一目标被改、被删或资格失效都拒绝；不按当前状态静默扩大或缩小集合。
    func validate(_ preview: CommandTrashPreview, item: CommandPlanItem) throws {
        guard preview.semanticsVersion == 1, preview.environmentID == environment.id,
              preview.contextID == ObjectIdentifier(environment.context),
              preview.storageID == ObjectIdentifier(environment.context.container),
              item.stamp == preview.item, item.draft.stamp == preview.draft,
              item.draft.targets == preview.targets else { throw CommandTrashIssue.stale }
        let current = try read(item, lease: preview.lease, plan: preview.plan)
        guard current.edit == preview.edit, current.impacts.map(\.target) == preview.impacts.map(\.target) else {
            throw CommandTrashIssue.stale
        }
        let problems = zip(preview.impacts, current.impacts).filter { $0 != $1 }
            .map { CommandTrashTargetProblem(target: $0.0.target, reason: .changed) }
        guard problems.isEmpty else { throw CommandTrashIssue.invalidTargets(problems) }
        try current.validateLimit()
    }

    func read(_ item: CommandPlanItem, lease: CommandHostLease, plan: CommandPlanStamp) throws -> CommandTrashPreview {
        try CommandTrashPreview.validate(item)
        let edit = try CommandTrashEdit(command: item.draft.commandID)
        let targets = item.draft.targets
        try environment.validateClean()
        let sources = try qualifications(targets.objects, command: item.draft.commandID)
        var impacts: [CommandTrashTargetImpact] = []
        var problems: [CommandTrashTargetProblem] = []
        for (target, source) in zip(targets.objects, sources) {
            do { impacts.append(try impact(target, source: source)) }
            catch let issue as CommandTrashIssue {
                guard case .invalidTargets(let entries) = issue else { throw issue }
                problems += entries
            }
        }
        guard problems.isEmpty else { throw CommandTrashIssue.invalidTargets(problems) }
        // 来源回调可能重入；整次采样后统一复核来源与父项资格。
        guard try qualifications(targets.objects, command: item.draft.commandID) == sources,
              try impacts.map({ try $0.parent.map(parentQualification) }) == impacts.map(\.parentSource) else {
            throw CommandTrashIssue.stale
        }
        try environment.validateClean()
        let preview = CommandTrashPreview(lease: lease, plan: plan, item: item.stamp, draft: item.draft.stamp,
            targets: targets, edit: edit, environmentID: environment.id, contextID: ObjectIdentifier(environment.context),
            storageID: ObjectIdentifier(environment.context.container), impacts: impacts)
        try preview.validateLimit()
        return preview
    }

    /// L8：自读备注取带键摘要；todo.trash／routine.trash／batch.trash 允许带备注（确认面板列出去向），摘要随资格冻结。
    private func qualifications(_ targets: [CommandObjectReference], command: CommandID) throws -> [CommandTaskTitleEligibility] {
        var problems: [CommandTrashTargetProblem] = []
        var sources: [CommandTaskTitleEligibility] = []
        for target in targets {
            do {
                let source = CommandNotesProofReader.proving(try environment.source(target), of: target,
                                                             in: environment.context, key: environment.notesKey)
                if source.protection != .ordinary { problems.append(.init(target: target, reason: .protectedContent)) }
                else if source.notes == .unproven { problems.append(.init(target: target, reason: .source)) }
                else if !CommandNotesProofReader.admits(command.rawValue, source.notes) {
                    problems.append(.init(target: target, reason: .notes))
                }
                sources.append(source)
            } catch { problems.append(.init(target: target, reason: .source)) }
        }
        guard problems.isEmpty else { throw CommandTrashIssue.invalidTargets(problems) }
        return sources
    }

    private func parentQualification(_ parent: CommandObjectReference) throws -> CommandTaskTitleEligibility {
        let source: CommandTaskTitleEligibility
        do { source = try environment.source(parent) } catch { throw CommandTrashIssue.stale }
        // 删子任务不放宽：父待办仍须无备注（沿原门槛，只把证明换成自读摘要）。
        let proven = CommandNotesProofReader.proving(source, of: parent, in: environment.context, key: environment.notesKey)
        guard proven.protection == .ordinary, proven.notes.isAbsent else { throw CommandTrashIssue.stale }
        return proven
    }

    private func impact(_ target: CommandObjectReference, source: CommandTaskTitleEligibility) throws -> CommandTrashTargetImpact {
        let problem = { (reason: CommandTrashTargetProblem.Reason) in
            CommandTrashIssue.invalidTargets([.init(target: target, reason: reason)])
        }
        switch target.type {
        case .todo:
            let todo = try live(SwiftDataTaskRepository(context: environment.context).fetchTodos(withID: target.id),
                                deleted: \.deletedAt, target: target)
            let children: [SubtaskItem]
            do { children = try TaskFamilyCommandIdentity.children(of: todo, in: environment.context) }
            catch { throw problem(.family) }
            return .init(target: target, record: todo.persistentModelID, title: todo.title, source: source,
                         parent: nil, parentSource: nil, parentTitle: nil, fingerprint: .todo(CommandNotesProofReader.redacted(todo.snapshot)),
                         subtasks: Set(children.filter { $0.deletedAt == nil }.map(\.persistentModelID)),
                         attachments: try liveAttachments(todo.id, kind: .todo))
        case .routine:
            let routine = try live(SwiftDataRoutineRepository(context: environment.context).fetchRoutines(withID: target.id),
                                   deleted: \.deletedAt, target: target)
            return .init(target: target, record: routine.persistentModelID, title: routine.title, source: source,
                         parent: nil, parentSource: nil, parentTitle: nil, fingerprint: .routine(CommandNotesProofReader.redacted(routine.snapshot)),
                         subtasks: [], attachments: try liveAttachments(routine.id, kind: .routine))
        case .subtask: return try subtaskImpact(target, source: source)
        default: throw CommandTrashIssue.invalidArguments
        }
    }

    private func subtaskImpact(_ target: CommandObjectReference, source: CommandTaskTitleEligibility) throws -> CommandTrashTargetImpact {
        let id = target.id
        let rows = try environment.context.fetch(FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id }))
        let child = try live(rows, deleted: \.deletedAt, target: target)
        let family = CommandTrashIssue.invalidTargets([.init(target: target, reason: .family)])
        guard let todo = child.todo else { throw family }
        let parents = try SwiftDataTaskRepository(context: environment.context).fetchTodos(withID: todo.id)
        guard parents.count == 1, parents[0] === todo, todo.deletedAt == nil,
              (try? TaskFamilyCommandIdentity.children(of: todo, in: environment.context))?.contains(where: { $0 === child }) == true,
              let snapshot = child.snapshot else { throw family }
        let parent = CommandObjectReference(type: .todo, id: todo.id)
        let parentSource: CommandTaskTitleEligibility
        do { parentSource = try parentQualification(parent) } catch { throw family }
        return .init(target: target, record: child.persistentModelID, title: child.title, source: source,
                     parent: parent, parentSource: parentSource, parentTitle: todo.title,
                     fingerprint: .subtask(snapshot, parent: CommandNotesProofReader.redacted(todo.snapshot)), subtasks: [], attachments: [])
    }

    private func live<T: PersistentModel>(_ rows: [T], deleted: KeyPath<T, Date?>, target: CommandObjectReference) throws -> T {
        guard rows.count == 1 else {
            throw CommandTrashIssue.invalidTargets([.init(target: target, reason: rows.isEmpty ? .missing : .duplicate)])
        }
        guard rows[0].modelContext === environment.context else { throw CommandTrashIssue.invalidRepository }
        guard rows[0][keyPath: deleted] == nil else {
            throw CommandTrashIssue.invalidTargets([.init(target: target, reason: .deleted)])
        }
        return rows[0]
    }

    private func liveAttachments(_ owner: UUID, kind: AttachmentOwner) throws -> Set<PersistentIdentifier> {
        Set(try OwnedAttachments.matching(ownerID: owner, kind: kind, in: environment.context)
            .filter { $0.deletedAt == nil }.map(\.persistentModelID))
    }
}
