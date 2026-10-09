import Foundation
import SwiftData

struct CommandSubtaskAcceptance: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let preview: CommandSubtaskPreview
    let object: CommandObjectReference
    let tagCreationIDs: [String: UUID]
    fileprivate init(_ preview: CommandSubtaskPreview, previous: Self?) {
        id = UUID()
        self.preview = preview
        object = preview.input.target ?? previous?.object ?? .init(type: .subtask, id: UUID())
        let keys = Set(preview.tags?.final.compactMap { target -> String? in
            if case .newName(_, let key) = target { return key }; return nil
        } ?? [])
        tagCreationIDs = Dictionary(uniqueKeysWithValues: keys.map { ($0, previous?.tagCreationIDs[$0] ?? UUID()) })
    }
    var description: String { "CommandSubtaskAcceptance(redacted)" }
    var debugDescription: String { description }
}

/// 子项保留独立事实；只有显式 P-M2 运行才登记类型化依赖输出。
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
    var savedRecord: PersistentIdentifier?
    var savedCompletion: Bool?
    var createdObject: CommandObjectReference? { state == .saved && isCreation ? object : nil }
    var description: String { "CommandSubtaskFacts(redacted)" }
    var debugDescription: String { description }

    func receipt(in run: CommandExecutionRun, attempt: CommandAttemptStamp) throws -> (Int, CommandExecutionResult?) {
        guard attempt.execution == run.stamp, attempt.phase == .local, run.permitsMember(attempt.unitID),
              let item = run.snapshot.items.first(where: { $0.id == attempt.unitID }), item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local else {
            throw CommandExecutionError.stale
        }
        guard run.canRecordLocalFacts(attempt, unit: run.units[index], hasPrevious: run.units[index].subtask != nil) else {
            throw CommandExecutionError.stale
        }
        try CommandSubtaskPreview.validate(item, allowingDependencies: run.multiPlan != nil,
                                         resolved: item.links.results.isEmpty ? nil : run.resolvedInput(item.id))
        let input = try CommandSubtaskInput(item.draft, resolved: run.resolvedInput(item.id))
        guard object.type == .subtask, object.dayKey == nil, isCreation == input.edit.isCreation,
              isCreation ? input.parent?.id == parentID : input.target == object,
              run.outputs[item.id] == nil || (run.outputs[item.id] == createdObject && run.units[index].subtask?.state == .saved) else {
            throw CommandExecutionError.invalidResult
        }
        guard state == .saved || (savedTagEffects == nil && savedTagIDs == nil && savedTitle == nil && savedCompletion == nil) else {
            throw CommandExecutionError.invalidResult
        }
        if let previous = run.units[index].subtask {
            guard previous.object == object, previous.savedRecord == nil || previous.savedRecord == savedRecord,
                  previous.parentID == parentID, previous.isCreation == isCreation,
                  previous.state == .pending || previous.state == state else { throw CommandExecutionError.invalidResult }
        }
        let result: CommandExecutionResult?
        switch state {
        case .pending: result = nil
        case .noChange:
            guard !isCreation, save == .notCalled, rollback == .notCalled, publication == .notCalled,
                  !registrationFailed, !publicationFailed, !conflict,
                  !refreshRequested, savedTagEffects == nil, savedTagIDs == nil else { throw CommandExecutionError.invalidResult }
            result = .noChange
        case .saved:
            guard save == .returned else { throw CommandExecutionError.invalidResult }
            let output = run.multiPlan?.outputCapability == .typedCreation && isCreation ? [item.id: object] : [:]
            result = .committed(outputs: output, external: [.taskPublication, .notification, .calendar])
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
    func accept(_ preview: CommandSubtaskPreview, retry: CommandMultiPlanRetryPermit? = nil) throws -> CommandSubtaskAcceptance {
        if let old = acceptances[preview.draft.draftID] {
            guard !wasInvoked(old.id) || retry?.matches(item: preview.item, acceptance: old.id) == true else { throw SubtaskCommandIssue.alreadyInvoked }
            if old.preview == preview && !wasInvoked(old.id) { return old }
        }
        let accepted = CommandSubtaskAcceptance(preview, previous: acceptances[preview.draft.draftID])
        acceptances[preview.draft.draftID] = accepted
        return accepted
    }
}
