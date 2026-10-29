import Foundation
import SwiftData

/// 回收只开放可恢复软删；永久删除、恢复和多项计划继续关闭。
enum CommandTrashEdit: String, CaseIterable, Equatable {
    case todo = "todo.trash", subtask = "subtask.delete", routine = "routine.trash", batch = "batch.trash"

    static let commands = Set(allCases.map(\.rawValue))

    init(command: CommandID) throws {
        guard let edit = Self(rawValue: command.rawValue) else { throw CommandTrashIssue.unsupportedPlan }
        self = edit
    }

    /// 单项指令只接一个普通对象；批量只接待办与习惯的固定集合。
    func allows(_ targets: [CommandObjectReference]) -> Bool {
        guard !targets.isEmpty, targets.allSatisfy({ $0.dayKey == nil }) else { return false }
        switch self {
        case .todo: return targets.count == 1 && targets[0].type == .todo
        case .subtask: return targets.count == 1 && targets[0].type == .subtask
        case .routine: return targets.count == 1 && targets[0].type == .routine
        case .batch: return targets.allSatisfy { [.todo, .routine].contains($0.type) }
        }
    }
}

enum CommandTrashIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, stale, alreadyInvoked, invalidRepository
    case invalidTargets([CommandTrashTargetProblem])
    case confirmationRequired, confirmationStale
    case writeLimit(CommandTrashCounts)
}

struct CommandTrashTargetProblem: Equatable {
    enum Reason: Equatable { case missing, duplicate, deleted, source, protectedContent, notes, family, changed }
    let target: CommandObjectReference
    let reason: Reason
}

/// 只统计本次会一起打上删除戳的实体，不含此前已独立删除的子项或附件。
struct CommandTrashCounts: Equatable {
    let targets: Int
    let subtasks: Int
    let attachments: Int
    /// 带备注的目标数：备注随对象一起进回收站，只用于确认说明，不另计写入实体。
    var notes = 0
    var total: Int { targets + subtasks + attachments }
    var limit: Int { CommandBatchWriteSet.Counts.entityLimit }
    var exceedsLimit: Bool { total > limit }
}

extension CommandTrashCounts {
    init(_ impacts: [CommandTrashTargetImpact]) {
        var subtasks = 0, attachments = 0
        for impact in impacts {
            subtasks += impact.subtasks.count
            attachments += impact.attachments.count
        }
        self.init(targets: impacts.count, subtasks: subtasks, attachments: attachments,
                  notes: impacts.filter { $0.source.notes.isPresent }.count)
    }
}

/// 冻结目标的完整快照；确认前任一字段变化都要求重新预览。
struct CommandTrashTargetImpact: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum Fingerprint: Equatable {
        case todo(TodoSnapshot), routine(RoutineSnapshot), subtask(SubtaskSnapshot, parent: TodoSnapshot)
    }
    let target: CommandObjectReference
    let record: PersistentIdentifier
    let title: String
    let source: CommandTaskTitleEligibility
    let parent: CommandObjectReference?
    let parentSource: CommandTaskTitleEligibility?
    let parentTitle: String?
    let fingerprint: Fingerprint
    let subtasks: Set<PersistentIdentifier>
    let attachments: Set<PersistentIdentifier>
    var description: String { "CommandTrashTargetImpact(redacted)" }
    var debugDescription: String { description }
}

struct CommandTrashPreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let targets: CommandDraftTargets
    let edit: CommandTrashEdit
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let impacts: [CommandTrashTargetImpact]
    let semanticsVersion = 1
    var counts: CommandTrashCounts { .init(impacts) }
    var description: String { "CommandTrashPreview(targets: \(targets.objects.count))" }
    var debugDescription: String { description }

    func validateLimit() throws {
        guard edit == .batch else { return }
        guard !counts.exceedsLimit else { throw CommandTrashIssue.writeLimit(counts) }
    }

    /// 只读当前唯一计划项；回收项不能与其他计划项组成多项计划。
    static func input(in host: CommandOwnedHost) throws -> CommandPlanItem {
        guard let item = CommandIndependentPlan.onlyItem(in: host) else { throw CommandTrashIssue.unsupportedPlan }
        try validate(item)
        return item
    }

    static func validate(_ item: CommandPlanItem) throws {
        guard CommandIndependentPlan.isStandalone(item) else { throw CommandTrashIssue.unsupportedPlan }
        let edit = try CommandTrashEdit(command: item.draft.commandID)
        guard CommandIndependentPlan.isPlainTargetDraft(item.draft), edit.allows(item.draft.targets.objects) else {
            throw CommandTrashIssue.invalidArguments
        }
    }

    func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease) throws -> CommandPlanItem {
        guard let item = CommandIndependentPlan.frozenItem(in: run, lease: lease, previewLease: self.lease, plan: plan,
                                                           item: self.item, draft: draft, targets: targets) else {
            throw CommandTrashIssue.stale
        }
        try Self.validate(item)
        return item
    }
}

struct CommandTrashAcceptance: Equatable {
    let id: UUID
    let preview: CommandTrashPreview
}

extension CommandTrashAcceptance {
    var confirmationBinding: CommandTrashConfirmation.Binding {
        .init(acceptanceID: id, plan: preview.plan, item: preview.item, targets: preview.targets.objects,
              summary: preview.counts)
    }
}

/// 回收的确认摘要是连带计数；绑定、撤销与核对沿共享的 CommandIndependentConfirmationLedger。
typealias CommandTrashConfirmation = CommandIndependentConfirmation<CommandTrashCounts>

extension CommandIndependentConfirmation where Summary == CommandTrashCounts {
    var counts: CommandTrashCounts { summary }
}

@MainActor final class CommandTrashRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var acceptances: [UUID: CommandTrashAcceptance] = [:]
    private let ledger = CommandIndependentConfirmationLedger<CommandTrashCounts>()
    var confirmations: [UUID: CommandTrashConfirmation] { ledger.confirmations }
    private var invoked: Set<UUID> = []
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }

    /// 新接受总是撤销旧确认；确认不能跨越目标或计划的任何修订。
    func accept(_ preview: CommandTrashPreview) throws -> CommandTrashAcceptance {
        try preview.validateLimit()
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) else { throw CommandTrashIssue.alreadyInvoked }
            if old.preview == preview { return old }
            ledger.revoke(acceptanceID: old.id)
        }
        let accepted = CommandTrashAcceptance(id: UUID(), preview: preview)
        acceptances[preview.draft.draftID] = accepted
        return accepted
    }

    func confirm(_ accepted: CommandTrashAcceptance) throws -> CommandTrashConfirmation {
        guard acceptances[accepted.preview.draft.draftID] == accepted, !wasInvoked(accepted.id) else {
            throw CommandTrashIssue.confirmationStale
        }
        try accepted.preview.validateLimit()
        return ledger.issue(accepted.confirmationBinding, titles: accepted.preview.impacts.map(\.title))
    }

    func cancel(_ confirmation: CommandTrashConfirmation) { ledger.cancel(confirmation) }

    func confirmation(for accepted: CommandTrashAcceptance) throws -> CommandTrashConfirmation {
        switch ledger.lookup(accepted.confirmationBinding) {
        case .missing: throw CommandTrashIssue.confirmationRequired
        case .stale: throw CommandTrashIssue.confirmationStale
        case .current(let confirmation): return confirmation
        }
    }
}
