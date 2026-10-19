import Foundation
import SwiftData

/// X-1 简单修改指令的共用骨架：普通、无依赖、无创建输出、一次仓储调用即可完成的单目标、固定多目标或无目标指令。
/// 每个指令只提供目标形状、资格读取、参数到仓储调用的映射和文案；计划戳、冻结、事务、回执与未知核对都在骨架里。
enum CommandSimpleShape: Equatable {
    case none
    case single(CommandObjectType)
    /// 显式固定集合；一个对象也走固定集合，不接受“全部结果”。
    case fixed(CommandObjectType)

    func allows(_ targets: CommandDraftTargets) -> Bool {
        switch self {
        case .none: return targets.selection == .none && targets.objects.isEmpty
        case .single(let type):
            return targets.selection == .single && targets.objects.count == 1 && Self.plain(targets.objects, type)
        case .fixed(let type):
            return [.single, .selected].contains(targets.selection) && !targets.objects.isEmpty && Self.plain(targets.objects, type)
        }
    }

    private static func plain(_ objects: [CommandObjectReference], _ type: CommandObjectType) -> Bool {
        objects.allSatisfy { $0.type == type && $0.dayKey == nil }
    }
}

enum CommandSimpleIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, stale, alreadyInvoked
    case invalidTarget(CommandSimpleProblem)
    /// 上次保存结果未知且尚未核对：同一对象不能再准备，避免未核实就重试。
    case verificationRequired
}

enum CommandSimpleProblem: String, Equatable {
    case missing, duplicate, deleted, protected, empty, nameTaken, incompleteOrder, changed
}

/// 预览里的一个值：本地化键或原文（用户内容）。
enum CommandSimpleDisplay: Equatable {
    case verbatim(String), localized(String)
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
    let semanticsVersion = 1
    var noChange: Bool { before == after }
    /// 未知结果期间被锁定的行身份：原有目标与新建行都算。
    var lockKeys: Set<String> { before.keys.union(after.keys) }
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

    static func validate(_ item: CommandPlanItem, shape: CommandSimpleShape) throws {
        let draft = item.draft
        guard item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.hasSupportedOrigins, item.executionOrigin == nil else { throw CommandSimpleIssue.unsupportedPlan }
        guard !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
              draft.baseline == CommandDraftBaseline(), draft.check().staticallyValid,
              shape.allows(draft.targets) else { throw CommandSimpleIssue.invalidArguments }
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
    private(set) var acceptances: [UUID: CommandSimpleAcceptance] = [:]
    private var invoked: Set<UUID> = []
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
        unresolved = unresolved.filter { $0.value != verification.acceptanceID }
    }

    func accept(_ preview: CommandSimplePreview) throws -> CommandSimpleAcceptance {
        try requireResolved(preview.lockKeys)
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) else { throw CommandSimpleIssue.alreadyInvoked }
            if old.preview == preview { return old }
        }
        let accepted = CommandSimpleAcceptance(id: UUID(), preview: preview)
        acceptances[preview.draft.draftID] = accepted
        return accepted
    }
}
