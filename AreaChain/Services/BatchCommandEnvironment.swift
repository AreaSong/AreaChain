import Foundation
import SwiftData

/// 显式隔离装配。唯一事务边界与私有发布属于整批，两个仓储不能分别保存或广播。
@MainActor final class BatchCommandEnvironment {
    struct Dependencies {
        let tasks: any TaskRepositoryProtocol
        let routines: any RoutineRepositoryProtocol
        var transaction: ModelChanges.Boundary
        var validateBeforeTransaction: () throws -> Void = {}
        var afterApply: (CommandObjectReference) throws -> Void = { _ in }
        var registerLocalModification: () throws -> Void = {}
    }
    let id = UUID()
    let context: ModelContext
    let center: NotificationCenter
    let dependencies: Dependencies
    let source: (CommandObjectReference) throws -> CommandTaskTitleEligibility
    let refresh: (CommandObjectReference, Bool) throws -> TaskTitleCommandEnvironment.Refresh
    var beforePublication: () throws -> Void = {}
    var afterPublication: () throws -> Void = {}
    lazy var reader = BatchCommandReader(environment: self)

    init(context: ModelContext, center: NotificationCenter, dependencies: Dependencies,
         source: @escaping (CommandObjectReference) throws -> CommandTaskTitleEligibility,
         refresh: @escaping (CommandObjectReference, Bool) throws -> TaskTitleCommandEnvironment.Refresh) throws {
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
        guard dependencies.tasks.taskMutationContext === context,
              dependencies.routines.routineMutationContext === context else { throw CommandBatchIssue.invalidRepository }
        guard !context.hasChanges else { throw TaskTitleCommandIssue.dirtyContext }
        guard !ModelChanges.hasActiveTransaction(in: context) else { throw TaskTitleCommandIssue.nestedTransaction }
    }

    func publish(_ result: BatchCommandTransaction.Result) throws {
        try beforePublication()
        BoardEvents.changed(dependencies: .init(center: center) { [self] includeCalendar in
            MainActor.assumeIsolated {
                result.facts.external = result.facts.impacts.filter { !$0.noChange }.map { impact in
                    var result = CommandBatchFacts.External(target: impact.target, refreshRequested: true)
                    if let observed = try? self.refresh(impact.target, includeCalendar) {
                        result.notificationRequested = observed.notificationRequested
                        result.calendarRequested = observed.calendarRequested
                        result.notification = observed.notificationRequested == true ? terminal(observed.notificationResult) : .unknown
                        result.calendar = observed.calendarRequested == true ? terminal(observed.calendarResult) : .unknown
                    }
                    return result
                }
            }
        })
        try afterPublication()
    }

    private func terminal(_ value: CommandExternalResult) -> CommandExternalResult {
        [.succeeded, .failed, .unknown].contains(value) ? value : .unknown
    }
}
