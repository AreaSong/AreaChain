import Foundation

enum CommandTaskCreatePreviewIssue: Error, Equatable {
    case unsupportedPlan, protectedContent, notesNotSupported, invalidArguments([CommandArgumentIssue])
    case invalidCatalog, stale, sourceConflict(CommandParameterID), emptyEffectiveContent
}

/// 只读派生计划，不登记创建 UUID，不签发执行许可；原 Draft 仍是唯一可编辑参数来源。
struct CommandTaskCreatePreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    static let parsingVersion = 1
    static let compositionVersion = 1

    let binding: Binding
    let composition: CommandTaskCreateComposition
    let issues: [CommandTaskCreatePreviewIssue]
    private let originalArguments: [CommandArgument]
    let source: CommandTaskCreateSource

    var arguments: [CommandArgument] { originalArguments }

    struct Binding: Equatable {
        let lease: CommandHostLease
        let plan: CommandPlanStamp
        let item: CommandPlanItemStamp
        let draft: CommandDraftStamp
        let catalog: CommandTaskTagCatalog.Evidence
        let parsingVersion: Int
        let compositionVersion: Int
    }

    var canPrepareExecution: Bool { issues.isEmpty && composition.tags.problems.isEmpty }
    var isExecutable: Bool { false }
    /// 3T-2A2 的数据输入，仍需重读、事务身份与授权；含冲突时不提供可采用计划。
    var transactionPlan: CommandTaskCreateComposition? { canPrepareExecution ? composition : nil }

    static func prepare(in host: CommandOwnedHost, source: CommandTaskCreateSource,
                        catalog: CommandTaskTagCatalog) throws -> Self {
        let item = try eligibleItem(in: host)
        return try prepare(item: item, lease: host.lease, plan: host.session.plan.stamp, source: source, catalog: catalog)
    }

    static func prepare(item: CommandPlanItem, lease: CommandHostLease, plan: CommandPlanStamp,
                        source: CommandTaskCreateSource, catalog: CommandTaskTagCatalog) throws -> Self {
        try CommandHandoffCoordinator.validateTaskCreateItem(item, composed: true, allowingDependencies: true)
        let draft = item.draft
        guard !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
              source.protection == .ordinary, source.stampEnabled || source.bundleID.isEmpty else {
            throw CommandTaskCreatePreviewIssue.protectedContent
        }
        let fields = try inputFields(draft)
        let composition = CommandTaskCreateComposition.compose(title: fields.title, day: fields.day,
                                                               arguments: draft.arguments, catalog: catalog)
        var issues: [CommandTaskCreatePreviewIssue] = []
        if composition.priority.hasConflict { issues.append(.sourceConflict(.priority)) }
        if composition.reminder.hasConflict { issues.append(.sourceConflict(.time)) }
        if !composition.hasEffectiveContent { issues.append(.emptyEffectiveContent) }
        let evidence: CommandTaskTagCatalog.Evidence
        do { evidence = try catalog.evidence() }
        catch { throw CommandTaskCreatePreviewIssue.invalidCatalog }
        return Self(binding: .init(lease: lease, plan: plan, item: item.stamp,
                                   draft: draft.stamp, catalog: evidence, parsingVersion: parsingVersion,
                                   compositionVersion: compositionVersion),
                    composition: composition, issues: issues, originalArguments: draft.arguments, source: source)
    }

    /// 值比较不是协调者实时 lease 校验，也不能检测未推进读取代次的 ABA。未来写入前两者都必须完成。
    func validateCurrent(in host: CommandOwnedHost, source: CommandTaskCreateSource,
                         catalog: CommandTaskTagCatalog) throws {
        guard let current = try? Self.prepare(in: host, source: source, catalog: catalog), current == self else {
            throw CommandTaskCreatePreviewIssue.stale
        }
    }

    /// 封存后的原 Run 仍持有同一 draft；lease/plan/item 的接续由 Coordinator 独立核验。
    func validateCurrent(draft: CommandDraft, source: CommandTaskCreateSource,
                         catalog: CommandTaskTagCatalog) throws {
        guard draft.stamp == binding.draft, draft.arguments == originalArguments, source == self.source,
              binding.parsingVersion == Self.parsingVersion, binding.compositionVersion == Self.compositionVersion,
              try catalog.evidence() == binding.catalog, canPrepareExecution else {
            throw CommandTaskCreatePreviewIssue.stale
        }
        let fields = try Self.inputFields(draft)
        guard CommandTaskCreateComposition.compose(title: fields.title, day: fields.day,
              arguments: draft.arguments, catalog: catalog) == composition else { throw CommandTaskCreatePreviewIssue.stale }
    }

    private static func eligibleItem(in host: CommandOwnedHost) throws -> CommandPlanItem {
        let session = host.session
        guard host.lease.ownership.hostID == session.hostID, session.plan.hostID == session.hostID,
              session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1, let item = session.plan.items.first,
              item.draft.hostID == session.hostID, item.draft.commandID.rawValue == "todo.create",
              item.draft.targets == .none, item.draft.baseline == CommandDraftBaseline(),
              item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.hasSupportedOrigins, item.executionOrigin == nil else {
            throw CommandTaskCreatePreviewIssue.unsupportedPlan
        }
        return item
    }

    static func inputFields(_ draft: CommandDraft) throws -> (title: String, day: String) {
        guard !draft.arguments.contains(where: { $0.parameter == .notes }) else {
            throw CommandTaskCreatePreviewIssue.notesNotSupported
        }
        guard let command = CommandCatalog.standard.command(id: draft.commandID), command.createdObjectType == .todo else {
            throw CommandTaskCreatePreviewIssue.unsupportedPlan
        }
        let issues = CommandArgumentValidation.issues(for: draft.arguments, command: command)
        guard issues.isEmpty else { throw CommandTaskCreatePreviewIssue.invalidArguments(issues) }
        guard case .shortText(let title) = draft.arguments.first(where: { $0.parameter == .title })?.value,
              case .day(let day) = draft.arguments.first(where: { $0.parameter == .day })?.value else {
            throw CommandTaskCreatePreviewIssue.invalidArguments([.missing(.title), .missing(.day)])
        }
        guard !title.contains(where: \.isNewline), !NaturalLanguageParser.hasTaskNoteSeparator(title),
              NaturalLanguageParser.parseTaskCapture(title).notes.isEmpty else {
            throw CommandTaskCreatePreviewIssue.notesNotSupported
        }
        return (title, day)
    }

    var description: String { "CommandTaskCreatePreview(redacted)" }
    var debugDescription: String { description }
}
