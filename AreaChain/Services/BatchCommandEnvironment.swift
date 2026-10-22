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
    let grant: CommandStoreGrant?
    let center: NotificationCenter
    let dependencies: Dependencies
    let source: (CommandObjectReference) throws -> CommandTaskTitleEligibility
    let refresh: (CommandObjectReference, Bool) throws -> TaskTitleCommandEnvironment.Refresh
    let stateOperations: RoutineCommandEnvironment.StateOperations?
    var beforePublication: () throws -> Void = {}
    var afterPublication: () throws -> Void = {}
    lazy var reader = BatchCommandReader(environment: self)
    /// 协调者的带键摘要（L6）；由装配它的适配器设置，用于自读备注的无备注证明（L8）。未设置即无证明、不可执行。
    var notesKey: CommandTextDigest?

    init(context: ModelContext, center: NotificationCenter, dependencies: Dependencies,
         source: @escaping (CommandObjectReference) throws -> CommandTaskTitleEligibility,
         refresh: @escaping (CommandObjectReference, Bool) throws -> TaskTitleCommandEnvironment.Refresh,
         stateOperations: RoutineCommandEnvironment.StateOperations? = nil,
         grant: CommandStoreGrant? = nil) throws {
        self.grant = grant
        self.context = context
        self.center = center
        self.dependencies = dependencies
        self.source = source
        self.refresh = refresh
        self.stateOperations = stateOperations
        // 正式版主 context 可能有原界面尚未自动保存的改动；凭据装配只在每次准备／提交前要求干净。
        if grant == nil { try validateClean() }
        else if !CommandStoreGrant.admits(context, center: center, grant: grant) { throw TaskTitleCommandIssue.ineligibleEnvironment }
    }

    func validateClean() throws {
        guard CommandStoreGrant.admits(context, center: center, grant: grant) else {
            throw TaskTitleCommandIssue.ineligibleEnvironment
        }
        guard dependencies.tasks.taskMutationContext === context,
              dependencies.routines.routineMutationContext === context else { throw CommandBatchIssue.invalidRepository }
        guard !context.hasChanges else { throw TaskTitleCommandIssue.dirtyContext }
        guard !ModelChanges.hasActiveTransaction(in: context) else { throw TaskTitleCommandIssue.nestedTransaction }
    }

    func publish(_ result: BatchCommandTransaction.Result) throws {
        try publish(changed: result.facts.impacts.filter { !$0.noChange }.map(\.target)) { result.facts.external = $0 }
    }

    /// 批量修改与 T-M4 回收共用私有发布；每个已改变对象只经注入刷新登记一次外部结果。
    func publish(changed targets: [CommandObjectReference],
                 observe: @escaping ([CommandBatchFacts.External]) -> Void) throws {
        try beforePublication()
        BoardEvents.changed(dependencies: .init(center: center) { [self] includeCalendar in
            MainActor.assumeIsolated {
                observe(targets.map { target in
                    var result = CommandBatchFacts.External(target: target, refreshRequested: true)
                    if let observed = try? self.refresh(target, includeCalendar) {
                        result.notificationRequested = observed.notificationRequested
                        result.calendarRequested = observed.calendarRequested
                        result.notification = observed.notificationRequested == true ? terminal(observed.notificationResult) : .unknown
                        result.calendar = observed.calendarRequested == true ? terminal(observed.calendarResult) : .unknown
                    }
                    return result
                })
            }
        })
        try afterPublication()
    }

    private func terminal(_ value: CommandExternalResult) -> CommandExternalResult {
        [.succeeded, .failed, .unknown].contains(value) ? value : .unknown
    }
}
