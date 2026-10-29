import Foundation
import SwiftData

/// T8 互转只开放单个普通无备注对象：新建新 UUID 的对象并让原对象进回收站，不就地改类型。
enum CommandConvertEdit: String, CaseIterable, Equatable {
    case todoToRoutine = "todo.toRoutine", routineToTodo = "routine.toTodo"

    static let commands = Set(allCases.map(\.rawValue))

    init(command: CommandID) throws {
        guard let edit = Self(rawValue: command.rawValue) else { throw CommandConvertIssue.unsupportedPlan }
        self = edit
    }

    var sourceType: CommandObjectType { self == .todoToRoutine ? .todo : .routine }
    var createdType: CommandObjectType { self == .todoToRoutine ? .routine : .todo }

    func allows(_ targets: [CommandObjectReference]) -> Bool {
        targets.count == 1 && targets[0].type == sourceType && targets[0].dayKey == nil
    }
}

enum CommandConvertIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, stale, alreadyInvoked, invalidRepository
    case invalidTarget(CommandConvertProblem)
    case confirmationRequired, confirmationStale
    /// 上次保存结果未知且尚未核对：同一对象不能再次转换，避免重复创建。
    case verificationRequired
}

enum CommandConvertProblem: Equatable { case missing, duplicate, deleted, source, protectedContent, notes, family, changed }

/// 预览列出的字段损失与关联变化，与 ItemConversionService 实际写入一一对应；执行前后各核对一次。
enum CommandConvertLosses: Equatable {
    struct FromTodo: Equatable {
        /// 原日期只保留成每周的这一天。
        let dayKey: String
        let weekdayMask: Int
        let dueMinutes: Int?
        let wasDone: Bool
        let subtasks: Int
        let doneSubtasks: Int
        let attachments: Int
        /// 带备注：备注原样搬到新对象，确认面板单列一行。
        var notes = false
    }
    struct FromRoutine: Equatable {
        /// 新待办落在这一天（执行当天）；跨日后须重新预览。
        let today: String
        let weekdayMask: Int
        let isEnabled: Bool
        let paused: Bool
        let checks: Int
        let templates: Int
        let attachments: Int
        /// 带备注：备注原样搬到新对象，确认面板单列一行。
        var notes = false
    }
    case todoToRoutine(FromTodo), routineToTodo(FromRoutine)
}

/// 冻结目标的完整快照；确认前后任一字段或连带集合变化都要求重新预览。
struct CommandConvertImpact: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum Fingerprint: Equatable { case todo(TodoSnapshot), routine(RoutineSnapshot) }
    let target: CommandObjectReference
    let record: PersistentIdentifier
    let title: String
    let source: CommandTaskTitleEligibility
    let fingerprint: Fingerprint
    /// 会和原待办同戳进回收站的活子任务。
    let subtasks: Set<PersistentIdentifier>
    /// 会改挂到新对象的活附件。
    let attachments: Set<PersistentIdentifier>
    /// 留在原习惯上的打卡记录。
    let checks: Set<PersistentIdentifier>
    let losses: CommandConvertLosses
    var description: String { "CommandConvertImpact(redacted)" }
    var debugDescription: String { description }
}

struct CommandConvertPreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let targets: CommandDraftTargets
    let edit: CommandConvertEdit
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let impact: CommandConvertImpact
    let semanticsVersion = 1
    var description: String { "CommandConvertPreview(\(edit.rawValue))" }
    var debugDescription: String { description }

    static func input(in host: CommandOwnedHost) throws -> CommandPlanItem {
        guard let item = CommandIndependentPlan.onlyItem(in: host) else { throw CommandConvertIssue.unsupportedPlan }
        try validate(item)
        return item
    }

    static func validate(_ item: CommandPlanItem) throws {
        guard CommandIndependentPlan.isStandalone(item) else { throw CommandConvertIssue.unsupportedPlan }
        let edit = try CommandConvertEdit(command: item.draft.commandID)
        guard CommandIndependentPlan.isPlainTargetDraft(item.draft), edit.allows(item.draft.targets.objects) else {
            throw CommandConvertIssue.invalidArguments
        }
    }

    func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease) throws -> CommandPlanItem {
        guard let item = CommandIndependentPlan.frozenItem(in: run, lease: lease, previewLease: self.lease, plan: plan,
                                                           item: self.item, draft: draft, targets: targets) else {
            throw CommandConvertIssue.stale
        }
        try Self.validate(item)
        return item
    }
}

