import Foundation

enum SubtaskCommandIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, stale, alreadyInvoked, fieldsChanged
    case invalidFamily, identityCollision, sourceUnavailable, protectedContent
}

enum CommandSubtaskEdit: Equatable {
    case create(SubtaskTitleEdit), title(SubtaskTitleEdit), completion(Bool), tags(CommandArgument)
    static let commands: Set<String> = ["subtask.create", "subtask.title", "subtask.completion", "subtask.tags"]
    var isCreation: Bool { if case .create = self { return true }; return false }
}

/// 父参数与修改目标有不同角色；不能从父参数构造子任务身份。
struct CommandSubtaskInput: Equatable {
    let edit: CommandSubtaskEdit
    let parent: CommandObjectReference?
    let target: CommandObjectReference?

    init(_ draft: CommandDraft) throws {
        guard CommandSubtaskEdit.commands.contains(draft.commandID.rawValue),
              !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
              draft.baseline == CommandDraftBaseline(), draft.check().staticallyValid else {
            throw SubtaskCommandIssue.invalidArguments
        }
        let arguments = draft.arguments
        if draft.commandID.rawValue == "subtask.create" {
            guard draft.targets == .none, (2...3).contains(arguments.count),
                  Set(arguments.map(\.parameter)).isSubset(of: [.parent, .title, .tags]),
                  case .object(let parent) = arguments.first(where: { $0.parameter == .parent })?.value,
                  parent.type == .todo, parent.dayKey == nil else { throw SubtaskCommandIssue.invalidArguments }
            self.parent = parent
            target = nil
            edit = .create(try Self.title(arguments))
        } else {
            guard arguments.count == 1, draft.targets.selection == .single, draft.targets.objects.count == 1,
                  let target = draft.targets.objects.first, target.type == .subtask, target.dayKey == nil else {
                throw SubtaskCommandIssue.invalidArguments
            }
            self.target = target
            parent = nil
            switch (draft.commandID.rawValue, arguments[0].parameter, arguments[0].operation, arguments[0].value) {
            case ("subtask.title", .title, .assign, .shortText): edit = .title(try Self.title(arguments))
            case ("subtask.completion", .enabled, .assign, .boolean(let done)): edit = .completion(done)
            case ("subtask.tags", .tags, .clear, nil): edit = .tags(arguments[0])
            case ("subtask.tags", .tags, let mode, .tags) where [.add, .remove, .replaceAll].contains(mode):
                edit = .tags(arguments[0])
            default: throw SubtaskCommandIssue.invalidArguments
            }
        }
    }

    private static func title(_ arguments: [CommandArgument]) throws -> SubtaskTitleEdit {
        guard let argument = arguments.first(where: { $0.parameter == .title }), argument.operation == .assign,
              case .shortText(let raw) = argument.value, !raw.contains(where: \.isNewline),
              let edit = SubtaskTitleEdit(raw) else { throw SubtaskCommandIssue.invalidArguments }
        return edit
    }
}

struct CommandSubtaskSourceRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let command: CommandID
    let parent: CommandObjectReference
    let target: CommandObjectReference?
    let arguments: [CommandArgument]
    var description: String { "CommandSubtaskSourceRequest(redacted)" }
    var debugDescription: String { description }
}

/// 装配者必须分别证明父项、子项和本次输入；父许可不提升另两者的资格。
struct CommandSubtaskEligibility: Equatable {
    struct Proof: Equatable {
        let revision: UUID
        let protection: CommandProtectionRequirement
    }
    let parent: CommandTaskTitleEligibility
    let subtask: Proof?
    let input: Proof
}

struct CommandSubtaskSource: Equatable {
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let eligibility: CommandSubtaskEligibility
}

struct CommandSubtaskParent: Equatable {
    let id: UUID
    let record: ObjectIdentifier
    let title: String
    let sourceBundleID: String
    let tagIDs: String
}

struct CommandSubtaskOriginal: Equatable {
    let id: UUID
    let record: ObjectIdentifier
    let parentID: UUID
    let title: String
    let isDone: Bool
    let sortOrder: Int
    let createdAt: Date
    let tagIDs: String
}

/// 新增只绑定排序实际依赖的兄弟身份/墓碑/顺序，不导出兄弟正文。
struct CommandSubtaskSibling: Equatable {
    let id: UUID
    let record: ObjectIdentifier
    let sortOrder: Int
    let deletedAt: Date?
}

struct CommandSubtaskPreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let arguments: [CommandArgument]
    let input: CommandSubtaskInput
    let parent: CommandSubtaskParent
    let original: CommandSubtaskOriginal?
    let siblings: [CommandSubtaskSibling]?
    let source: CommandSubtaskSource
    let catalog: CommandTaskTagCatalog.Evidence
    let tags: CommandTaskTagMutation?
    var semanticsVersion = 1

    var noChange: Bool {
        guard let original else { return false }
        switch input.edit {
        case .create: return false
        case .title(let edit): return original.title == edit.title && tags?.noChange(rawIDs: original.tagIDs) == true
        case .completion(let done): return original.isDone == done
        case .tags: return tags?.noChange(rawIDs: original.tagIDs) == true
        }
    }

    static func item(in host: CommandOwnedHost) throws -> CommandPlanItem {
        let session = host.session
        guard session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1,
              let item = session.plan.items.first, item.draft.hostID == session.hostID else {
            throw SubtaskCommandIssue.unsupportedPlan
        }
        try validate(item)
        return item
    }

    static func validate(_ item: CommandPlanItem) throws {
        guard item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.mergedOrigins.isEmpty, item.returnedAttempts.isEmpty else { throw SubtaskCommandIssue.unsupportedPlan }
        _ = try CommandSubtaskInput(item.draft)
    }

    func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease) throws -> CommandPlanItem {
        guard lease.ownership == self.lease.ownership, lease.revision == self.lease.revision + 2,
              run.snapshot.stamp == plan, run.snapshot.items.count == 1, run.outputs.isEmpty,
              let item = run.snapshot.items.first, item.stamp == self.item, item.draft.stamp == draft,
              item.draft.arguments == arguments, try CommandSubtaskInput(item.draft) == input,
              let command = CommandCatalog.standard.command(id: item.draft.commandID) else { throw SubtaskCommandIssue.stale }
        let projected = item.draft.targets.argument(for: command).map { [$0] } ?? []
        guard run.resolvedInput(item.id) == .init(arguments: arguments + projected, targets: item.draft.targets) else {
            throw SubtaskCommandIssue.stale
        }
        try Self.validate(item)
        return item
    }
    var description: String { "CommandSubtaskPreview(redacted)" }
    var debugDescription: String { description }
}
