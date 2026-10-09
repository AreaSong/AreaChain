import Foundation
import SwiftData

@MainActor final class BatchCommandReader {
    unowned let environment: BatchCommandEnvironment
    let catalogReader: TaskCreateTagCatalogReader
    init(environment: BatchCommandEnvironment) {
        self.environment = environment
        catalogReader = .init(context: environment.context, invalidation: .catalogFacts)
    }

    func prepare(in host: CommandOwnedHost) throws -> CommandBatchPreview {
        let item = try CommandBatchPreview.input(in: host)
        return try read(item, lease: host.lease, plan: host.session.plan.stamp, catalog: catalogReader.prepare())
    }

    func validate(_ preview: CommandBatchPreview, item: CommandPlanItem) throws {
        guard preview.semanticsVersion == 2, preview.environmentID == environment.id,
              preview.contextID == ObjectIdentifier(environment.context),
              preview.storageID == ObjectIdentifier(environment.context.container),
              item.stamp == preview.item, item.draft.stamp == preview.draft,
              item.draft.arguments == preview.arguments, item.draft.targets == preview.targets else { throw CommandBatchIssue.stale }
        let current = try read(item, lease: preview.lease, plan: preview.plan, catalog: catalogReader.current())
        guard current.edit == preview.edit, current.impacts.count == preview.impacts.count,
              preview.impacts.map(\.target) == preview.targets.objects else { throw CommandBatchIssue.stale }
        guard current.catalog == preview.catalog else { throw CommandBatchIssue.catalogChanged }
        var problems: [CommandBatchTargetProblem] = []
        for (old, new) in zip(preview.impacts, current.impacts) {
            guard old.target == new.target, old.record == new.record, old.source == new.source,
                  old.rawTagIDs == new.rawTagIDs, old.original == new.original, old.final == new.final,
                  old.tags == new.tags, old.identity == new.identity, old.completion == new.completion,
                  old.children == new.children, old.state == new.state, old.taskDay == new.taskDay,
                  !preview.edit.isState || old.title == new.title else {
                problems.append(.init(target: old.target, reason: .changed)); continue
            }
        }
        guard problems.isEmpty else { throw CommandBatchIssue.invalidTargets(problems) }
        guard current.writeSet == preview.writeSet else { throw CommandBatchIssue.writeConflict }
    }

    func read(_ item: CommandPlanItem, lease: CommandHostLease, plan: CommandPlanStamp,
                      catalog: CommandTaskTagCatalog) throws -> CommandBatchPreview {
        try CommandBatchPreview.validate(item, allowingDependencies: true)
        let edit = try CommandBatchEdit(command: item.draft.commandID, arguments: item.draft.arguments)
        guard !edit.isState || environment.stateOperations != nil else { throw CommandBatchIssue.unassembled }
        let targets = item.draft.targets
        let lookup = CommandTaskTagLookup(catalog)
        try validateSelectedTags(edit, lookup: lookup)
        let sources = try qualifications(targets.objects)
        try environment.validateClean()
        // 来源回调可能重入；整次采样结束后统一再核对来源与目录，不按对象反复全表读取。
        guard try qualifications(targets.objects) == sources else { throw CommandBatchIssue.stale }
        let impacts = try edit.isState ? readStateImpacts(targets.objects, edit: edit, sources: sources, lookup: lookup)
            : readImpacts(targets.objects, edit: edit, sources: sources, lookup: lookup)
        guard try catalogReader.current().evidence() == catalog.evidence() else { throw CommandBatchIssue.catalogChanged }
        try environment.validateClean()
        return .init(lease: lease, plan: plan, item: item.stamp, draft: item.draft.stamp,
                     arguments: item.draft.arguments, targets: targets, edit: edit,
                     environmentID: environment.id, contextID: ObjectIdentifier(environment.context),
                     storageID: ObjectIdentifier(environment.context.container), catalog: try catalog.evidence(), impacts: impacts,
                     writeSet: edit.isState ? try CommandBatchWriteSet(impacts: impacts) : nil)
    }

    private func qualifications(_ targets: [CommandObjectReference]) throws -> [CommandTaskTitleEligibility] {
        var problems: [CommandBatchTargetProblem] = []
        var sources: [CommandTaskTitleEligibility] = []
        for target in targets {
            do {
                let source = try environment.source(target)
                if source.protection != .ordinary { problems.append(.init(target: target, reason: .protectedContent)) }
                else if source.notes != .absent { problems.append(.init(target: target, reason: .notes)) }
                sources.append(source)
            } catch { problems.append(.init(target: target, reason: .source)) }
        }
        guard problems.isEmpty else { throw CommandBatchIssue.invalidTargets(problems) }
        return sources
    }

