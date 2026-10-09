import Foundation
import SwiftData

/// 显式 context 的只读装配；不提供 handler，也不默认读取生产 Persistence 或猜测普通来源。
@MainActor
final class TaskTitleCommandPreviewReader {
    private let context: ModelContext
    private let repository: any TaskRepositoryProtocol
    private let sourceProtection: @MainActor () throws -> CommandProtectionRequirement
    private let environmentID = UUID()
    private let sourceRevision: @MainActor () throws -> UUID?
    private let catalogReader: TaskCreateTagCatalogReader

    init(context: ModelContext, sourceProtection: @escaping @MainActor () throws -> CommandProtectionRequirement,
         repository: (any TaskRepositoryProtocol)? = nil,
         sourceRevision: @escaping @MainActor () throws -> UUID? = { nil }) {
        self.sourceRevision = sourceRevision
        self.context = context
        self.sourceProtection = sourceProtection
        self.repository = repository ?? SwiftDataTaskRepository(context: context)
        catalogReader = TaskCreateTagCatalogReader(context: context, invalidation: .catalogFacts)
    }

    func owns(_ source: CommandTaskTitleSource) -> Bool {
        source.environmentID == environmentID && source.contextID == ObjectIdentifier(context)
            && source.storageID == ObjectIdentifier(context.container)
    }

    func verifyOrdinaryTags(_ rawIDs: String) throws {
        _ = try CommandTaskTitleTags.merge(rawIDs: rawIDs, title: "", catalog: catalogReader.current())
    }

    func prepare(in host: CommandOwnedHost) throws -> CommandTaskTitlePreview {
        _ = try CommandTaskTitlePreview.input(in: host)
        return try read(in: host, catalog: catalogReader.prepare())
    }

    func prepareMember(item: CommandPlanItem, targets: CommandDraftTargets, lease: CommandHostLease,
                       plan: CommandPlanStamp) throws -> CommandTaskTitlePreview {
        let input = try CommandTaskTitlePreview.resolvedInput(item: item, targets: targets)
        let catalog = try catalogReader.current()
        let observation = try read(input, catalog: catalog)
        return try .prepare(input: input, lease: lease, plan: plan, source: observation.source,
                            catalog: catalog, impact: observation.impact, context: observation.followUp)
    }

    func prepareChain(in host: CommandOwnedHost, binding: CommandTaskChainBinding) throws -> CommandTaskTitlePreview {
        guard let run = host.session.execution else { throw TaskTitleCommandIssue.stale }
        let input = try CommandTaskTitlePreview.chainInput(in: run, binding: binding)
        let catalog = try catalogReader.prepare()
        let observation = try read(input, catalog: catalog)
        return try .prepare(input: input, lease: host.lease, plan: run.snapshot.stamp, source: observation.source,
                            catalog: catalog, impact: observation.impact, context: observation.followUp, chain: binding)
    }

    /// 此核对仍不是授权：B2 必须再核验协调者实时 lease、干净 context、唯一身份并在同步边界写入。
    func validateCurrent(_ preview: CommandTaskTitlePreview, in host: CommandOwnedHost) throws -> CommandTaskTitlePreview {
        let current = try read(in: host, catalog: catalogReader.current())
        try preview.validateCurrent(current)
        return current
    }

    private func read(in host: CommandOwnedHost, catalog: CommandTaskTagCatalog) throws -> CommandTaskTitlePreview {
        let input = try CommandTaskTitlePreview.input(in: host)
        let observation = try read(input, catalog: catalog)
        return try .prepare(in: host, source: observation.source, catalog: catalog,
                            impact: observation.impact, context: observation.followUp)
    }

    struct Observation {
        let todo: TodoItem
        let source: CommandTaskTitleSource
        let impact: CommandTaskTitleImpact
        let followUp: CommandTaskTitleContext
    }

    /// 不推进目录读取代次；重新核对原接受的实际字段、目录和真实 Run。
    func validateFrozen(_ preview: CommandTaskTitlePreview, run: CommandExecutionRun,
                        lease: CommandHostLease) throws -> Observation {
        let input = try preview.frozenInput(in: run, lease: lease)
        return try validateObserved(preview, input: input)
    }

