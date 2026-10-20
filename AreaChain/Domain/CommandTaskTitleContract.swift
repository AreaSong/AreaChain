import Foundation

enum TaskTitleCommandIssue: Error, Equatable {
    case unassembled, ineligibleEnvironment, dirtyContext, nestedTransaction, stale, alreadyInvoked
    case sourceUnavailable, sourceChanged, notesNotSupported, catalogChanged, fieldsChanged(Set<TaskTitleField>)
}

/// 普通证明（revision、protection）来自受控来源所有者；备注证明不再由所有者给出（合并批 M-1 B，L8）：
/// 适配器自己读对象备注，填入 `notes`。证明随资格一起参与相等比较，执行期间备注被改即判定冲突。
struct CommandTaskTitleEligibility: Equatable {
    let revision: UUID
    let protection: CommandProtectionRequirement
    /// 所有者构造时恒为 unproven；只有适配器读库后才改为其他值。
    var notes: CommandNotesProof = .unproven
}

/// 备注“有／无”的证明：只存协调者带键摘要（L6 的随机内存密钥 HMAC），不存明文。
/// unproven：未读或没有密钥，一律不可执行；unreadable：读不到唯一对象，由调用方原有的缺失／重复检查拒绝。
enum CommandNotesProof: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case unproven, unreadable, absent(digest: String), present(digest: String)
    var isAbsent: Bool { if case .absent = self { return true }; return false }
    var isPresent: Bool { if case .present = self { return true }; return false }
    var description: String { "CommandNotesProof(redacted)" }
    var debugDescription: String { description }
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
