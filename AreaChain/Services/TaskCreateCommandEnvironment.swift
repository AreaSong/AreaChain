import Foundation
import SwiftData

/// 本阶段只装配内存库、私有事件源与明确 fake 消费者，无生产默认依赖。
@MainActor final class TaskCreateCommandEnvironment {
    let id = UUID()
    let context: ModelContext
    let source: () throws -> CommandTaskCreateSource
    let dependencies: TaskMutationService.Dependencies
    let center: NotificationCenter
    let refresh: (_ includeCalendar: Bool) throws -> Refresh
    var beforePublication: () throws -> Void = {}
    var afterPublication: () throws -> Void = {}
    private(set) var notification: CommandExternalResult = .unknown
    private(set) var calendar: CommandExternalResult = .unknown
    private(set) var refreshRequested = false

    struct Refresh {
        /// nil 表示无法确认是否请求；请求本身不能推导处理成功。
        var notificationRequested: Bool?
        var calendarRequested: Bool?
        var notificationResult: CommandExternalResult = .unknown
        var calendarResult: CommandExternalResult = .unknown
    }
    private(set) var observedRefresh: Refresh?

    init(context: ModelContext, center: NotificationCenter,
         source: @escaping () throws -> CommandTaskCreateSource,
         dependencies: TaskMutationService.Dependencies,
         refresh: @escaping (Bool) throws -> Refresh) throws {
        self.context = context
        self.center = center
        self.source = source
        self.dependencies = dependencies
        self.refresh = refresh
        try validate()
    }

    func validate() throws {
        guard center !== NotificationCenter.default, !context.autosaveEnabled,
              !context.container.configurations.isEmpty,
              context.container.configurations.allSatisfy(\.isStoredInMemoryOnly) else {
            throw TaskCreateCommandIssue.ineligibleEnvironment
        }
    }

    func validateClean() throws {
        try validate()
        guard !context.hasChanges else { throw TaskCreateCommandIssue.dirtyContext }
        // 不继承未知外层的保存/发布依赖；共享服务自己的嵌套 pending 契约保持原样。
        guard !ModelChanges.hasActiveTransaction(in: context) else { throw TaskCreateCommandIssue.nestedTransaction }
    }

    func publish() throws {
        notification = .unknown
        calendar = .unknown
        refreshRequested = false
        observedRefresh = nil
        try beforePublication()
        let events = BoardEvents.Dependencies(center: center) { [self] includeCalendar in
            MainActor.assumeIsolated {
                refreshRequested = true
                do {
                    let observed = try refresh(includeCalendar)
                    observedRefresh = observed
                    notification = observed.notificationRequested == true ? terminal(observed.notificationResult) : .unknown
                    calendar = observed.calendarRequested == true ? terminal(observed.calendarResult) : .unknown
                } catch {
                    // 消费者可能已部分处理；异常不证明零请求或零外部写入。
                    notification = .unknown
                    calendar = .unknown
                }
            }
        }
        BoardEvents.changed(dependencies: events)
        try afterPublication()
    }

    private func terminal(_ result: CommandExternalResult) -> CommandExternalResult {
        [.succeeded, .failed, .unknown].contains(result) ? result : .unknown
    }
}
