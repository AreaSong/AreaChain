import Foundation
import SwiftData

/// 沿创建适配的显式依赖模式；没有生产默认值，仅允许受控内存库、私有发布和 fake 消费者。
@MainActor final class TaskTitleCommandEnvironment {
    let context: ModelContext
    let center: NotificationCenter
    let dependencies: TaskMutationService.TitleDependencies
    let source: (UUID) throws -> CommandTaskTitleEligibility
    let refresh: (CommandTaskTitleContext, Bool) throws -> Refresh
    let requestAuthorization: (Int) -> CommandTaskTitleFacts.Authorization
    var beforePublication: () throws -> Void = {}
    var afterPublication: () throws -> Void = {}
    private var sourceRevision: UUID?
    private var readingTarget: UUID?
    lazy var fieldReader = TaskFieldCommandReader(environment: self)
    lazy var reader = TaskTitleCommandPreviewReader(context: context, sourceProtection: { [unowned self] in
        guard let readingTarget else { throw TaskTitleCommandIssue.stale }
        let evidence: CommandTaskTitleEligibility
        do { evidence = try source(readingTarget) }
        catch { throw TaskTitleCommandIssue.sourceUnavailable }
        guard evidence.notes == .absent else { throw TaskTitleCommandIssue.notesNotSupported }
        sourceRevision = evidence.revision
        return evidence.protection
    }, sourceRevision: { [unowned self] in sourceRevision })

    struct Refresh {
        var notificationRequested: Bool?
        var calendarRequested: Bool?
        var notificationResult: CommandExternalResult = .unknown
        var calendarResult: CommandExternalResult = .unknown
    }

    init(context: ModelContext, center: NotificationCenter,
         dependencies: TaskMutationService.TitleDependencies,
         source: @escaping (UUID) throws -> CommandTaskTitleEligibility,
         refresh: @escaping (CommandTaskTitleContext, Bool) throws -> Refresh,
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

    func reading<T>(target: UUID, _ work: () throws -> T) throws -> T {
        guard readingTarget == nil else { throw CommandExecutionError.busy }
        readingTarget = target
        defer { readingTarget = nil }
        return try work()
    }

    /// 每次调用独占效果对象，发布中的重入不能重置原调用的证据。
    final class Effects {
        var validationIssue: TaskTitleCommandIssue?
        var fieldConflict = false
        var followUp: CommandTaskTitleContext?
        var authorizationRequest = CommandTaskTitleFacts.Call.notCalled
        var authorizationResult = CommandTaskTitleFacts.Authorization.unknown
        var refreshRequested = false
        var observed: Refresh?
        var notification: CommandExternalResult {
            observed?.notificationRequested == true ? terminal(observed!.notificationResult) : .unknown
        }
        var calendar: CommandExternalResult {
            observed?.calendarRequested == true ? terminal(observed!.calendarResult) : .unknown
        }
        private func terminal(_ result: CommandExternalResult) -> CommandExternalResult {
            [.succeeded, .failed, .unknown].contains(result) ? result : .unknown
        }
    }

    func publish(_ effects: Effects) throws {
        try beforePublication()
        guard let followUp = effects.followUp else { throw TaskTitleCommandIssue.stale }
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
