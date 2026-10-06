import Foundation

enum TaskCreateCommandIssue: Error, Equatable {
    case unassembled, invalidInput, unsupportedPlan, protectedContent, sourceChanged, sourceUnavailable, storageUnavailable
    case dirtyContext, nestedTransaction, ineligibleEnvironment, identityCollision, stale, alreadyInvoked
}

/// 来源由隔离装配实际采样；ordinary 不是根据标题关键词推断的。
struct CommandTaskCreateSource: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let protection: CommandProtectionRequirement
    let stampEnabled: Bool
    let bundleID: String
    var description: String { "CommandTaskCreateSource(redacted)" }
    var debugDescription: String { description }
}

struct CommandTaskCreateInput: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let arguments: [CommandArgument]
    let parsed: ParsedCapture
    let day: String

    init(_ draft: CommandDraft) throws {
        guard !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary else {
            throw TaskCreateCommandIssue.protectedContent
        }
        guard draft.commandID.rawValue == "todo.create", draft.targets == .none,
              draft.baseline == CommandDraftBaseline(), draft.arguments.count == 2,
              let command = CommandCatalog.standard.command(id: draft.commandID),
              command.createdObjectType == .todo,
              CommandArgumentValidation.issues(for: draft.arguments, command: command).isEmpty,
              Set(draft.arguments.map(\.parameter)) == [.title, .day],
              case .shortText(let title) = draft.arguments.first(where: { $0.parameter == .title })?.value,
              case .day(let day) = draft.arguments.first(where: { $0.parameter == .day })?.value else {
            throw TaskCreateCommandIssue.invalidInput
        }
        let raw = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = NaturalLanguageParser.parseTaskCapture(raw)
        guard !NaturalLanguageParser.hasTaskNoteSeparator(raw), !title.contains(where: \.isNewline),
              parsed.notes.isEmpty, parsed.tagNames.isEmpty, parsed.tagName == nil,
              parsed.remindMinutes == nil, !parsed.hasPriorityToken,
              !parsed.isImportant, !parsed.isUrgent, parsed.hasContentTitle,
              !parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskCreateCommandIssue.invalidInput
        }
        arguments = draft.arguments
        self.parsed = parsed
        self.day = day
    }

    var description: String { "CommandTaskCreateInput(redacted)" }
    var debugDescription: String { description }
}

/// 只由协调者签发；UI 不能指定候选 UUID 或把任意 UUID 声明为已保留。
struct CommandTaskCreatePreparation: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let creationID: UUID
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let source: CommandTaskCreateSource
    let input: CommandTaskCreateInput

    fileprivate init(item: CommandPlanItem, plan: CommandPlanStamp, lease: CommandHostLease,
                     evidence: CommandTaskCreateEvidence) {
        id = UUID()
        creationID = UUID()
        self.lease = lease
        self.plan = plan
        self.item = item.stamp
        draft = item.draft.stamp
        environmentID = evidence.environmentID
        contextID = evidence.contextID
        storageID = evidence.storageID
        source = evidence.source
        input = evidence.input
    }

    var description: String { "CommandTaskCreatePreparation(redacted)" }
    var debugDescription: String { description }
}

struct CommandTaskCreateEvidence {
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let source: CommandTaskCreateSource
    let input: CommandTaskCreateInput
}

/// 仅记录运行内调用事实，不是 SwiftData 耐久账本，也不携带任务正文。
struct CommandTaskCreateFacts: Equatable {
    enum State: Equatable { case pending, notSubmitted, saved, unknown }
    enum Call: Equatable { case notCalled, called, returned }
    let creationID: UUID
    var candidateID: UUID?
    var savedID: UUID?
    var state: State = .pending
    var save: Call = .notCalled
    var rollback: Call = .notCalled
    var publication: Call = .notCalled
    var publicationFailed = false
    var registrationFailed = false
    var refreshRequested = false
    var notificationRequested: Bool?
    var calendarRequested: Bool?
}

struct TaskCreateCommandRequest {
    let lease: CommandHostLease
    let operation: CommandOperationIdentity
    let attempt: CommandAttemptStamp
}

/// 精确 ID 的当前存在性不等于历史提交证明，所有分支均禁止重新创建。
enum CommandTaskCreateVerification: Equatable {
    case absent, singleLive, tombstone, ambiguous, unreadable
}

@MainActor final class CommandTaskCreateRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var preparations: [UUID: CommandTaskCreatePreparation] = [:]
    private var invoked: Set<UUID> = []

    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }

    func reserve(item: CommandPlanItem, plan: CommandPlanStamp, lease: CommandHostLease,
                 evidence: CommandTaskCreateEvidence) throws -> CommandTaskCreatePreparation {
        if let old = preparations[item.draft.id] {
            guard old.lease == lease, old.plan == plan, old.item == item.stamp, old.draft == item.draft.stamp,
                  old.environmentID == evidence.environmentID, old.contextID == evidence.contextID,
                  old.storageID == evidence.storageID, old.source == evidence.source,
                  old.input == evidence.input else { throw TaskCreateCommandIssue.stale }
            return old
        }
        let prepared = CommandTaskCreatePreparation(item: item, plan: plan, lease: lease, evidence: evidence)
        preparations[item.draft.id] = prepared
        return prepared
    }
}