    private func validateSelectedTags(_ edit: CommandBatchEdit, lookup: CommandTaskTagLookup) throws {
        guard lookup.catalogProblems.isEmpty else { throw CommandTaskTitlePreviewIssue.tags(lookup.catalogProblems) }
        guard case .tags(let argument) = edit, case .tags(let ids) = argument.value else { return }
        for id in TagIDList.normalized(ids) {
            switch lookup.resolve(.id(id)) {
            case .success(.existing(let row)) where row.state == .live: break
            case .failure(let error): throw CommandTaskTitlePreviewIssue.tags([.init(selection: .id(id), kind: error.kind)])
            default: throw CommandBatchIssue.inactiveTag
            }
        }
    }

    private func readImpacts(_ targets: [CommandObjectReference], edit: CommandBatchEdit,
                             sources: [CommandTaskTitleEligibility], lookup: CommandTaskTagLookup) throws -> [CommandBatchTargetImpact] {
        let todoIDs = targets.filter { $0.type == .todo }.map(\.id)
        let routineIDs = targets.filter { $0.type == .routine }.map(\.id)
        let todos = try environment.context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { todoIDs.contains($0.id) }))
        let routines = try environment.context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { routineIDs.contains($0.id) }))
        let todoIndex = Dictionary(grouping: todos, by: \.id)
        let routineIndex = Dictionary(grouping: routines, by: \.id)
        var result: [CommandBatchTargetImpact] = []
        var problems: [CommandBatchTargetProblem] = []
        for (target, source) in zip(targets, sources) {
            do {
                if target.type == .todo {
                    let todo = try unique(todoIndex[target.id] ?? [], target: target)
                    result.append(try impact(target, record: todo, source: source, edit: edit, lookup: lookup))
                } else {
                    let routine = try unique(routineIndex[target.id] ?? [], target: target)
                    result.append(try impact(target, record: routine, source: source, edit: edit, lookup: lookup))
                }
            } catch let issue as CommandBatchIssue {
                if case .invalidTargets(let entries) = issue { problems += entries }
                else { throw issue }
            } catch { problems.append(.init(target: target, reason: .tags)) }
        }
        guard problems.isEmpty else { throw CommandBatchIssue.invalidTargets(problems) }
        return result
    }

    func unique<T: PersistentModel>(_ rows: [T], target: CommandObjectReference) throws -> T {
        guard rows.count == 1 else {
            throw CommandBatchIssue.invalidTargets([.init(target: target, reason: rows.isEmpty ? .missing : .duplicate)])
        }
        guard rows[0].modelContext === environment.context else { throw CommandBatchIssue.invalidRepository }
        return rows[0]
    }

    private func impact(_ target: CommandObjectReference, record: any PersistentModel,
                        source: CommandTaskTitleEligibility, edit: CommandBatchEdit,
                        lookup: CommandTaskTagLookup) throws -> CommandBatchTargetImpact {
        let title: String, raw: String, day: String, deleted: Bool
        if let todo = record as? TodoItem {
            title = todo.title; raw = todo.tagIDs; day = todo.dayKey; deleted = todo.deletedAt != nil
        } else if let routine = record as? DailyRoutine {
            title = routine.title; raw = routine.tagIDs; day = ""; deleted = routine.deletedAt != nil
        } else { throw CommandBatchIssue.invalidArguments }
        guard !deleted else { throw CommandBatchIssue.invalidTargets([.init(target: target, reason: .deleted)]) }
        let original: CommandValue, final: CommandValue, tags: CommandTaskTagMutation?
        switch edit {
        case .move(let destination):
            _ = try CommandTaskTitleTags.associations(rawIDs: raw, lookup: lookup)
            original = .day(day); final = .day(destination); tags = nil
        case .tags(let argument):
            let mutation = try CommandTaskTagMutation.prepare(rawIDs: raw, argument: argument, lookup: lookup)
            guard let encoded = mutation.finalEncodedIDs else { throw CommandBatchIssue.invalidArguments }
            original = .tags(TagIDList.parse(raw)); final = .tags(TagIDList.parse(encoded)); tags = mutation
        case .completion, .enabled: throw CommandBatchIssue.invalidArguments
        }
        return .init(target: target, record: ObjectIdentifier(record), title: title, source: source,
                     rawTagIDs: raw, original: original, final: final, tags: tags)
    }
}
