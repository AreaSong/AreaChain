import Foundation
import SwiftData

enum TaskCopyCommandIssue: Error, Equatable {
    case unassembled, unsupportedPlan, invalidArguments, invalidTarget
    case missing, duplicate, deleted, protectedContent, sourceUnavailable, notesUnverified
    case notesEmpty, changed, stale, writeFailed
}

/// 复制只冻结当时核验过的内容；不进 Plan/Run、不修改数据、不进撤销，也不需要独立确认。
struct CommandTaskCopyPreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    static let command = "todo.copy"
    let lease: CommandHostLease
    let draft: CommandDraftStamp
    let target: CommandObjectReference
    let section: TaskCopySection
    let environmentID: UUID
    let record: PersistentIdentifier
    let snapshot: TodoSnapshot
    let source: CommandTaskTitleEligibility
    let text: String
    var description: String { "CommandTaskCopyPreview(redacted)" }
    var debugDescription: String { description }

    /// 只接受当前操作草稿：目录把复制标为外部效果，不能入列或与其他计划项组合。
    static func input(in host: CommandOwnedHost) throws -> CommandDraft {
        let session = host.session
        guard session.execution == nil, session.operations.pending == nil, session.plan.items.isEmpty,
              session.plan.editing == nil, let draft = session.operations.active,
              draft.hostID == session.hostID, draft.commandID.rawValue == command else {
            throw TaskCopyCommandIssue.unsupportedPlan
        }
        _ = try parse(draft)
        return draft
    }

    static func parse(_ draft: CommandDraft) throws -> (CommandObjectReference, TaskCopySection) {
        guard !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary,
              draft.baseline == CommandDraftBaseline(), draft.check().staticallyValid else {
            throw TaskCopyCommandIssue.invalidArguments
        }
        guard draft.targets.objects.count == 1, let target = draft.targets.objects.first,
              target.type == .todo, target.dayKey == nil else { throw TaskCopyCommandIssue.invalidTarget }
        let extra = draft.arguments.filter { $0.parameter != .section }
        let sections = draft.arguments.filter { $0.parameter == .section }
        guard extra.isEmpty, sections.count <= 1 else { throw TaskCopyCommandIssue.invalidArguments }
        guard let argument = sections.first else { return (target, .record) }
        guard argument.operation == .assign, case .choice(let raw) = argument.value,
              let section = TaskCopySection(rawValue: raw) else { throw TaskCopyCommandIssue.invalidArguments }
        return (target, section)
    }
}

struct CommandTaskCopyResult: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let draft: CommandDraftStamp
    let target: CommandObjectReference
    let section: TaskCopySection
    let characters: Int
    var description: String { "CommandTaskCopyResult(redacted)" }
    var debugDescription: String { description }
}
