import Foundation
import SwiftData

/// X-1 简单修改指令的共用骨架：普通、无依赖、无创建输出、一次仓储调用即可完成的单目标、固定多目标或无目标指令。
/// 每个指令只提供目标形状、资格读取、参数到仓储调用的映射和文案；计划戳、冻结、事务、回执与未知核对都在骨架里。
enum CommandSimpleShape: Equatable {
    case none
    case single(CommandObjectType)
    /// 显式固定集合；一个对象也走固定集合，不接受“全部结果”。
    case fixed(CommandObjectType)
    /// 单个对象，类型可以是集合里的任一种（如同一天混排的待办或习惯）。
    case singleAny(Set<CommandObjectType>)
    /// 合并批 M-2：显式固定集合，对象可以是集合里的任意几种（如从待办、习惯、子任务、手记上解绑标签）。
    case fixedAny(Set<CommandObjectType>)

    func allows(_ targets: CommandDraftTargets) -> Bool {
        switch self {
        case .none: return targets.selection == .none && targets.objects.isEmpty
        case .single(let type):
            return targets.selection == .single && targets.objects.count == 1 && Self.plain(targets.objects, [type])
        case .fixed(let type):
            return [.single, .selected].contains(targets.selection) && !targets.objects.isEmpty && Self.plain(targets.objects, [type])
        case .singleAny(let types):
            return targets.selection == .single && targets.objects.count == 1 && Self.plain(targets.objects, types)
        case .fixedAny(let types):
            return [.single, .selected].contains(targets.selection) && !targets.objects.isEmpty && Self.plain(targets.objects, types)
        }
    }

    private static func plain(_ objects: [CommandObjectReference], _ types: Set<CommandObjectType>) -> Bool {
        objects.allSatisfy { types.contains($0.type) && $0.dayKey == nil }
    }
}

enum CommandSimpleIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, stale, alreadyInvoked
    case invalidTarget(CommandSimpleProblem)
    /// 上次保存结果未知且尚未核对：同一对象不能再准备，避免未核实就重试。
    case verificationRequired
    /// 合并批 M-2：需要独立确认的指令还没有在共用确认面板里确认（或确认已被撤销）。
    case confirmationRequired
}

enum CommandSimpleProblem: String, Equatable {
    case missing, duplicate, deleted, protected, empty, nameTaken, incompleteOrder, changed
    /// T-M6：来源不是普通内容、位置越界、父任务不符、不在那天的清单里、跨“带子任务”分组、正文超限、
    /// 没有可延期对象、日期不是今天、目标超过总量上限、快速新增解析不出内容。
    case protectedSource, outOfRange, parentMismatch, notListed, crossesGroup, tooLong, nothingToMove, notToday, tooMany, untitled
    /// L-M1b：正文解析出私密或预置标签（L7）；托管正文因锁定、遮罩或隐私变化不再借出（须返回编辑后重新预览）。
    case protectedTag, locked
    /// 合并批 M-2：要恢复的对象不在回收站里。
    case notTrashed
}

/// 预览里的一个值：本地化键、原文（用户内容）或带一个整数参数的本地化键（如“N 字”）。
enum CommandSimpleDisplay: Equatable {
    case verbatim(String), localized(String), count(String, Int)
}

/// 不属于字段变化、但要在预览与回执里说明的一行（如被跳过的预置标签）。
struct CommandSimpleNotice: Equatable {
    let key: String
    let title: String
    /// 为真时整条指令不可执行（如 L7 私密标签）；预览照常列出原因，接受被拒。
    var blocking = false
}

struct CommandSimpleField: Equatable {
    /// 稳定字段标识，界面用 `unified.simple.field.<id>` 显示名称。
    let id: String
    let value: String
    let display: CommandSimpleDisplay
}

/// 一行读取结果。key 是行的稳定身份，record 用来发现同 UUID 被替换；字段全部参与冻结比较。
struct CommandSimpleRow: Equatable {
    let key: String
    let record: PersistentIdentifier?
    let title: String
    let fields: [CommandSimpleField]
}

