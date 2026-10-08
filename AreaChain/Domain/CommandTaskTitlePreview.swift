import Foundation

/// 只有读取与比较能力，没有接受、调用占用或执行能力；不把预览当写入许可。
struct CommandTaskTitlePreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    static let parsingVersion = 1
    static let impactVersion = 1

    struct Binding: Equatable {
        let lease: CommandHostLease
        let plan: CommandPlanStamp
        let item: CommandPlanItemStamp
        let draft: CommandDraftStamp
        let source: CommandTaskTitleSource
        let catalog: CommandTaskTagCatalog.Evidence
        let parsingVersion: Int
        let impactVersion: Int
        var chain: CommandTaskChainBinding?
    }

    let binding: Binding
    let impact: CommandTaskTitleImpact
    let followUpContext: CommandTaskTitleContext
    let arguments: [CommandArgument]
    let draftBaseline: CommandDraftBaseline
    var baseline: CommandDraftBaseline { impact.baseline }
    var isExecutable: Bool { false }

    struct Input {
        let item: CommandPlanItem
        let target: CommandObjectReference
        let title: String
        let edit: TaskTitleEdit
    }

    static func input(in host: CommandOwnedHost) throws -> Input {
        let session = host.session
        guard host.lease.ownership.hostID == session.hostID, session.plan.hostID == session.hostID,
              session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1, let item = session.plan.items.first,
              item.draft.hostID == session.hostID, item.draft.commandID.rawValue == "todo.title",
              item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.mergedOrigins.isEmpty, item.returnedAttempts.isEmpty else {
            throw CommandTaskTitlePreviewIssue.unsupportedPlan
        }
        return try input(item: item, hostID: session.hostID)
    }

    /// 可编辑计划和冻结 Run 共用资格；调用者仍须分别验证真实所有权和运行输入。
    static func input(item: CommandPlanItem, hostID: String) throws -> Input {
        guard item.draft.hostID == hostID, item.draft.commandID.rawValue == "todo.title",
              item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.mergedOrigins.isEmpty, item.returnedAttempts.isEmpty else {
            throw CommandTaskTitlePreviewIssue.unsupportedPlan
        }
        return try resolvedInput(item: item, targets: item.draft.targets)
    }

    /// 只验证参数与真实目标；链的身份/依赖必须先由 chainInput 检查，原单项入口不放宽。
    static func resolvedInput(item: CommandPlanItem, targets: CommandDraftTargets) throws -> Input {
        let draft = item.draft
        guard !draft.arguments.contains(where: { $0.parameter == .notes }),
              draft.baseline.original(.notes, targets: draft.targets) == nil else {
            throw CommandTaskTitlePreviewIssue.notesNotSupported
        }
        guard !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
              draft.baseline.isReadable else { throw CommandTaskTitlePreviewIssue.protectedContent }
        guard let command = CommandCatalog.standard.command(id: draft.commandID),
              CommandArgumentValidation.issues(for: draft.arguments + (targets.argument(for: command).map { [$0] } ?? []), command: command).isEmpty,
              targets.issues(for: command).isEmpty, draft.arguments.count == 1,
              draft.arguments[0].parameter == .title, draft.arguments[0].operation == .assign,
              case .shortText(let title) = draft.arguments[0].value,
              targets.selection == .single, let target = targets.objects.first,
              target.type == .todo, target.dayKey == nil else { throw CommandTaskTitlePreviewIssue.invalidArguments }
        guard !title.contains(where: \.isNewline), !NaturalLanguageParser.hasTaskNoteSeparator(title),
              let edit = TaskTitleEdit(title), edit.notes == nil else { throw CommandTaskTitlePreviewIssue.notesNotSupported }
        guard !edit.title.isEmpty else { throw CommandTaskTitlePreviewIssue.emptyTitle }
        return Input(item: item, target: target, title: title, edit: edit)
    }

    static func prepare(in host: CommandOwnedHost, source: CommandTaskTitleSource, catalog: CommandTaskTagCatalog,
                        impact: CommandTaskTitleImpact, context: CommandTaskTitleContext) throws -> Self {
        let input = try input(in: host)
        return try prepare(input: input, lease: host.lease, plan: host.session.plan.stamp,
                           source: source, catalog: catalog, impact: impact, context: context)
    }

    static func prepare(input: Input, lease: CommandHostLease, plan: CommandPlanStamp,
                        source: CommandTaskTitleSource, catalog: CommandTaskTagCatalog,
                        impact: CommandTaskTitleImpact, context: CommandTaskTitleContext,
                        chain: CommandTaskChainBinding? = nil) throws -> Self {
        guard source.protection == .ordinary else { throw CommandTaskTitlePreviewIssue.protectedContent }
        guard input.target == impact.target, input.edit == impact.edit,
              Set(impact.originalValues.keys) == input.edit.writeFields,
              case .text(let rawIDs) = impact.originalValues[.tagIDs],
              try CommandTaskTitleTags.merge(rawIDs: rawIDs, title: input.title, catalog: catalog) == impact.tags else {
            throw CommandTaskTitlePreviewIssue.invalidBaseline
        }
        let draft = input.item.draft
        guard draft.baseline.preference == nil, draft.baseline.preferenceGroup == nil,
              draft.baseline.values.allSatisfy({ impact.baseline.values[$0.key] == $0.value }) else {
            throw CommandTaskTitlePreviewIssue.invalidBaseline
        }
        return Self(binding: .init(lease: lease, plan: plan, item: input.item.stamp,
                                   draft: draft.stamp, source: source, catalog: try catalog.evidence(),
                                   parsingVersion: parsingVersion, impactVersion: impactVersion, chain: chain),
                    impact: impact, followUpContext: context, arguments: draft.arguments, draftBaseline: draft.baseline)
    }

    /// 上下文不属于冲突基线；调用者使用返回的新预览取最新后续上下文，不能复用旧采样执行。
    func validateCurrent(_ current: Self) throws {
        guard binding == current.binding, impact == current.impact, arguments == current.arguments,
              draftBaseline == current.draftBaseline,
              binding.parsingVersion == Self.parsingVersion, binding.impactVersion == Self.impactVersion else {
            throw CommandTaskTitlePreviewIssue.stale
        }
    }

    /// 只接受原封存输入，不能用清空 execution 的临时 Host 重新准备。
    func frozenInput(in run: CommandExecutionRun, lease: CommandHostLease) throws -> Input {
        guard binding.parsingVersion == Self.parsingVersion, binding.impactVersion == Self.impactVersion else {
            throw CommandTaskTitlePreviewIssue.stale
        }
        if let chain = binding.chain {
            guard lease == binding.lease, chain.attempt == run.attempt(chain.identity.consumer.id),
                  run.snapshot.stamp == binding.plan else { throw CommandTaskTitlePreviewIssue.stale }
            let input = try Self.chainInput(in: run, binding: chain)
            guard input.item.stamp == binding.item, input.item.draft.stamp == binding.draft,
                  input.item.draft.arguments == arguments, input.item.draft.baseline == draftBaseline,
                  input.target == impact.target, input.edit == impact.edit else { throw CommandTaskTitlePreviewIssue.stale }
            return input
        }
        guard binding.parsingVersion == Self.parsingVersion, binding.impactVersion == Self.impactVersion,
              lease.ownership == binding.lease.ownership, lease.revision == binding.lease.revision + 2,
              run.snapshot.stamp == binding.plan, run.snapshot.items.count == 1,
              let item = run.snapshot.items.first, item.stamp == binding.item, item.draft.stamp == binding.draft,
              item.draft.arguments == arguments, item.draft.baseline == draftBaseline,
              run.outputs.isEmpty else { throw CommandTaskTitlePreviewIssue.stale }
        let input = try Self.input(item: item, hostID: lease.ownership.hostID)
        // Run 会沿原 targets.argument 投影加入 target；原草稿参数本身不持有第二份 target。
        guard let command = CommandCatalog.standard.command(id: item.draft.commandID),
              let targetArgument = item.draft.targets.argument(for: command),
              run.resolvedInput(item.id) == CommandResolvedInput(arguments: arguments + [targetArgument], targets: item.draft.targets),
              input.target == impact.target, input.edit == impact.edit else { throw CommandTaskTitlePreviewIssue.stale }
        return input
    }

    var description: String { "CommandTaskTitlePreview(redacted)" }
    var debugDescription: String { description }
}
