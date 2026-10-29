import Foundation
import SwiftData

/// 沿创建适配的显式依赖模式；没有生产默认值，仅允许受控内存库、私有发布和 fake 消费者。
@MainActor final class TaskTitleCommandEnvironment {
    let context: ModelContext
    let grant: CommandStoreGrant?
    let center: NotificationCenter
    let dependencies: TaskMutationService.TitleDependencies
    let source: (UUID) throws -> CommandTaskTitleEligibility
    let refresh: (CommandTaskTitleContext, Bool) throws -> Refresh
    let requestAuthorization: (Int) -> CommandTaskTitleFacts.Authorization
    var beforePublication: () throws -> Void = {}
    var afterPublication: () throws -> Void = {}
    private var sourceRevision: UUID?
    private var sourceNotes: CommandNotesProof?
    /// 协调者的带键摘要；由装配它的适配器设置，用于自读备注的无备注证明。未设置即无证明、不可执行。
    var notesKey: CommandTextDigest?
    private var readingTarget: UUID?
    lazy var fieldReader = TaskFieldCommandReader(environment: self)
    lazy var reader = TaskTitleCommandPreviewReader(context: context, sourceProtection: { [unowned self] in
        guard let readingTarget else { throw TaskTitleCommandIssue.stale }
        let evidence: CommandTaskTitleEligibility
        do { evidence = try source(readingTarget) }
        catch { throw TaskTitleCommandIssue.sourceUnavailable }
        // 适配自读备注取带键摘要；标题不放宽（`//` 派生备注另行定界），有备注或无法证明都拒绝。
        let notes = CommandNotesProofReader.proof(of: .init(type: .todo, id: readingTarget), in: context, key: notesKey)
        guard notes != .unproven else { throw TaskTitleCommandIssue.sourceUnavailable }
        guard CommandNotesProofReader.admits("todo.title", notes) else { throw TaskTitleCommandIssue.notesNotSupported }
        sourceRevision = evidence.revision
        sourceNotes = notes
        return evidence.protection
    }, sourceRevision: { [unowned self] in sourceRevision }, sourceNotes: { [unowned self] in sourceNotes })

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
         requestAuthorization: @escaping (Int) -> CommandTaskTitleFacts.Authorization,
         grant: CommandStoreGrant? = nil) throws {
        self.grant = grant
        self.context = context
        self.center = center
        self.dependencies = dependencies
        self.source = source
        self.refresh = refresh
        self.requestAuthorization = requestAuthorization
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
