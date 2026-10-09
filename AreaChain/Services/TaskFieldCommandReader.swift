import Foundation
import SwiftData

/// 属性命令沿用普通来源证明与目录规则；只采样实际影响字段，不读取正文来猜资格。
@MainActor final class TaskFieldCommandReader {
    unowned let environment: TaskTitleCommandEnvironment
    private let id = UUID()
    let catalogReader: TaskCreateTagCatalogReader

    init(environment: TaskTitleCommandEnvironment) {
        self.environment = environment
        catalogReader = .init(context: environment.context, invalidation: .catalogFacts)
    }

    func prepare(in host: CommandOwnedHost) throws -> CommandTaskFieldPreview {
        let item = try CommandTaskFieldPreview.input(in: host)
        return try prepare(item: item, lease: host.lease, plan: host.session.plan.stamp, catalog: catalogReader.prepare())
    }

    func prepare(item: CommandPlanItem, lease: CommandHostLease, plan: CommandPlanStamp,
                 catalog: CommandTaskTagCatalog, consumption: CommandCreationConsumption? = nil) throws -> CommandTaskFieldPreview {
        let observation = try read(item, catalog: catalog, consumption: consumption)
        return .init(lease: lease, plan: plan, item: item.stamp, draft: item.draft.stamp,
                     arguments: item.draft.arguments, target: observation.target, original: observation.original,
                     edit: observation.edit, source: observation.source, catalog: observation.catalog,
                     tagIDs: observation.todo.tagIDs, completion: observation.completion, tags: observation.tags,
                     targetTitle: observation.todo.title, consumption: consumption, record: observation.todo.persistentModelID)
    }

    func owns(_ source: CommandTaskTitleSource) -> Bool {
        source.environmentID == id && source.contextID == ObjectIdentifier(environment.context)
            && source.storageID == ObjectIdentifier(environment.context.container)
    }

    func verifyQualification(_ preview: CommandTaskFieldPreview) throws -> Bool {
        guard owns(preview.source) else { throw TaskFieldCommandIssue.stale }
        let source = try source(target: preview.target.id)
        let catalog = try catalogReader.current().evidence()
        return source.protection == .ordinary && source.notes == .absent && source.revision == preview.source.revision
            && catalog == preview.catalog
    }

    func verifyOrdinaryTags(_ rawIDs: String) throws {
        _ = try CommandTaskTitleTags.merge(rawIDs: rawIDs, title: "", catalog: catalogReader.current())
    }

    struct Observation {
        let todo: TodoItem
        let target: CommandObjectReference
        let original: TaskFieldEdit
        let edit: TaskFieldEdit
        let source: CommandTaskTitleSource
        let catalog: CommandTaskTagCatalog.Evidence
        let completion: CommandTaskCompletionImpact?
        let tags: CommandTaskTagMutation?
        var followUp: CommandTaskTitleContext {
            .init(dayKey: todo.dayKey, isDone: todo.isDone, calendarEventID: todo.calendarEventID)
        }
    }

    func validate(_ preview: CommandTaskFieldPreview, item: CommandPlanItem) throws -> Observation {
        guard preview.semanticsVersion == 2, item.stamp == preview.item, item.draft.stamp == preview.draft,
              item.draft.arguments == preview.arguments else { throw TaskFieldCommandIssue.stale }
        let observation = try read(item, catalog: catalogReader.current(), consumption: preview.consumption)
        guard observation.target == preview.target, observation.edit == preview.edit,
              observation.source == preview.source, observation.catalog == preview.catalog,
              observation.todo.tagIDs == preview.tagIDs else { throw TaskFieldCommandIssue.stale }
        guard preview.record == observation.todo.persistentModelID else { throw TaskFieldCommandIssue.stale }
        guard observation.original == preview.original, observation.completion == preview.completion,
              observation.tags == preview.tags else { throw TaskFieldCommandIssue.fieldsChanged }
        return observation
    }

    private func read(_ item: CommandPlanItem, catalog: CommandTaskTagCatalog,
                      consumption: CommandCreationConsumption?) throws -> Observation {
        let resolved = try consumption?.input(item)
        try CommandTaskFieldPreview.validate(item, allowingDependencies: true, resolved: resolved)
        let target = (resolved?.targets ?? item.draft.targets).objects[0]
        let source = try source(target: target.id)
        guard source.protection == .ordinary else { throw CommandTaskTitlePreviewIssue.protectedContent }
        guard source.notes == .absent else { throw TaskTitleCommandIssue.notesNotSupported }
        guard try catalogReader.current().evidence() == catalog.evidence() else { throw TaskTitleCommandIssue.catalogChanged }
        try environment.validateClean()
        let rows = try SwiftDataTaskRepository(context: environment.context).fetchTodos(withID: target.id)
        guard !rows.isEmpty else { throw CommandTaskTitlePreviewIssue.missingTarget }
        guard rows.count == 1 else { throw CommandTaskTitlePreviewIssue.duplicateTarget }
        let todo = rows[0]
        try consumption?.output.validate(context: ObjectIdentifier(environment.context),
                                         storage: ObjectIdentifier(environment.context.container), record: todo.persistentModelID)
        guard todo.modelContext === environment.context, todo.deletedAt == nil else { throw CommandTaskTitlePreviewIssue.deletedTarget }
        // 空标题只检查既有关联的 D3 资格，不解析任务标题或产生标签效果。
        _ = try CommandTaskTitleTags.merge(rawIDs: todo.tagIDs, title: "", catalog: catalog)
        let edit = try TaskFieldEdit(command: item.draft.commandID, argument: item.draft.arguments[0])
        let original: TaskFieldEdit
        switch edit {
        case .move: original = .move(todo.dayKey)
        case .priority: original = .priority(important: todo.isImportant, urgent: todo.isUrgent)
        case .reminder: original = .reminder(todo.remindMinutes)
        case .due: original = .due(todo.dueMinutes)
        case .completion: original = .completion(todo.isDone)
        case .tags, .createTag: original = edit
        }
        return .init(todo: todo, target: target, original: original, edit: edit,
                     source: .init(environmentID: id, contextID: ObjectIdentifier(environment.context),
                                   storageID: ObjectIdentifier(environment.context.container), protection: source.protection,
                                   revision: source.revision), catalog: try catalog.evidence(),
                     completion: try completion(todo, edit: edit, catalog: catalog),
                     tags: try CommandTaskTagMutation.prepare(rawIDs: todo.tagIDs, edit: edit, catalog: catalog))
    }

    private func completion(_ todo: TodoItem, edit: TaskFieldEdit,
                            catalog: CommandTaskTagCatalog) throws -> CommandTaskCompletionImpact? {
        guard case .completion(let done) = edit else { return nil }
        let children: [SubtaskItem]
        do { children = try TaskFamilyCommandIdentity.children(of: todo, in: environment.context) }
        catch { throw TaskFieldCommandIssue.fieldsChanged }
        return try TaskFamilyCommandIdentity.completion(of: todo, done: done, children: children,
                                                       lookup: CommandTaskTagLookup(catalog))
    }

    private func source(target: UUID) throws -> CommandTaskTitleEligibility {
        do { return try environment.source(target) }
        catch { throw TaskTitleCommandIssue.sourceUnavailable }
    }
}
