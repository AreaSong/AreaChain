import Foundation
import SwiftData

/// 一个操作的集合是接受时的完整类型身份，不保存可再次执行的查询。
enum CommandBatchEdit: Equatable {
    case move(String)
    case tags(CommandArgument)
    case completion(Bool)
    case enabled(Bool)

    static let basicCommands: Set<String> = ["batch.move", "batch.tags"]
    static let stateCommands: Set<String> = ["batch.completion", "batch.enabled"]
    static let commands = basicCommands.union(stateCommands)
    init(command: CommandID, arguments: [CommandArgument]) throws {
        guard arguments.count == 1, let argument = arguments.first else { throw CommandBatchIssue.invalidArguments }
        switch (command.rawValue, argument.parameter, argument.operation, argument.value) {
        case ("batch.move", .day, .assign, .day(let day)) where CommandArgumentValidation.isCanonicalDay(day):
            self = .move(day)
        case ("batch.tags", .tags, let operation, .tags(let ids)) where [.add, .remove].contains(operation) && !ids.isEmpty:
            self = .tags(argument)
        case ("batch.completion", .enabled, .assign, .boolean(let value)): self = .completion(value)
        case ("batch.enabled", .enabled, .assign, .boolean(let value)): self = .enabled(value)
        default: throw CommandBatchIssue.invalidArguments
        }
    }
    var parameter: CommandParameterID {
        switch self {
        case .move: return .day
        case .tags: return .tags
        case .completion, .enabled: return .enabled
        }
    }
    var isState: Bool { Self.stateCommands.contains(command) }
    private var command: String {
        switch self {
        case .move: return "batch.move"
        case .tags: return "batch.tags"
        case .completion: return "batch.completion"
        case .enabled: return "batch.enabled"
        }
    }
    func allows(_ target: CommandObjectReference) -> Bool {
        switch self {
        case .move: return target.type == .todo && target.dayKey == nil
        case .tags: return [.todo, .routine].contains(target.type) && target.dayKey == nil
        case .enabled: return target.type == .routine && target.dayKey == nil
        case .completion:
            return target.type == .todo && target.dayKey == nil
                || target.type == .routineOccurrence && target.dayKey.map(CommandArgumentValidation.isCanonicalDay) == true
        }
    }
}

enum CommandBatchIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, stale, alreadyInvoked, invalidRepository
    case invalidTargets([CommandBatchTargetProblem])
    case catalogChanged, inactiveTag, fieldsChanged(CommandObjectReference)
    case writeConflict, writeLimit(CommandBatchWriteSet.Counts)
}

struct CommandBatchTargetProblem: Equatable {
    enum Reason: Equatable {
        case missing, duplicate, deleted, source, protectedContent, notes, tags, changed, family
        case state(RoutineStateIssue)
    }
    let target: CommandObjectReference
    let reason: Reason
}

struct CommandBatchTargetImpact: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let target: CommandObjectReference
    let record: ObjectIdentifier
    let title: String
    let source: CommandTaskTitleEligibility
    let rawTagIDs: String
    let original: CommandValue
    let final: CommandValue
    let tags: CommandTaskTagMutation?
    var identity: PersistentIdentifier?
    var taskDay: String?
    var completion: CommandTaskCompletionImpact?
    var children: [UUID: PersistentIdentifier] = [:]
    var state: CommandRoutineStateImpact?
    var noChange: Bool { state?.noChange ?? tags.map { $0.noChange(rawIDs: rawTagIDs) } ?? (original == final) }
    var description: String { "CommandBatchTargetImpact(redacted)" }
    var debugDescription: String { description }
}

struct CommandBatchPreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let arguments: [CommandArgument]
    let targets: CommandDraftTargets
    let edit: CommandBatchEdit
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let catalog: CommandTaskTagCatalog.Evidence
    let impacts: [CommandBatchTargetImpact]
    var writeSet: CommandBatchWriteSet?
    let semanticsVersion = 2
    var changedCount: Int { impacts.filter { !$0.noChange }.count }
    var baseline: CommandDraftBaseline {
        .init(Dictionary(uniqueKeysWithValues: impacts.map {
            (.init(subject: .object($0.target), parameter: edit.parameter), .uniform($0.original))
        }))
    }
    var description: String { "CommandBatchPreview(targets: \(targets.objects.count))" }
    var debugDescription: String { description }

    static func input(in host: CommandOwnedHost) throws -> CommandPlanItem {
        let session = host.session
        guard session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1,
              let item = session.plan.items.first, item.draft.hostID == session.hostID else {
            throw CommandBatchIssue.unsupportedPlan
        }
        try validate(item)
        return item
    }

    static func validate(_ item: CommandPlanItem) throws {
        let draft = item.draft
        guard item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.mergedOrigins.isEmpty, item.returnedAttempts.isEmpty,
              CommandBatchEdit.commands.contains(draft.commandID.rawValue) else { throw CommandBatchIssue.unsupportedPlan }
        guard !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
              draft.baseline == CommandDraftBaseline(), draft.check().staticallyValid,
              !draft.targets.objects.isEmpty, draft.targets.selection != .none else { throw CommandBatchIssue.invalidArguments }
        let edit = try CommandBatchEdit(command: draft.commandID, arguments: draft.arguments)
        guard draft.targets.objects.allSatisfy(edit.allows) else { throw CommandBatchIssue.invalidArguments }
    }

    func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease) throws -> CommandPlanItem {
        guard lease.ownership == self.lease.ownership, lease.revision == self.lease.revision + 2,
              run.snapshot.stamp == plan, run.snapshot.items.count == 1, run.outputs.isEmpty,
              let item = run.snapshot.items.first, item.stamp == self.item, item.draft.stamp == draft,
              item.draft.arguments == arguments, item.draft.targets == targets,
              let command = CommandCatalog.standard.command(id: item.draft.commandID),
              let targetArgument = targets.argument(for: command),
              run.resolvedInput(item.id) == .init(arguments: arguments + [targetArgument], targets: targets) else {
            throw CommandBatchIssue.stale
        }
        try Self.validate(item)
        return item
    }
}

struct CommandBatchAcceptance: Equatable {
    let id: UUID
    let preview: CommandBatchPreview
    var checkCreationIDs: [CommandObjectReference: UUID] = [:]
}

@MainActor final class CommandBatchRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var acceptances: [UUID: CommandBatchAcceptance] = [:]
    private var invoked: Set<UUID> = []
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }
    func accept(_ preview: CommandBatchPreview) throws -> CommandBatchAcceptance {
        try preview.writeSet?.validateLimit()
        var identities: [CommandObjectReference: UUID] = [:]
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) else { throw CommandBatchIssue.alreadyInvoked }
            if old.preview == preview { return old }
            identities = old.checkCreationIDs
        }
        let keys = preview.writeSet?.creationTargets ?? []
        let ids = Dictionary(uniqueKeysWithValues: keys.map { ($0, identities[$0] ?? UUID()) })
        let accepted = CommandBatchAcceptance(id: UUID(), preview: preview, checkCreationIDs: ids)
        acceptances[preview.draft.draftID] = accepted
        return accepted
    }
}
