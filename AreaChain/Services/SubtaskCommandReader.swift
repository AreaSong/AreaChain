import Foundation
import SwiftData

@MainActor final class SubtaskCommandReader {
    unowned let environment: SubtaskCommandEnvironment
    let catalogReader: TaskCreateTagCatalogReader
    init(environment: SubtaskCommandEnvironment) {
        self.environment = environment
        catalogReader = .init(context: environment.context, invalidation: .catalogFacts)
    }

    struct Observation {
        let parent: TodoItem
        let subtask: SubtaskItem?
        let preview: CommandSubtaskPreview
        var followUp: CommandTaskTitleContext {
            .init(dayKey: parent.dayKey, isDone: parent.isDone, calendarEventID: parent.calendarEventID)
        }
    }

    func prepare(in host: CommandOwnedHost) throws -> CommandSubtaskPreview {
        let item = try CommandSubtaskPreview.item(in: host)
        return try read(item, lease: host.lease, plan: host.session.plan.stamp, catalog: catalogReader.prepare()).preview
    }

    func validate(_ preview: CommandSubtaskPreview, item: CommandPlanItem) throws -> Observation {
        guard preview.semanticsVersion == 1, item.stamp == preview.item, item.draft.stamp == preview.draft,
              item.draft.arguments == preview.arguments else { throw SubtaskCommandIssue.stale }
        let observation = try read(item, lease: preview.lease, plan: preview.plan, catalog: catalogReader.current())
        guard observation.preview.source == preview.source, observation.preview.catalog == preview.catalog else {
            throw SubtaskCommandIssue.stale
        }
        guard observation.preview == preview else { throw SubtaskCommandIssue.fieldsChanged }
        return observation
    }

    func ensureCreationAvailable(_ accepted: CommandSubtaskAcceptance) throws {
        guard accepted.preview.input.edit.isCreation else { return }
        let id = accepted.object.id
        guard try environment.context.fetch(FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id })).isEmpty else {
            throw SubtaskCommandIssue.identityCollision
        }
    }

    func family(parent reference: CommandObjectReference?, target: CommandObjectReference?) throws -> (TodoItem, SubtaskItem?) {
        let context = environment.context
        let child = try target.map { try TaskFamilyCommandIdentity.subtask($0.id, in: context) }
        guard let parentID = reference?.id ?? child?.todo?.id else { throw SubtaskCommandIssue.invalidFamily }
        let parents = try SwiftDataTaskRepository(context: context).fetchTodos(withID: parentID)
        guard parents.count == 1, parents[0].modelContext === context, parents[0].deletedAt == nil,
              child == nil || child?.todo === parents[0] else { throw SubtaskCommandIssue.invalidFamily }
        let children = try TaskFamilyCommandIdentity.children(of: parents[0], in: context)
        guard child == nil || children.contains(where: { $0 === child }) else { throw SubtaskCommandIssue.invalidFamily }
        return (parents[0], child)
    }

    private func read(_ item: CommandPlanItem, lease: CommandHostLease, plan: CommandPlanStamp,
                      catalog: CommandTaskTagCatalog) throws -> Observation {
        try CommandSubtaskPreview.validate(item)
        try environment.validateClean()
        let input = try CommandSubtaskInput(item.draft)
        let (parent, child) = try family(parent: input.parent, target: input.target)
        let source = try environment.qualification(.init(command: item.draft.commandID,
            parent: .init(type: .todo, id: parent.id), target: input.target, arguments: item.draft.arguments))
        let latest = try family(parent: input.parent, target: input.target)
        guard latest.0 === parent, latest.1 === child else { throw SubtaskCommandIssue.invalidFamily }
        _ = try CommandTaskTitleTags.merge(rawIDs: parent.tagIDs, title: "", catalog: catalog)
        if let child { _ = try CommandTaskTitleTags.merge(rawIDs: child.tagIDs, title: "", catalog: catalog) }
        // 先证明资格，再复制最小可显示字段；父 notes 从未被读取来猜测资格。
        let original = child.map { CommandSubtaskOriginal(id: $0.id, record: ObjectIdentifier($0), parentID: parent.id,
            title: $0.title, isDone: $0.isDone, sortOrder: $0.sortOrder, createdAt: $0.createdAt, tagIDs: $0.tagIDs) }
        let siblings = input.edit.isCreation ? parent.subtasks.map {
            CommandSubtaskSibling(id: $0.id, record: ObjectIdentifier($0), sortOrder: $0.sortOrder, deletedAt: $0.deletedAt)
        }.sorted { $0.id.uuidString < $1.id.uuidString } : nil
        // 原末尾算法需要可表示的下一位；不能让坏排序值在明确接受后溢出。
        guard siblings?.contains(where: { $0.deletedAt == nil && $0.sortOrder == Int.max }) != true else {
            throw SubtaskCommandIssue.invalidFamily
        }
        let preview = CommandSubtaskPreview(lease: lease, plan: plan, item: item.stamp, draft: item.draft.stamp,
            arguments: item.draft.arguments, input: input,
            parent: .init(id: parent.id, record: ObjectIdentifier(parent), title: parent.title,
                          sourceBundleID: parent.sourceBundleID, tagIDs: parent.tagIDs),
            original: original, siblings: siblings, source: source, catalog: try catalog.evidence(),
            tags: try tags(input.edit, arguments: item.draft.arguments, rawIDs: child?.tagIDs ?? "", catalog: catalog))
        guard try catalogReader.current().evidence() == preview.catalog else { throw SubtaskCommandIssue.stale }
        try environment.validateClean()
        return .init(parent: parent, subtask: child, preview: preview)
    }

    private func tags(_ edit: CommandSubtaskEdit, arguments: [CommandArgument], rawIDs: String,
                      catalog: CommandTaskTagCatalog) throws -> CommandTaskTagMutation? {
        switch edit {
        case .completion: return nil
        case .tags(let argument): return try .prepare(rawIDs: rawIDs, argument: argument, catalog: catalog)
        case .create, .title:
            guard case .shortText(let title) = arguments.first(where: { $0.parameter == .title })?.value else {
                throw SubtaskCommandIssue.invalidArguments
            }
            if edit.isCreation {
                let plan = CommandTaskTagPlanning.compose(title: title,
                    argument: arguments.first(where: { $0.parameter == .tags }), catalog: catalog)
                guard plan.problems.isEmpty else { throw CommandTaskTitlePreviewIssue.tags(plan.problems) }
                return .init(original: [], final: plan.final.map(\.target), actions: plan)
            }
            let merged = try CommandTaskTitleTags.merge(rawIDs: rawIDs, title: title, catalog: catalog)
            return .init(original: merged.original, final: merged.final, actions: merged.syntax)
        }
    }
}
