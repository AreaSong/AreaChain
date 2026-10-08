import Foundation

enum RoutineCommandIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, stale, alreadyInvoked, fieldsChanged
    case sourceUnavailable, protectedContent, invalidRepository
}

/// 定义字段与显式状态操作共用原接受协议；状态能力仍须单独装配。
enum CommandRoutineEdit: Equatable {
    case title(TaskTitleEdit), weekdays(Int), reminder(Int?), priority(important: Bool, urgent: Bool), tags(CommandArgument)
    case enabled(Bool), occurrence(RoutineOccurrenceAction)
    static let stateCommands: Set<String> = ["routine.enabled", "occurrence.complete", "occurrence.skip", "occurrence.reopen"]
    static var allCommands: Set<String> { commands.union(stateCommands) }
    var isState: Bool { if case .enabled = self { return true }; if case .occurrence = self { return true }; return false }

    init(command: CommandID, arguments: [CommandArgument]) throws {
        if let action = RoutineOccurrenceAction(rawValue: command.rawValue.replacingOccurrences(of: "occurrence.", with: "")),
           command.rawValue.hasPrefix("occurrence."), arguments.isEmpty { self = .occurrence(action); return }
        guard arguments.count == 1 else { throw RoutineCommandIssue.invalidArguments }
        try self.init(command: command, argument: arguments[0])
    }

    static let commands: Set<String> = ["routine.title", "routine.weekdays", "routine.reminder", "routine.priority", "routine.tags"]

    init(command: CommandID, argument: CommandArgument) throws {
        switch (command.rawValue, argument.parameter, argument.operation, argument.value) {
        case ("routine.enabled", .enabled, .assign, .boolean(let value)): self = .enabled(value)
        case ("routine.title", .title, .assign, .shortText(let raw)):
            guard !raw.contains(where: \.isNewline), !NaturalLanguageParser.hasTaskNoteSeparator(raw),
                  let edit = TaskTitleEdit(raw), edit.notes == nil else { throw TaskTitleCommandIssue.notesNotSupported }
            guard !edit.title.isEmpty else { throw RoutineCommandIssue.invalidArguments }
            self = .title(edit)
        case ("routine.weekdays", .weekdays, .assign, .weekdays(let mask))
            where mask > 0 && mask & ~WeekdayMask.all == 0: self = .weekdays(mask)
        case ("routine.reminder", .time, .setReminder, .time(let minutes)) where (0..<1440).contains(minutes):
            self = .reminder(minutes)
        case ("routine.reminder", .time, .cancelReminder, nil): self = .reminder(nil)
        case ("routine.priority", .priority, .assign, .choice(let value)):
            guard ["p1", "p2", "p3", "p4"].contains(value), let flags = PriorityToken.flags(in: "!" + value) else {
                throw RoutineCommandIssue.invalidArguments
            }
            self = .priority(important: flags.isImportant, urgent: flags.isUrgent)
        case ("routine.priority", .priority, .clear, nil): self = .priority(important: false, urgent: false)
        case ("routine.tags", .tags, .clear, nil): self = .tags(argument)
        case ("routine.tags", .tags, let operation, .tags) where [.add, .remove, .replaceAll].contains(operation):
            self = .tags(argument)
        default: throw RoutineCommandIssue.invalidArguments
        }
    }
}

struct CommandRoutineSourceRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let command: CommandID
    let target: CommandObjectReference
    let arguments: [CommandArgument]
    var description: String { "CommandRoutineSourceRequest(redacted)" }
    var debugDescription: String { description }
}

struct CommandRoutineEligibility: Equatable {
    let target: CommandTaskTitleEligibility
    let input: CommandSubtaskEligibility.Proof
}

struct CommandRoutineSource: Equatable {
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let eligibility: CommandRoutineEligibility
}

enum RoutineField: Hashable { case title, weekdayMask, weekdaysOnly, remindMinutes, isImportant, isUrgent, tagIDs }
enum RoutineFieldValue: Equatable { case text(String), flag(Bool), number(Int?) }

/// 原始存储星期与兼容标记分别绑定；有效安排相同仍可能需要真实写入。
struct CommandRoutinePreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let arguments: [CommandArgument]
    let target: CommandObjectReference
    let record: ObjectIdentifier
    let targetTitle: String
    let isEnabled: Bool
    let original: [RoutineField: RoutineFieldValue]
    let final: [RoutineField: RoutineFieldValue]
    let edit: CommandRoutineEdit
    let source: CommandRoutineSource
    let catalog: CommandTaskTagCatalog.Evidence
    let tagIDs: String
    let tags: CommandTaskTagMutation?
    var stateImpact: CommandRoutineStateImpact?
    var semanticsVersion = 1
    var noChange: Bool { original == final && (tags?.noChange(rawIDs: tagIDs) ?? true) && (stateImpact?.noChange ?? true) }
    var description: String { "CommandRoutinePreview(redacted)" }
    var debugDescription: String { description }

    static func input(in host: CommandOwnedHost) throws -> CommandPlanItem {
        let session = host.session
        guard session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1,
              let item = session.plan.items.first, item.draft.hostID == session.hostID else {
            throw RoutineCommandIssue.unsupportedPlan
        }
        try validate(item)
        return item
    }

    static func validate(_ item: CommandPlanItem) throws {
        let draft = item.draft
        guard item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.mergedOrigins.isEmpty, item.returnedAttempts.isEmpty,
              CommandRoutineEdit.allCommands.contains(draft.commandID.rawValue) else { throw RoutineCommandIssue.unsupportedPlan }
        guard !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
              draft.baseline == CommandDraftBaseline(), draft.check().staticallyValid,
              draft.targets.selection == .single, draft.targets.objects.count == 1,
              let target = draft.targets.objects.first else {
            throw RoutineCommandIssue.invalidArguments
        }
        let edit = try CommandRoutineEdit(command: draft.commandID, arguments: draft.arguments)
        if case .occurrence = edit {
            guard target.type == .routineOccurrence, target.dayKey.map(CommandArgumentValidation.isCanonicalDay) == true else {
                throw RoutineCommandIssue.invalidArguments
            }
        } else if target.type != .routine || target.dayKey != nil { throw RoutineCommandIssue.invalidArguments }
    }

    func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease) throws -> CommandPlanItem {
        guard lease.ownership == self.lease.ownership, lease.revision == self.lease.revision + 2,
              run.snapshot.stamp == plan, run.snapshot.items.count == 1, run.outputs.isEmpty,
              let item = run.snapshot.items.first, item.stamp == self.item, item.draft.stamp == draft,
              item.draft.arguments == arguments, item.draft.targets == .init(.single, objects: [target]),
              let command = CommandCatalog.standard.command(id: item.draft.commandID),
              let targetArgument = item.draft.targets.argument(for: command),
              run.resolvedInput(item.id) == .init(arguments: arguments + [targetArgument], targets: item.draft.targets) else {
            throw RoutineCommandIssue.stale
        }
        try Self.validate(item)
        return item
    }
}

struct RoutineCommandRequest {
    let lease: CommandHostLease
    let operation: CommandOperationIdentity
    let attempt: CommandAttemptStamp
}