    /// 接受/提交前仍核对真实可编辑计划；字段和目录冲突不折叠成自动刷新。
    func validateAccepted(_ preview: CommandTaskTitlePreview, in host: CommandOwnedHost) throws -> Observation {
        let input = try CommandTaskTitlePreview.input(in: host)
        guard host.lease == preview.binding.lease, host.session.plan.stamp == preview.binding.plan,
              input.item.stamp == preview.binding.item, input.item.draft.stamp == preview.binding.draft,
              input.item.draft.arguments == preview.arguments, input.item.draft.baseline == preview.draftBaseline,
              input.target == preview.impact.target, input.edit == preview.impact.edit,
              preview.binding.parsingVersion == CommandTaskTitlePreview.parsingVersion,
              preview.binding.impactVersion == CommandTaskTitlePreview.impactVersion else {
            throw TaskTitleCommandIssue.stale
        }
        return try validateObserved(preview, input: input)
    }

    private func validateObserved(_ preview: CommandTaskTitlePreview,
                                  input: CommandTaskTitlePreview.Input) throws -> Observation {
        let catalog = try catalogReader.current()
        guard try catalog.evidence() == preview.binding.catalog else { throw TaskTitleCommandIssue.catalogChanged }
        let current = try read(input, catalog: catalog)
        try preview.binding.multiOutput?.validate(context: ObjectIdentifier(context),
                                                  storage: ObjectIdentifier(context.container), record: current.todo.persistentModelID)
        guard current.source == preview.binding.source else { throw TaskTitleCommandIssue.sourceChanged }
        let changed = Set(preview.impact.writeFields.filter {
            current.impact.originalValues[$0] != preview.impact.originalValues[$0]
        })
        guard changed.isEmpty else { throw TaskTitleCommandIssue.fieldsChanged(changed) }
        guard current.impact == preview.impact else { throw CommandTaskTitlePreviewIssue.stale }
        return current
    }

    private func read(_ input: CommandTaskTitlePreview.Input, catalog: CommandTaskTagCatalog) throws -> Observation {
        let protection: CommandProtectionRequirement
        let revision: UUID?
        do { protection = try sourceProtection(); revision = try sourceRevision() }
        catch let issue as TaskTitleCommandIssue { throw issue }
        catch { throw CommandTaskTitlePreviewIssue.storageUnavailable }
        guard protection == .ordinary else { throw CommandTaskTitlePreviewIssue.protectedContent }
        // 来源闭包是最后一个可重入读取；它返回后再次核对目录，不能用回调前的采样写入。
        guard try catalogReader.current().evidence() == catalog.evidence() else { throw TaskTitleCommandIssue.catalogChanged }
        let rows: [TodoItem]
        do { rows = try repository.fetchTodos(withID: input.target.id) }
        catch { throw CommandTaskTitlePreviewIssue.storageUnavailable }
        guard !rows.isEmpty else { throw CommandTaskTitlePreviewIssue.missingTarget }
        guard rows.count == 1 else { throw CommandTaskTitlePreviewIssue.duplicateTarget }
        let todo = rows[0]
        guard todo.id == input.target.id, todo.modelContext === context else { throw CommandTaskTitlePreviewIssue.invalidTarget }
        guard todo.deletedAt == nil else { throw CommandTaskTitlePreviewIssue.deletedTarget }
        let tags = try CommandTaskTitleTags.merge(rawIDs: todo.tagIDs, title: input.title, catalog: catalog)
        // 资格先于标题投影；不显式读取 notes，也不调用包含正文的完整 snapshot。
        var values: [TaskTitleField: TaskTitleFieldValue] = [.title: .text(todo.title), .tagIDs: .text(todo.tagIDs)]
        if input.edit.priority != nil {
            values[.isImportant] = .flag(todo.isImportant)
            values[.isUrgent] = .flag(todo.isUrgent)
        }
        if input.edit.remindMinutes != nil { values[.remindMinutes] = .minutes(todo.remindMinutes) }
        let source = CommandTaskTitleSource(environmentID: environmentID, contextID: ObjectIdentifier(context),
                                            storageID: ObjectIdentifier(context.container), protection: protection, revision: revision)
        return .init(todo: todo, source: source,
                     impact: .init(target: input.target, edit: input.edit, originalValues: values, tags: tags),
                     followUp: .init(dayKey: todo.dayKey, isDone: todo.isDone, calendarEventID: todo.calendarEventID))
    }
}
