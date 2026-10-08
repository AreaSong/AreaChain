import Foundation

struct CommandRoutineAcceptance: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let preview: CommandRoutinePreview
    let object: CommandObjectReference
    let tagCreationIDs: [String: UUID]
    fileprivate init(_ preview: CommandRoutinePreview) {
        id = UUID()
        self.preview = preview
        object = preview.target
        let keys = Set(preview.tags?.final.compactMap { target -> String? in
            if case .newName(_, let key) = target { return key }; return nil
        } ?? [])
        tagCreationIDs = Dictionary(uniqueKeysWithValues: keys.map { ($0, UUID()) })
    }
    var description: String { "CommandRoutineAcceptance(redacted)" }
    var debugDescription: String { description }
}

/// 习惯定义修改事实没有创建输出；本地提交与系统消费者结果独立登记。
struct CommandRoutineFacts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum State: Equatable { case pending, notSubmitted, noChange, saved, unknown }
    let object: CommandObjectReference
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
    var savedValues: [RoutineField: RoutineFieldValue]?
    var authorizationRequest = CommandTaskTitleFacts.Call.notCalled
    var authorizationResult = CommandTaskTitleFacts.Authorization.unknown
    var description: String { "CommandRoutineFacts(redacted)" }
    var debugDescription: String { description }

    func receipt(in run: CommandExecutionRun, attempt: CommandAttemptStamp) throws -> (Int, CommandExecutionResult?) {
        guard attempt.execution == run.stamp, attempt.phase == .local, run.snapshot.items.count == 1,
              let item = run.snapshot.items.first, item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local else {
            throw CommandExecutionError.stale
        }
        try CommandRoutinePreview.validate(item)
        guard object.type == .routine, object.dayKey == nil, item.draft.targets.objects == [object], run.outputs.isEmpty else {
            throw CommandExecutionError.invalidResult
        }
        guard state == .saved || (savedTagEffects == nil && savedTagIDs == nil && savedTitle == nil && savedValues == nil) else {
            throw CommandExecutionError.invalidResult
        }
        if let previous = run.units[index].routine {
            guard previous.object == object,
                  previous.state == .pending || previous.state == state else { throw CommandExecutionError.invalidResult }
        }
        let result: CommandExecutionResult?
        switch state {
        case .pending: result = nil
        case .noChange:
            guard save == .notCalled, publication == .notCalled,
                  !refreshRequested, authorizationRequest == .notCalled, savedTagEffects == nil, savedTagIDs == nil else {
                throw CommandExecutionError.invalidResult
            }
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

@MainActor final class CommandRoutineRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    private(set) var acceptances: [UUID: CommandRoutineAcceptance] = [:]
    private var invoked: Set<UUID> = []
    func wasInvoked(_ id: UUID) -> Bool { invoked.contains(id) }
    func markInvoked(_ id: UUID) { invoked.insert(id) }
    func accept(_ preview: CommandRoutinePreview) throws -> CommandRoutineAcceptance {
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) else { throw RoutineCommandIssue.alreadyInvoked }
            if old.preview == preview { return old }
        }
        let accepted = CommandRoutineAcceptance(preview)
        acceptances[preview.draft.draftID] = accepted
        return accepted
    }
}
