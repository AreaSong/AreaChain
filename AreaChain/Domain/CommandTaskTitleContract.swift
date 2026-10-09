import Foundation

enum TaskTitleCommandIssue: Error, Equatable {
    case unassembled, ineligibleEnvironment, dirtyContext, nestedTransaction, stale, alreadyInvoked
    case sourceUnavailable, sourceChanged, notesNotSupported, catalogChanged, fieldsChanged(Set<TaskTitleField>)
}

/// 普通/无备注证明来自受控来源所有者；不能由标题关键词或未读取 notes 推导。
struct CommandTaskTitleEligibility: Equatable {
    enum Notes: Equatable { case absent, present, unknown }
    let revision: UUID
    let protection: CommandProtectionRequirement
    let notes: Notes
}

struct CommandTaskTitleAcceptance: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let preview: CommandTaskTitlePreview
    let tagCreationIDs: [String: UUID]
    fileprivate init(_ preview: CommandTaskTitlePreview, previous: Self?) {
        id = UUID()
        self.preview = preview
        tagCreationIDs = Dictionary(uniqueKeysWithValues: preview.impact.tags.syntax.final.compactMap {
            guard case .newName(_, let key) = $0.target else { return nil }
            return (key, previous?.tagCreationIDs[key] ?? UUID())
        })
    }
    var description: String { "CommandTaskTitleAcceptance(redacted)" }
    var debugDescription: String { description }
}

struct TaskTitleCommandRequest {
    let lease: CommandHostLease
    let operation: CommandOperationIdentity
    let attempt: CommandAttemptStamp
}

/// 修改事实没有 candidateID / savedID 或创建输出；外部请求与已知处理结果分别保存。
struct CommandTaskTitleFacts: Equatable {
    enum State: Equatable { case pending, notSubmitted, noChange, saved, unknown }
    enum Call: Equatable { case notCalled, called, returned }
    enum Authorization: Equatable { case unknown, granted, denied }
    let targetID: UUID
    var state: State = .pending
    var save: Call = .notCalled
    var rollback: Call = .notCalled
    var publication: Call = .notCalled
    var registrationFailed = false
    var publicationFailed = false
    var conflict: TaskTitleCommandIssue?
    var savedTagEffects: [CommandTaskTagAssociation.Effect]?
    var followUpContext: CommandTaskTitleContext?
    var authorizationRequest: Call = .notCalled
    var authorizationResult: Authorization = .unknown
    var refreshRequested = false
    var notificationRequested: Bool?
    var calendarRequested: Bool?
}

/// 精确目标的当前值只供核验，不证明原调用已经成功，也不生成重放许可。
struct CommandTaskTitleVerification: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum Presence: Equatable { case absent, live, deleted, ambiguous, unreadable }
    let operation: CommandOperationIdentity
    let attempt: CommandAttemptStamp
    let originalFacts: CommandTaskTitleFacts
    let presence: Presence
    let currentValues: [TaskTitleField: TaskTitleFieldValue]
    var description: String { "CommandTaskTitleVerification(redacted)" }
    var debugDescription: String { description }
}

@MainActor final class CommandTaskTitleRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var acceptances: [UUID: CommandTaskTitleAcceptance] = [:]
    private var invoked: Set<UUID> = []
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }

    func accept(_ preview: CommandTaskTitlePreview, retry: CommandMultiPlanRetryPermit? = nil) throws -> CommandTaskTitleAcceptance {
        if let old = acceptances[preview.binding.draft.draftID] {
            guard !wasInvoked(old.id) || retry?.matches(item: preview.binding.item, acceptance: old.id) == true else { throw TaskTitleCommandIssue.alreadyInvoked }
            if old.preview == preview && !wasInvoked(old.id) { return old }
        }
        let accepted = CommandTaskTitleAcceptance(preview, previous: acceptances[preview.binding.draft.draftID])
        acceptances[preview.binding.draft.draftID] = accepted
        return accepted
    }
}