struct CommandSimpleState: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var rows: [CommandSimpleRow] = []
    var notices: [CommandSimpleNotice] = []
    var keys: Set<String> { Set(rows.map(\.key)) }
    var description: String { "CommandSimpleState(rows: \(rows.count))" }
    var debugDescription: String { description }

    /// 逐行逐字段列出变化；新行的原值为空。
    func changes(to after: CommandSimpleState) -> [CommandSimpleChange] {
        after.rows.flatMap { row -> [CommandSimpleChange] in
            let old = rows.first { $0.key == row.key }
            return row.fields.compactMap { field in
                let before = old?.fields.first { $0.id == field.id }
                guard before?.value != field.value else { return nil }
                return .init(key: row.key, title: row.title, field: field.id, before: before?.display, after: field.display)
            }
        }
    }
}

struct CommandSimpleChange: Equatable {
    let key: String
    let title: String
    let field: String
    let before: CommandSimpleDisplay?
    let after: CommandSimpleDisplay
}

/// 每个指令只给两句文案的本地化键：预览说明与保存后的回执。
struct CommandSimpleCopy: Equatable {
    let preview: String
    let saved: String
}

/// 规格方法收到的全部输入：冻结参数、新建对象的身份（准备时分配一次），以及冻结目标的行身份。
/// frozen 为 nil 表示按参数重新推出目标（准备与复核时），否则只读这些行（写后核对与未知核对）。
struct CommandSimpleCall: Equatable {
    let input: CommandResolvedInput
    var creation: CommandObjectReference?
    var frozen: Set<String>?
}

struct CommandSimplePreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let command: CommandID
    let input: CommandResolvedInput
    let environmentID: UUID
    let copy: CommandSimpleCopy
    let before: CommandSimpleState
    let after: CommandSimpleState
    /// 新建型指令在准备时分配的对象身份；接受与提交沿用同一个，重试不会另建。
    var creation: CommandObjectReference?
    let semanticsVersion = 1
    var noChange: Bool { before == after }
    var executable: Bool { !after.notices.contains(where: \.blocking) }
    /// 未知结果期间被锁定的行身份：原有目标与新建行都算；新建型指令另锁整条指令，未核对前不能再建。
    var lockKeys: Set<String> {
        before.keys.union(after.keys).union(creation == nil ? [] : ["create:" + command.rawValue])
    }
    var call: CommandSimpleCall { .init(input: input, creation: creation) }
    /// 写后与未知核对只读冻结的行，不按参数重新推出目标。
    var frozenCall: CommandSimpleCall { .init(input: input, creation: creation, frozen: before.keys.union(after.keys)) }
    var description: String { "CommandSimplePreview(\(command.rawValue))" }
    var debugDescription: String { description }

    /// 只接当前唯一的普通计划项：不入原子组、不接依赖或输出、不进多项计划。
    static func input(in host: CommandOwnedHost, shape: CommandSimpleShape) throws -> CommandPlanItem {
        let session = host.session
        guard session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1,
              let item = session.plan.items.first, item.draft.hostID == session.hostID else {
            throw CommandSimpleIssue.unsupportedPlan
        }
        try validate(item, shape: shape)
        return item
    }

    static func validate(_ item: CommandPlanItem, shape: CommandSimpleShape, longText: Bool = false) throws {
        let draft = item.draft
        guard item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.hasSupportedOrigins, item.executionOrigin == nil else { throw CommandSimpleIssue.unsupportedPlan }
        // 封存前的长文草稿只放开“普通、未托管的正文”（L1）；受保护、required、unknown 与计划里的印记仍拒绝。
        let exportable = longText ? !draft.blocksUnprotectedTransfer && draft.longTextImprints.isEmpty
            : !draft.blocksUnprotectedExport
        guard exportable, draft.protectionRequirement == .ordinary,
              draft.baseline == CommandDraftBaseline(), draft.check().staticallyValid,
              shape.allows(draft.targets) else { throw CommandSimpleIssue.invalidArguments }
    }

    /// 长文规格的准备入口：与 `input(in:shape:)` 同一计划约束，只是正文仍在宿主草稿里（由托管同步读取）。
    static func longTextInput(in host: CommandOwnedHost, shape: CommandSimpleShape) throws -> CommandPlanItem {
        let session = host.session
        guard session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1,
              let item = session.plan.items.first, item.draft.hostID == session.hostID else {
            throw CommandSimpleIssue.unsupportedPlan
        }
        try validate(item, shape: shape, longText: true)
        return item
    }

    /// 封存后的 Run 必须仍是接受时那一项、那一份参数与目标。
    func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease, shape: CommandSimpleShape) throws -> CommandPlanItem {
        guard run.multiPlan == nil, run.previewLeaseMatches(self.lease, current: lease, itemID: item.id),
              run.snapshot.stamp == plan, run.snapshot.items.count == 1, run.permitsMember(item.id),
              let frozen = run.snapshot.items.first(where: { $0.stamp == item }), frozen.draft.stamp == draft,
              run.resolvedInput(frozen.id) == input, try frozen.checkedInput() == input else { throw CommandSimpleIssue.stale }
        try Self.validate(frozen, shape: shape)
        return frozen
    }
}

