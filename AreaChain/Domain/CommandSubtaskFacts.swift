import Foundation

struct CommandSubtaskAcceptance: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let preview: CommandSubtaskPreview
    let object: CommandObjectReference
    let tagCreationIDs: [String: UUID]
    fileprivate init(_ preview: CommandSubtaskPreview) {
        id = UUID()
        self.preview = preview
        object = preview.input.target ?? .init(type: .subtask, id: UUID())
        let keys = Set(preview.tags?.final.compactMap { target -> String? in
            if case .newName(_, let key) = target { return key }; return nil
        } ?? [])
        tagCreationIDs = Dictionary(uniqueKeysWithValues: keys.map { ($0, UUID()) })
    }
    var description: String { "CommandSubtaskAcceptance(redacted)" }
    var debugDescription: String { description }
}

/// 创建输出只属于这次子任务事实；不进入 todo 创建回执或可依赖的 Run.outputs。
struct CommandSubtaskFacts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum State: Equatable { case pending, notSubmitted, noChange, saved, unknown }
    let object: CommandObjectReference
    let parentID: UUID
    let isCreation: Bool
    var state: State = .pending
    var save = CommandTaskTitleFacts.Call.notCalled
    var rollback = CommandTaskTitleFacts.Call.notCalled
    var publication = CommandTaskTitleFacts.Call.notCalled
    var registrationFailed = false
    var publicationFailed = false
    var conflict = false
    var refreshRequested = false
    var notificationRequested: Bool?
    var calendarRequested: Bool?
    var savedTagEffects: [CommandTaskTagAssociation.Effect]?
    var savedTagIDs: [UUID]?
    var savedTitle: String?
    var savedCompletion: Bool?
    var createdObject: CommandObjectReference? { state == .saved && isCreation ? object : nil }
    var description: String { "CommandSubtaskFacts(redacted)" }
    var debugDescription: String { description }

    func receipt(in run: CommandExecutionRun, attempt: CommandAttemptStamp) throws -> (Int, CommandExecutionResult?) {
        guard attempt.execution == run.stamp, attempt.phase == .local, run.snapshot.items.count == 1,
              let item = run.snapshot.items.first, item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local else {
            throw CommandExecutionError.stale
        }
        try CommandSubtaskPreview.validate(item)
        let input = try CommandSubtaskInput(item.draft)
        guard object.type == .subtask, object.dayKey == nil, isCreation == input.edit.isCreation,
              isCreation ? input.parent?.id == parentID : input.target == object, run.outputs.isEmpty else {
            throw CommandExecutionError.invalidResult
        }
        guard state == .saved || (savedTagEffects == nil && savedTagIDs == nil && savedTitle == nil && savedCompletion == nil) else {
            throw CommandExecutionError.invalidResult
        }
        if let previous = run.units[index].subtask {
            guard previous.object == object, previous.parentID == parentID, previous.isCreation == isCreation,
                  previous.state == .pending || previous.state == state else { throw CommandExecutionError.invalidResult }
        }
        let result: CommandExecutionResult?
        switch state {
        case .pending: result = nil
        case .noChange:
            guard !isCreation, save == .notCalled, publication == .notCalled,
                  !refreshRequested, savedTagEffects == nil, savedTagIDs == nil else { throw CommandExecutionError.invalidResult }
            result = .noChange
        case .saved:
            guard save == .returned else { throw CommandExecutionError.invalidResult }
            result = .committed(outputs: [:], external: [.taskPublication, .notification, .calendar])
        case .unknown: result = .commitUnknown
        case .notSubmitted:
            guard save == .notCalled else { throw CommandExecutionError.invalidResult }
            result = .failedWithoutCommit
        }
        return (index, result)
    }
}

@MainActor final class CommandSubtaskRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var acceptances: [UUID: CommandSubtaskAcceptance] = [:]
    private var invoked: Set<UUID> = []
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }
    func accept(_ preview: CommandSubtaskPreview) throws -> CommandSubtaskAcceptance {
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) else { throw SubtaskCommandIssue.alreadyInvoked }
            if old.preview == preview { return old }
        }
        let accepted = CommandSubtaskAcceptance(preview)
        acceptances[preview.draft.draftID] = accepted
        return accepted
    }
}
