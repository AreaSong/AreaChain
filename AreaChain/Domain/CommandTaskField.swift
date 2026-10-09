import Foundation
import SwiftData

/// 普通单目标属性的窄修改值；可空时间仅表示明确清空，缺少操作不能构造此值。
enum TaskFieldEdit: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case move(String)
    case priority(important: Bool, urgent: Bool)
    case reminder(Int?)
    case due(Int?)
    case completion(Bool)
    case tags(CommandArgument)
    case createTag(String)

    static let basicCommands: Set<String> = ["todo.move", "todo.priority", "todo.reminder"]
    static let milestone2Commands: Set<String> = ["todo.completion", "todo.tags", "todo.createTag", "todo.due"]
    static let commands = basicCommands.union(milestone2Commands)

    init(command: CommandID, argument: CommandArgument) throws {
        switch (command.rawValue, argument.parameter, argument.operation, argument.value) {
        case ("todo.move", .day, .assign, .day(let day)) where DayKey.date(from: day) != nil:
            self = .move(day)
        case ("todo.priority", .priority, .assign, .choice(let value)):
            guard ["p1", "p2", "p3", "p4"].contains(value),
                  let flags = PriorityToken.flags(in: "!" + value) else { throw TaskFieldCommandIssue.invalidArguments }
            self = .priority(important: flags.isImportant, urgent: flags.isUrgent)
        case ("todo.priority", .priority, .clear, nil): self = .priority(important: false, urgent: false)
        case ("todo.reminder", .time, .setReminder, .time(let minutes)) where (0..<1440).contains(minutes):
            self = .reminder(minutes)
        case ("todo.reminder", .time, .cancelReminder, nil): self = .reminder(nil)
        case ("todo.due", .time, .assign, .time(let minutes)) where (0..<1440).contains(minutes): self = .due(minutes)
        case ("todo.due", .time, .clear, nil): self = .due(nil)
        case ("todo.completion", .enabled, .assign, .boolean(let done)): self = .completion(done)
        case ("todo.tags", .tags, .clear, nil): self = .tags(argument)
        case ("todo.tags", .tags, let operation, .tags) where [.add, .remove, .replaceAll].contains(operation):
            self = .tags(argument)
        case ("todo.createTag", .name, .assign, .shortText(let name)):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !name.contains(where: { $0.isNewline }) else { throw TaskFieldCommandIssue.invalidArguments }
            self = .createTag(trimmed)
        default: throw TaskFieldCommandIssue.invalidArguments
        }
    }

    var value: CommandValue? {
        switch self {
        case .move(let day): return .day(day)
        case .priority(let important, let urgent): return .choice(important ? (urgent ? "p1" : "p2") : (urgent ? "p3" : "p4"))
        case .reminder(let minutes), .due(let minutes): return minutes.map(CommandValue.time)
        case .completion(let done): return .boolean(done)
        case .tags(let argument): return argument.value
        case .createTag(let name): return .shortText(name)
        }
    }
    var commandID: CommandID {
        let name: String
        switch self {
        case .move: name = "move"
        case .priority: name = "priority"
        case .reminder: name = "reminder"
        case .due: name = "due"
        case .completion: name = "completion"
        case .tags: name = "tags"
        case .createTag: name = "createTag"
        }
        return .init(rawValue: "todo." + name)
    }
    var description: String { "TaskFieldEdit(redacted)" }
    var debugDescription: String { description }
}

enum TaskFieldCommandIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, stale, alreadyInvoked, fieldsChanged
}

