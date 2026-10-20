import Foundation
import SwiftData

/// 仅显式隔离装配；子项/输入证明没有从父证明推导的默认闭包。
@MainActor final class SubtaskCommandEnvironment {
    let id = UUID()
    let context: ModelContext
    let center: NotificationCenter
    let dependencies: TaskMutationService.SubtaskDependencies
    let source: (CommandSubtaskSourceRequest) throws -> CommandSubtaskEligibility
    let refresh: (CommandTaskTitleContext, Bool) throws -> TaskTitleCommandEnvironment.Refresh
    var beforePublication: () throws -> Void = {}
    var afterPublication: () throws -> Void = {}
    lazy var reader = SubtaskCommandReader(environment: self)
    /// 协调者的带键摘要（L6）；由装配它的适配器设置，用于自读备注的无备注证明（L8）。未设置即无证明、不可执行。
    var notesKey: CommandTextDigest?

    init(context: ModelContext, center: NotificationCenter, dependencies: TaskMutationService.SubtaskDependencies,
         source: @escaping (CommandSubtaskSourceRequest) throws -> CommandSubtaskEligibility,
         refresh: @escaping (CommandTaskTitleContext, Bool) throws -> TaskTitleCommandEnvironment.Refresh) throws {
        self.context = context
        self.center = center
        self.dependencies = dependencies
        self.source = source
        self.refresh = refresh
        try validateClean()
    }

    func validateClean() throws {
        guard center !== NotificationCenter.default, !context.autosaveEnabled,
              !context.container.configurations.isEmpty,
              context.container.configurations.allSatisfy(\.isStoredInMemoryOnly) else {
            throw TaskTitleCommandIssue.ineligibleEnvironment
        }
        guard !context.hasChanges else { throw TaskTitleCommandIssue.dirtyContext }
        guard !ModelChanges.hasActiveTransaction(in: context) else { throw TaskTitleCommandIssue.nestedTransaction }
    }

    func qualification(_ request: CommandSubtaskSourceRequest) throws -> CommandSubtaskSource {
        let evidence: CommandSubtaskEligibility
        do { evidence = try source(request) } catch { throw SubtaskCommandIssue.sourceUnavailable }
        guard evidence.parent.protection == .ordinary, evidence.input.protection == .ordinary,
              request.target == nil ? evidence.subtask == nil : evidence.subtask?.protection == .ordinary else {
            throw SubtaskCommandIssue.protectedContent
        }
        // L8：自读父待办备注取带键摘要；子任务类指令本批不放宽，父待办有备注仍拒绝。摘要随资格参与后续相等比较。
        let parent = CommandNotesProofReader.proving(evidence.parent, of: request.parent, in: context, key: notesKey)
        guard parent.notes != .unproven else { throw SubtaskCommandIssue.sourceUnavailable }
        guard CommandNotesProofReader.admits(request.command.rawValue, parent.notes) else {
            throw TaskTitleCommandIssue.notesNotSupported
        }
        try validateClean()
        return .init(environmentID: id, contextID: ObjectIdentifier(context), storageID: ObjectIdentifier(context.container),
                     eligibility: .init(parent: parent, subtask: evidence.subtask, input: evidence.input))
    }

    func publish(_ effects: TaskTitleCommandEnvironment.Effects) throws {
        try beforePublication()
        guard let followUp = effects.followUp else { throw SubtaskCommandIssue.stale }
        BoardEvents.changed(dependencies: .init(center: center) { [self] includeCalendar in
            MainActor.assumeIsolated {
                effects.refreshRequested = true
                do { effects.observed = try refresh(followUp, includeCalendar) }
                catch { effects.observed = nil }
            }
        })
        try afterPublication()
    }
}
