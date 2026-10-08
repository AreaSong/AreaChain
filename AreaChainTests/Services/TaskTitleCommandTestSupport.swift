import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class TaskTitleCommandIO {
    let base: TaskTitleFixture
    var revision = UUID()
    var notes = CommandTaskTitleEligibility.Notes.absent
    var sourceRead: (() throws -> Void)?
    var beforeTransaction: (() throws -> Void)?
    var afterRegistration: (() throws -> Void)?
    var onRefresh: (() throws -> Void)?
    var saveMode = TaskCreateCommandIO.SaveMode.normal
    var notificationResult = CommandExternalResult.unknown
    var calendarResult = CommandExternalResult.unknown
    var notificationProcessed = 0
    var calendarProcessed = 0
    var observedContexts: [CommandTaskTitleContext] = []

    init() throws {
        base = try TaskTitleFixture()
        // 合成来源所有者建立无备注证明；命令服务不读取 notes 来猜资格。
        base.todo.notes = ""
        try base.io.context.save()
    }

    func environment() throws -> TaskTitleCommandEnvironment {
        var dependencies = base.dependencies
        dependencies.transaction.save = { [self] context in
            base.io.trace.append("save")
            if saveMode == .throwBefore { throw TaskCreateCommandIO.Failure.injected }
            try context.save()
            base.io.trace.append("saved")
            if saveMode == .throwAfter { throw TaskCreateCommandIO.Failure.injected }
        }
        dependencies.validateBeforeTransaction = { [self] in try beforeTransaction?() }
        let registration = dependencies.registerLocalModification
        dependencies.registerLocalModification = { [self] id in try registration(id); try afterRegistration?() }
        return try .init(context: base.io.context, center: base.io.center, dependencies: dependencies,
                         source: { [self] target in
            #expect(target == base.todo.id)
            try sourceRead?()
            return .init(revision: revision, protection: base.protection, notes: notes)
        }, refresh: { [self] context, includeCalendar in
            observedContexts.append(context)
            base.io.events.requestRefresh(includeCalendar)
            try onRefresh?()
            if notificationResult != .unknown { notificationProcessed += 1 }
            if includeCalendar && calendarResult != .unknown { calendarProcessed += 1 }
            return .init(notificationRequested: true, calendarRequested: includeCalendar,
                         notificationResult: notificationResult, calendarResult: calendarResult)
        }, requestAuthorization: { [self] minutes in
            base.io.dependencies.requestReminderAccessIfNeeded(minutes)
            return .granted
        })
    }
}

@MainActor final class TaskTitleCommandFixture {
    let io: TaskTitleCommandIO
    let environment: TaskTitleCommandEnvironment
    let adapter: TaskTitleCommandAdapter
    var base: TaskTitleFixture { io.base }
    var handoff: HandoffFixture { base.handoff }

    init() throws {
        io = try TaskTitleCommandIO()
        environment = try io.environment()
        adapter = .init(coordinator: io.base.handoff.coordinator, environment: environment)
    }

    func prepare(_ text: String = "新标题") throws -> CommandTaskTitlePreview {
        try base.queue(text)
        return try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept(_ preview: CommandTaskTitlePreview) throws -> CommandTaskTitleAcceptance {
        try adapter.accept(preview, expecting: handoff.owned().lease)
    }
    func submit(_ accepted: CommandTaskTitleAcceptance) throws -> CommandTaskTitleFacts {
        try adapter.submit(accepted: accepted, expecting: handoff.owned().lease)
    }
    func request() throws -> TaskTitleCommandRequest {
        _ = try handoff.seal()
        let attempt = try handoff.begin()
        return try .init(lease: handoff.owned().lease,
                         operation: #require(handoff.state().execution?.operation(attempt.unitID)), attempt: attempt)
    }
    func unit() throws -> CommandExecutionUnit { try #require(handoff.state().execution?.units.first) }
    func count(_ action: String) -> Int { base.io.trace.filter { $0 == action }.count }
}