/// 新对象的 UUID 在接受时分配一次；之后的执行、回执与未知核对都用它，不另取。
struct CommandConvertAcceptance: Equatable {
    let id: UUID
    let createdID: UUID
    let preview: CommandConvertPreview
    var created: CommandObjectReference { .init(type: preview.edit.createdType, id: createdID) }

    var confirmationBinding: CommandConvertConfirmation.Binding {
        .init(acceptanceID: id, plan: preview.plan, item: preview.item, targets: preview.targets.objects,
              summary: preview.impact.losses)
    }
}

/// 转换的确认摘要是损失清单；与回收共用同一份确认绑定规则。
typealias CommandConvertConfirmation = CommandIndependentConfirmation<CommandConvertLosses>

@MainActor final class CommandConvertRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var acceptances: [UUID: CommandConvertAcceptance] = [:]
    private let ledger = CommandIndependentConfirmationLedger<CommandConvertLosses>()
    var confirmations: [UUID: CommandConvertConfirmation] { ledger.confirmations }
    private var invoked: Set<UUID> = []
    /// 保存结果未知的原对象 → 对应接受；核对出确定结果前不允许再准备转换。
    private(set) var unresolved: [CommandObjectReference: UUID] = [:]
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }

    func requireResolved(_ targets: [CommandObjectReference]) throws {
        guard targets.allSatisfy({ unresolved[$0] == nil }) else { throw CommandConvertIssue.verificationRequired }
    }

    func markUnknown(_ target: CommandObjectReference, acceptanceID: UUID) { unresolved[target] = acceptanceID }

    /// 只有核对给出确定结果才解除；不一致时保持阻止。
    func resolve(_ verification: CommandConvertVerification) {
        let target = verification.originalFacts.impact.target
        guard verification.outcome != .inconsistent, unresolved[target] == verification.originalFacts.acceptanceID else { return }
        unresolved[target] = nil
    }

    func accept(_ preview: CommandConvertPreview) throws -> CommandConvertAcceptance {
        try requireResolved(preview.targets.objects)
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) else { throw CommandConvertIssue.alreadyInvoked }
            if old.preview == preview { return old }
            ledger.revoke(acceptanceID: old.id)
        }
        let accepted = CommandConvertAcceptance(id: UUID(), createdID: UUID(), preview: preview)
        acceptances[preview.draft.draftID] = accepted
        return accepted
    }

    func confirm(_ accepted: CommandConvertAcceptance) throws -> CommandConvertConfirmation {
        guard acceptances[accepted.preview.draft.draftID] == accepted, !wasInvoked(accepted.id) else {
            throw CommandConvertIssue.confirmationStale
        }
        return ledger.issue(accepted.confirmationBinding, titles: [accepted.preview.impact.title])
    }

    func cancel(_ confirmation: CommandConvertConfirmation) { ledger.cancel(confirmation) }

    func confirmation(for accepted: CommandConvertAcceptance) throws -> CommandConvertConfirmation {
        switch ledger.lookup(accepted.confirmationBinding) {
        case .missing: throw CommandConvertIssue.confirmationRequired
        case .stale: throw CommandConvertIssue.confirmationStale
        case .current(let confirmation): return confirmation
        }
    }
}

/// 未知结果的只读核对：新对象按接受时的 UUID 查，原对象看软删状态。当前值不提升原 unknown 回执。
struct CommandConvertVerification: Equatable {
    enum Presence: Equatable { case absent, live, deleted, ambiguous, unreadable }
    enum Outcome: Equatable { case converted, notConverted, inconsistent }
    let operation: CommandOperationIdentity
    let attempt: CommandAttemptStamp
    let originalFacts: CommandConvertFacts
    let created: Presence
    let original: Presence

    var outcome: Outcome {
        switch (created, original) {
        case (.live, .deleted): return .converted
        case (.absent, .live): return .notConverted
        default: return .inconsistent
        }
    }
}
