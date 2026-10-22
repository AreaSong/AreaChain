import Foundation
import SwiftData

/// 只接受显式内存库与私有事件；来源分别证明定义和本次输入。备注由适配自读、只取带键摘要（L8）。
@MainActor final class RoutineCommandEnvironment {
    let id = UUID()
    let context: ModelContext
    let grant: CommandStoreGrant?
    let center: NotificationCenter
    let dependencies: RoutineMutationService.Dependencies
    let source: (CommandRoutineSourceRequest) throws -> CommandRoutineEligibility
    let refresh: (CommandObjectReference, Bool) throws -> TaskTitleCommandEnvironment.Refresh
    let requestAuthorization: (Int) -> CommandTaskTitleFacts.Authorization
    let stateOperations: StateOperations?
    let creation: Creation?
    var beforePublication: () throws -> Void = {}
    var afterPublication: () throws -> Void = {}
    /// 协调者的带键摘要（L6）；由装配它的适配器设置，用于自读备注的无备注证明（L8）。未设置即无证明、不可执行。
    var notesKey: CommandTextDigest?
    lazy var reader = RoutineCommandReader(environment: self)
    lazy var creationReader = RoutineCreateCommandReader(environment: self)

    init(context: ModelContext, center: NotificationCenter, dependencies: RoutineMutationService.Dependencies,
         source: @escaping (CommandRoutineSourceRequest) throws -> CommandRoutineEligibility,
         refresh: @escaping (CommandObjectReference, Bool) throws -> TaskTitleCommandEnvironment.Refresh,
         requestAuthorization: @escaping (Int) -> CommandTaskTitleFacts.Authorization,
         creation: Creation? = nil, stateOperations: StateOperations? = nil,
         grant: CommandStoreGrant? = nil) throws {
        self.grant = grant
        self.context = context
        self.center = center
        self.dependencies = dependencies
        self.source = source
        self.refresh = refresh
        self.requestAuthorization = requestAuthorization
        self.creation = creation
        self.stateOperations = stateOperations
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

    func qualification(_ request: CommandRoutineSourceRequest) throws -> CommandRoutineSource {
        let evidence: CommandRoutineEligibility
        do { evidence = try source(request) } catch { throw RoutineCommandIssue.sourceUnavailable }
        guard evidence.target.protection == .ordinary, evidence.input.protection == .ordinary else {
            throw RoutineCommandIssue.protectedContent
        }
        // L8：自读习惯备注取带键摘要；习惯字段类指令本批不放宽，有备注仍拒绝。摘要随资格参与后续相等比较。
        let target = CommandNotesProofReader.proving(evidence.target, of: request.target, in: context, key: notesKey)
        guard target.notes != .unproven else { throw RoutineCommandIssue.sourceUnavailable }
        guard CommandNotesProofReader.admits(request.command.rawValue, target.notes) else {
            throw TaskTitleCommandIssue.notesNotSupported
        }
        try validateClean()
        return .init(environmentID: id, contextID: ObjectIdentifier(context), storageID: ObjectIdentifier(context.container),
                     eligibility: .init(target: target, input: evidence.input))
    }

    func publish(_ effects: TaskTitleCommandEnvironment.Effects, target: CommandObjectReference) throws {
        try beforePublication()
        BoardEvents.changed(dependencies: .init(center: center) { [self] includeCalendar in
            MainActor.assumeIsolated {
                effects.refreshRequested = true
                do { effects.observed = try refresh(target, includeCalendar) }
                catch { effects.observed = nil }
            }
        })
        try afterPublication()
    }
}