struct CommandTaskFieldPreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let arguments: [CommandArgument]
    let target: CommandObjectReference
    let original: TaskFieldEdit
    let edit: TaskFieldEdit
    let source: CommandTaskTitleSource
    let catalog: CommandTaskTagCatalog.Evidence
    let tagIDs: String
    var completion: CommandTaskCompletionImpact?
    var tags: CommandTaskTagMutation?
    var targetTitle = ""
    var consumption: CommandCreationConsumption?
    var record: PersistentIdentifier?
    var semanticsVersion = 2
    var noChange: Bool { tags.map { $0.noChange(rawIDs: tagIDs) } ?? (original == edit) }

    static func input(in host: CommandOwnedHost) throws -> CommandPlanItem {
        let session = host.session
        guard session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1,
              let item = session.plan.items.first, item.draft.hostID == session.hostID else {
            throw TaskFieldCommandIssue.unsupportedPlan
        }
        try validate(item)
        return item
    }

    static func validate(_ item: CommandPlanItem, allowingDependencies: Bool = false,
                         resolved: CommandResolvedInput? = nil) throws {
        let input = try item.checkedInput(resolved)
        let draft = item.draft
        guard item.atomicGroup == nil, allowingDependencies || item.links.predecessors.isEmpty, resolved != nil || item.links.results.isEmpty,
              item.hasSupportedOrigins, allowingDependencies || item.executionOrigin == nil,
              TaskFieldEdit.commands.contains(draft.commandID.rawValue) else { throw TaskFieldCommandIssue.unsupportedPlan }
        guard !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
              draft.baseline == CommandDraftBaseline(),
              draft.arguments.count == 1, input.targets.selection == .single, input.targets.objects.count == 1,
              let target = input.targets.objects.first, target.type == .todo, target.dayKey == nil else {
            throw TaskFieldCommandIssue.invalidArguments
        }
        _ = try TaskFieldEdit(command: draft.commandID, argument: draft.arguments[0])
    }

    func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease) throws -> CommandPlanItem {
        guard run.previewLeaseMatches(self.lease, current: lease, itemID: self.item.id),
              run.snapshot.stamp == plan, run.permitsMember(self.item.id),
              let item = run.snapshot.items.first(where: { $0.stamp == self.item }), item.draft.stamp == draft,
              item.draft.arguments == arguments else { throw TaskFieldCommandIssue.stale }
        if let consumption { try consumption.validate(in: run, item: item) }
        let resolved = try consumption?.input(item) ?? item.checkedInput()
        guard run.resolvedInput(item.id) == resolved else { throw TaskFieldCommandIssue.stale }
        guard resolved.targets == .init(.single, objects: [target]) else { throw TaskFieldCommandIssue.stale }
        try Self.validate(item, allowingDependencies: run.multiPlan != nil, resolved: resolved)
        return item
    }

    var description: String { "CommandTaskFieldPreview(redacted)" }
    var debugDescription: String { description }
}

struct CommandTaskFieldAcceptance: Equatable {
    let id: UUID
    let preview: CommandTaskFieldPreview
    var tagCreationIDs: [String: UUID] = [:]
}

struct CommandTaskFieldFacts: Equatable {
    enum State: Equatable { case pending, notSubmitted, noChange, saved, unknown }
    let targetID: UUID
    var state: State = .pending
    var save = CommandTaskTitleFacts.Call.notCalled
    var rollback = CommandTaskTitleFacts.Call.notCalled
    var publication = CommandTaskTitleFacts.Call.notCalled
    var registrationFailed = false
    var publicationFailed = false
    var conflict = false
    var authorizationRequest = CommandTaskTitleFacts.Call.notCalled
    var authorizationResult = CommandTaskTitleFacts.Authorization.unknown
    var refreshRequested = false
    var notificationRequested: Bool?
    var calendarRequested: Bool?
    var savedTagEffects: [CommandTaskTagAssociation.Effect]?
    var savedTagIDs: [UUID]?
    var completedSubtaskIDs: [UUID]?
}

@MainActor final class CommandTaskFieldRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var acceptances: [UUID: CommandTaskFieldAcceptance] = [:]
    private var invoked: Set<UUID> = []
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }

    func accept(_ preview: CommandTaskFieldPreview, retry: CommandMultiPlanRetryPermit? = nil) throws -> CommandTaskFieldAcceptance {
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) || retry?.matches(item: preview.item, acceptance: old.id) == true else { throw TaskFieldCommandIssue.alreadyInvoked }
            if old.preview == preview && !wasInvoked(old.id) { return old }
        }
        let keys = preview.tags?.final.compactMap { target -> String? in
            if case .newName(_, let key) = target { return key }; return nil
        } ?? []
        let previous = acceptances[preview.draft.draftID]?.tagCreationIDs ?? [:]
        let ids = Dictionary(uniqueKeysWithValues: keys.map { ($0, previous[$0] ?? UUID()) })
        let result = CommandTaskFieldAcceptance(id: UUID(), preview: preview, tagCreationIDs: ids)
        acceptances[preview.draft.draftID] = result
        return result
    }
}
