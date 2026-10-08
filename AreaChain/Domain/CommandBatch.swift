import Foundation

/// B-M1 只有一个操作，集合是接受时的完整类型身份，不保存可再次执行的查询。
enum CommandBatchEdit: Equatable {
    case move(String)
    case tags(CommandArgument)

    static let commands: Set<String> = ["batch.move", "batch.tags"]
    init(command: CommandID, arguments: [CommandArgument]) throws {
        guard arguments.count == 1, let argument = arguments.first else { throw CommandBatchIssue.invalidArguments }
        switch (command.rawValue, argument.parameter, argument.operation, argument.value) {
        case ("batch.move", .day, .assign, .day(let day)) where CommandArgumentValidation.isCanonicalDay(day):
            self = .move(day)
        case ("batch.tags", .tags, let operation, .tags(let ids)) where [.add, .remove].contains(operation) && !ids.isEmpty:
            self = .tags(argument)
        default: throw CommandBatchIssue.invalidArguments
        }
    }
    var parameter: CommandParameterID { if case .move = self { return .day }; return .tags }
}

enum CommandBatchIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, stale, alreadyInvoked, invalidRepository
    case invalidTargets([CommandBatchTargetProblem])
    case catalogChanged, inactiveTag, fieldsChanged(CommandObjectReference)
}

struct CommandBatchTargetProblem: Equatable {
    enum Reason: Equatable { case missing, duplicate, deleted, source, protectedContent, notes, tags, changed }
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
    var noChange: Bool { tags.map { $0.noChange(rawIDs: rawTagIDs) } ?? (original == final) }
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
    let semanticsVersion = 1
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
              !draft.targets.objects.isEmpty, draft.targets.selection != .none,
              draft.targets.objects.allSatisfy({ $0.dayKey == nil }) else { throw CommandBatchIssue.invalidArguments }
        _ = try CommandBatchEdit(command: draft.commandID, arguments: draft.arguments)
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
}

@MainActor final class CommandBatchRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var acceptances: [UUID: CommandBatchAcceptance] = [:]
    private var invoked: Set<UUID> = []
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }
    func accept(_ preview: CommandBatchPreview) throws -> CommandBatchAcceptance {
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) else { throw CommandBatchIssue.alreadyInvoked }
            if old.preview == preview { return old }
        }
        let accepted = CommandBatchAcceptance(id: UUID(), preview: preview)
        acceptances[preview.draft.draftID] = accepted
        return accepted
    }
}