struct CommandSimpleAcceptance: Equatable {
    let id: UUID
    let preview: CommandSimplePreview
}

/// 未知结果的只读核对：当前值等于预期即已写入，等于原值即未写入；当前值不提升原 unknown 回执。
struct CommandSimpleVerification: Equatable {
    enum Outcome: String, Equatable { case applied, notApplied, inconsistent }
    let acceptanceID: UUID
    let outcome: Outcome
}

@MainActor final class CommandSimpleRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    /// 协调者持有的带键摘要（L6）；随协调者存在，只在内存。
    let textDigest = CommandTextDigest()
    /// 合并批 M-2：需要独立确认的简单指令沿共享的确认登记（见 CommandSimpleConfirmation.swift）。
    let confirmations = CommandIndependentConfirmationLedger<CommandSimpleConfirmationSummary>()
    private(set) var acceptances: [UUID: CommandSimpleAcceptance] = [:]
    private var invoked: Set<UUID> = []
    private var notApplied: Set<UUID> = []
    /// 保存结果未知的行身份 → 对应接受；核对出确定结果前不允许再准备。
    private(set) var unresolved: [String: UUID] = [:]
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }

    func requireResolved(_ keys: Set<String>) throws {
        guard keys.allSatisfy({ unresolved[$0] == nil }) else { throw CommandSimpleIssue.verificationRequired }
    }

    func markUnknown(_ preview: CommandSimplePreview, acceptanceID: UUID) {
        for key in preview.lockKeys { unresolved[key] = acceptanceID }
    }

    /// 只有确定结果才解除；不一致时保持阻止。
    func resolve(_ verification: CommandSimpleVerification) {
        guard verification.outcome != .inconsistent else { return }
        if verification.outcome == .notApplied { notApplied.insert(verification.acceptanceID) }
        unresolved = unresolved.filter { $0.value != verification.acceptanceID }
    }

    func verifiedNotApplied(_ acceptanceID: UUID) -> Bool { notApplied.contains(acceptanceID) }

    /// 长文 Run 归还草稿后放开该草稿的接受；草稿版本已推进，旧接受不会再匹配新预览。
    func release(_ draftID: UUID) { acceptances[draftID] = nil }

    func accept(_ preview: CommandSimplePreview) throws -> CommandSimpleAcceptance {
        guard preview.executable else { throw CommandSimpleIssue.invalidTarget(.protectedTag) }
        try requireResolved(preview.lockKeys)
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) else { throw CommandSimpleIssue.alreadyInvoked }
            if old.preview == preview { return old }
            confirmations.revoke(acceptanceID: old.id)
        }
        let accepted = CommandSimpleAcceptance(id: UUID(), preview: preview)
        acceptances[preview.draft.draftID] = accepted
        return accepted
    }
}
