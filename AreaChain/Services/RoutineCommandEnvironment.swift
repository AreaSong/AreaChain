import Foundation
import SwiftData

/// 只接受显式内存库与私有事件；来源分别证明定义和本次输入，绝不读取 notes 猜资格。
@MainActor final class RoutineCommandEnvironment {
    let id = UUID()
    let context: ModelContext
    let center: NotificationCenter
    let dependencies: RoutineMutationService.Dependencies
    let source: (CommandRoutineSourceRequest) throws -> CommandRoutineEligibility
    let refresh: (CommandObjectReference, Bool) throws -> TaskTitleCommandEnvironment.Refresh
    let requestAuthorization: (Int) -> CommandTaskTitleFacts.Authorization
    var beforePublication: () throws -> Void = {}
    var afterPublication: () throws -> Void = {}
    lazy var reader = RoutineCommandReader(environment: self)

    init(context: ModelContext, center: NotificationCenter, dependencies: RoutineMutationService.Dependencies,
         source: @escaping (CommandRoutineSourceRequest) throws -> CommandRoutineEligibility,
         refresh: @escaping (CommandObjectReference, Bool) throws -> TaskTitleCommandEnvironment.Refresh,
         requestAuthorization: @escaping (Int) -> CommandTaskTitleFacts.Authorization) throws {
        self.context = context
        self.center = center
        self.dependencies = dependencies
        self.source = source
        self.refresh = refresh
        self.requestAuthorization = requestAuthorization
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

    func qualification(_ request: CommandRoutineSourceRequest) throws -> CommandRoutineSource {
        let evidence: CommandRoutineEligibility
        do { evidence = try source(request) } catch { throw RoutineCommandIssue.sourceUnavailable }
        guard evidence.target.protection == .ordinary, evidence.input.protection == .ordinary else {
            throw RoutineCommandIssue.protectedContent
        }
        guard evidence.target.notes == .absent else { throw TaskTitleCommandIssue.notesNotSupported }
        try validateClean()
        return .init(environmentID: id, contextID: ObjectIdentifier(context), storageID: ObjectIdentifier(context.container),
                     eligibility: evidence)
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
