import Foundation
import SwiftData

/// 仅显式隔离装配；子项/输入证明没有从父证明推导的默认闭包。
@MainActor final class SubtaskCommandEnvironment {
    let id = UUID()
    let context: ModelContext
    let grant: CommandStoreGrant?
    let center: NotificationCenter
    let dependencies: TaskMutationService.SubtaskDependencies
    let source: (CommandSubtaskSourceRequest) throws -> CommandSubtaskEligibility
    let refresh: (CommandTaskTitleContext, Bool) throws -> TaskTitleCommandEnvironment.Refresh
    var beforePublication: () throws -> Void = {}
    var afterPublication: () throws -> Void = {}
    lazy var reader = SubtaskCommandReader(environment: self)
    /// 协调者的带键摘要；由装配它的适配器设置，用于自读备注的无备注证明。未设置即无证明、不可执行。
    var notesKey: CommandTextDigest?

    init(context: ModelContext, center: NotificationCenter, dependencies: TaskMutationService.SubtaskDependencies,
         source: @escaping (CommandSubtaskSourceRequest) throws -> CommandSubtaskEligibility,
         refresh: @escaping (CommandTaskTitleContext, Bool) throws -> TaskTitleCommandEnvironment.Refresh,
         grant: CommandStoreGrant? = nil) throws {
        self.grant = grant
        self.context = context
        self.center = center
        self.dependencies = dependencies
        self.source = source
        self.refresh = refresh
        // 正式版主 context 可能有原界面尚未自动保存的改动；凭据装配只在每次准备／提交前要求干净。
        if grant == nil { try validateClean() }
        else if !CommandStoreGrant.admits(context, center: center, grant: grant) { throw TaskTitleCommandIssue.ineligibleEnvironment }
    }

    func validateClean() throws {
        guard CommandStoreGrant.admits(context, center: center, grant: grant) else {
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
        // 自读父待办备注取带键摘要；子任务类指令不放宽，父待办有备注仍拒绝。摘要随资格参与后续相等比较。
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
