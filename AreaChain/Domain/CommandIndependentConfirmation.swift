import Foundation

/// 独立确认的唯一绑定规则，回收（T-M4）与 T8 转换共用。确认只绑定接受时的计划戳、计划项、
/// 固定目标与各指令提供的摘要；摘要来自同一份冻结预览，不重新取样。
struct CommandIndependentConfirmation<Summary: Equatable>: Equatable, CustomStringConvertible,
    CustomDebugStringConvertible {
    struct Binding: Equatable {
        let acceptanceID: UUID
        let plan: CommandPlanStamp
        let item: CommandPlanItemStamp
        let targets: [CommandObjectReference]
        let summary: Summary
    }

    let id: UUID
    let acceptanceID: UUID
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let targets: [CommandObjectReference]
    let titles: [String]
    let summary: Summary
    /// 面板只列出前几个标题，其余以数量说明。
    static var sampleLimit: Int { 3 }
    var description: String { "CommandIndependentConfirmation(targets: \(targets.count))" }
    var debugDescription: String { description }

    fileprivate init(_ binding: Binding, titles: [String]) {
        id = UUID()
        acceptanceID = binding.acceptanceID
        plan = binding.plan
        item = binding.item
        targets = binding.targets
        self.titles = Array(titles.prefix(Self.sampleLimit))
        summary = binding.summary
    }

    func matches(_ binding: Binding) -> Bool {
        acceptanceID == binding.acceptanceID && plan == binding.plan && item == binding.item
            && targets == binding.targets && summary == binding.summary
    }
}

/// 每个接受最多一份有效确认；新接受、取消或拒绝都撤销旧确认，提交时必须仍与接受逐项一致。
@MainActor final class CommandIndependentConfirmationLedger<Summary: Equatable> {
    typealias Confirmation = CommandIndependentConfirmation<Summary>
    enum Lookup: Equatable { case missing, stale, current(Confirmation) }
    private(set) var confirmations: [UUID: Confirmation] = [:]

    func issue(_ binding: Confirmation.Binding, titles: [String]) -> Confirmation {
        let confirmation = Confirmation(binding, titles: titles)
        confirmations[binding.acceptanceID] = confirmation
        return confirmation
    }

    func revoke(acceptanceID: UUID) { confirmations[acceptanceID] = nil }

    func cancel(_ confirmation: Confirmation) {
        guard confirmations[confirmation.acceptanceID] == confirmation else { return }
        confirmations[confirmation.acceptanceID] = nil
    }

    func lookup(_ binding: Confirmation.Binding) -> Lookup {
        guard let confirmation = confirmations[binding.acceptanceID] else { return .missing }
        return confirmation.matches(binding) ? .current(confirmation) : .stale
    }
}

/// 需独立确认的指令只接受当前唯一的普通计划项：不入原子组、不接依赖或输出、不进多项计划。
enum CommandIndependentPlan {
    static func onlyItem(in host: CommandOwnedHost) -> CommandPlanItem? {
        let session = host.session
        guard session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1,
              let item = session.plan.items.first, item.draft.hostID == session.hostID else { return nil }
        return item
    }

    static func isStandalone(_ item: CommandPlanItem) -> Bool {
        guard item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.hasSupportedOrigins, item.executionOrigin == nil,
              let command = CommandCatalog.standard.command(id: item.draft.commandID) else { return false }
        return command.interactions.contains(.independentConfirmation)
    }

    /// 普通来源、无参数、无基线，只有固定目标。
    static func isPlainTargetDraft(_ draft: CommandDraft) -> Bool {
        !draft.blocksUnprotectedExport && draft.protectionRequirement == .ordinary
            && draft.baseline == CommandDraftBaseline() && draft.arguments.isEmpty && draft.check().staticallyValid
            && draft.targets.selection != .none
    }

    /// 封存后的 Run 必须仍是接受时那一项、那一份目标。
    static func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease, previewLease: CommandHostLease,
                           plan: CommandPlanStamp, item stamp: CommandPlanItemStamp, draft: CommandDraftStamp,
                           targets: CommandDraftTargets) -> CommandPlanItem? {
        guard run.multiPlan == nil, run.previewLeaseMatches(previewLease, current: lease, itemID: stamp.id),
              run.snapshot.stamp == plan, run.snapshot.items.count == 1, run.permitsMember(stamp.id),
              let item = run.snapshot.items.first(where: { $0.id == stamp.id }), item.stamp == stamp,
              item.draft.stamp == draft, item.draft.targets == targets,
              let command = CommandCatalog.standard.command(id: item.draft.commandID),
              run.resolvedInput(item.id) == .init(arguments: targets.argument(for: command).map { [$0] } ?? [],
                                                  targets: targets) else { return nil }
        return item
    }
}
