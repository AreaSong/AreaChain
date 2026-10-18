import Foundation
import SwiftData

/// T-M4 回收只开放可恢复软删；永久删除、恢复和多项计划继续关闭。
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
        self.init(targets: impacts.count, subtasks: subtasks, attachments: attachments)
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
        let session = host.session
        guard session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1,
              let item = session.plan.items.first, item.draft.hostID == session.hostID else {
            throw CommandTrashIssue.unsupportedPlan
        }
        try validate(item)
        return item
    }

    static func validate(_ item: CommandPlanItem) throws {
        let draft = item.draft
        guard item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.hasSupportedOrigins, item.executionOrigin == nil,
              let command = CommandCatalog.standard.command(id: draft.commandID),
              command.interactions.contains(.independentConfirmation) else { throw CommandTrashIssue.unsupportedPlan }
        let edit = try CommandTrashEdit(command: draft.commandID)
        guard !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
              draft.baseline == CommandDraftBaseline(), draft.arguments.isEmpty, draft.check().staticallyValid,
              draft.targets.selection != .none, edit.allows(draft.targets.objects) else { throw CommandTrashIssue.invalidArguments }
    }

    func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease) throws -> CommandPlanItem {
        guard run.multiPlan == nil, run.previewLeaseMatches(self.lease, current: lease, itemID: self.item.id),
              run.snapshot.stamp == plan, run.snapshot.items.count == 1, run.permitsMember(self.item.id),
              let item = run.snapshot.items.first(where: { $0.id == self.item.id }), item.stamp == self.item,
              item.draft.stamp == draft, item.draft.targets == targets,
              let command = CommandCatalog.standard.command(id: item.draft.commandID),
              run.resolvedInput(item.id) == .init(arguments: targets.argument(for: command).map { [$0] } ?? [],
                                                  targets: targets) else {
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

/// 独立确认只绑定当时的计划戳与固定目标；摘要来自同一预览，不重新取样。
struct CommandTrashConfirmation: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let acceptanceID: UUID
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let targets: [CommandObjectReference]
    let titles: [String]
    let counts: CommandTrashCounts
    static let sampleLimit = 3
    var description: String { "CommandTrashConfirmation(targets: \(targets.count))" }
    var debugDescription: String { description }

    fileprivate init(_ accepted: CommandTrashAcceptance) {
        id = UUID()
        acceptanceID = accepted.id
        plan = accepted.preview.plan
        item = accepted.preview.item
        targets = accepted.preview.targets.objects
        titles = Array(accepted.preview.impacts.prefix(Self.sampleLimit).map(\.title))
        counts = accepted.preview.counts
    }

    func matches(_ accepted: CommandTrashAcceptance) -> Bool {
        acceptanceID == accepted.id && plan == accepted.preview.plan && item == accepted.preview.item
            && targets == accepted.preview.targets.objects && counts == accepted.preview.counts
    }
}

@MainActor final class CommandTrashRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var acceptances: [UUID: CommandTrashAcceptance] = [:]
    private(set) var confirmations: [UUID: CommandTrashConfirmation] = [:]
    private var invoked: Set<UUID> = []
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }

    /// 新接受总是撤销旧确认；确认不能跨越目标或计划的任何修订。
    func accept(_ preview: CommandTrashPreview) throws -> CommandTrashAcceptance {
        try preview.validateLimit()
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) else { throw CommandTrashIssue.alreadyInvoked }
            if old.preview == preview { return old }
            confirmations[old.id] = nil
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
        let confirmation = CommandTrashConfirmation(accepted)
        confirmations[accepted.id] = confirmation
        return confirmation
    }

    func cancel(_ confirmation: CommandTrashConfirmation) {
        guard confirmations[confirmation.acceptanceID] == confirmation else { return }
        confirmations[confirmation.acceptanceID] = nil
    }

    func confirmation(for accepted: CommandTrashAcceptance) throws -> CommandTrashConfirmation {
        guard let confirmation = confirmations[accepted.id] else { throw CommandTrashIssue.confirmationRequired }
        guard confirmation.matches(accepted) else { throw CommandTrashIssue.confirmationStale }
        return confirmation
    }
}
