import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class TaskCreateCommandIO {
    enum Failure: Error { case injected }
    enum SaveMode { case normal, throwBefore, throwAfter }
    let capture: TaskCaptureFixture
    var saveMode = SaveMode.normal
    var beforeTransaction: (() throws -> Void)?
    var sourceRead: (() throws -> Void)?
    var repositoryFactory: ((ModelContext) -> any TaskRepositoryProtocol)?
    var protection = CommandProtectionRequirement.ordinary
    var stampEnabled = true
    var notificationResult = CommandExternalResult.unknown
    var authorizationResult = CommandTaskCreateFacts.Authorization.unknown
    var calendarResult = CommandExternalResult.unknown
    var onRefresh: (() throws -> Void)?
    var notificationProcessed = 0
    var calendarProcessed = 0
    var afterRegistration: (() throws -> Void)?

    init() throws { capture = try TaskCaptureFixture() }

    func environment() throws -> TaskCreateCommandEnvironment {
        var dependencies = capture.dependencies
        dependencies.transaction.save = { [self] context in
            capture.trace.append("save")
            if saveMode == .throwBefore { throw Failure.injected }
            try context.save()
            capture.trace.append("saved")
            if saveMode == .throwAfter { throw Failure.injected }
        }
        dependencies.repository = { [self] context in repositoryFactory?(context) ?? SwiftDataTaskRepository(context: context) }
        dependencies.validateBeforeTransaction = { [self] in try beforeTransaction?() }
        let registration = dependencies.registerLocalCreation
        dependencies.registerLocalCreation = { [self] id in try registration(id); try afterRegistration?() }
        return try TaskCreateCommandEnvironment(context: capture.context, center: capture.center, source: { [self] in
            try sourceRead?()
            return .init(protection: protection, stampEnabled: stampEnabled, bundleID: capture.source)
        }, dependencies: dependencies, refresh: { [self] includeCalendar in
            capture.events.requestRefresh(includeCalendar)
            try onRefresh?()
            // fake 消费者只有实际处理后才返回完成；默认只记录刷新请求。
            if notificationResult != .unknown { notificationProcessed += 1 }
            if includeCalendar && capture.calendarEnabled && calendarResult != .unknown { calendarProcessed += 1 }
            return .init(notificationRequested: true, calendarRequested: includeCalendar && capture.calendarEnabled,
                         notificationResult: notificationResult, calendarResult: calendarResult)
        }, requestAuthorization: { [self] minutes in
            capture.dependencies.requestReminderAccessIfNeeded(minutes)
            return authorizationResult
        })
    }
}

@MainActor final class TaskCreateCommandFixture {
    let io: TaskCreateCommandIO
    let handoff: HandoffFixture
    let environment: TaskCreateCommandEnvironment
    let adapter: TaskCreateCommandAdapter

    init() throws {
        io = try TaskCreateCommandIO()
        handoff = try HandoffFixture()
        environment = try io.environment()
        adapter = TaskCreateCommandAdapter(coordinator: handoff.coordinator, environment: environment)
    }

    static func arguments(_ title: String = "合成普通任务", day: String = "2026-10-05") -> [CommandArgument] {
        [.init(parameter: .title, operation: .assign, value: .shortText(title)),
         .init(parameter: .day, operation: .assign, value: .day(day))]
    }

    @discardableResult
    func queue(_ arguments: [CommandArgument]? = nil) throws -> UUID {
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                               arguments: arguments ?? Self.arguments()))
    }

    func prepare() throws -> CommandTaskCreatePreparation {
        try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }

    func request() throws -> TaskCreateCommandRequest {
        _ = try handoff.seal()
        let attempt = try handoff.begin()
        return try .init(lease: handoff.owned().lease, operation: #require(handoff.state().execution?.operation(attempt.unitID)),
                         attempt: attempt)
    }

    func submit() throws -> CommandTaskCreateFacts {
        try adapter.submit(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }

    func unit() throws -> CommandExecutionUnit { try #require(handoff.state().execution?.units.first) }
    func count(_ action: String) -> Int { io.capture.trace.filter { $0 == action }.count }
}
