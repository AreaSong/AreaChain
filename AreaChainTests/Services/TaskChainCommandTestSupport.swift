import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class TaskChainCommandIO {
    let creation: TaskCreateCommandIO
    var revision = UUID()
    var notes = CommandTaskTitleEligibility.Notes.absent
    var titleSaveMode = TaskCreateCommandIO.SaveMode.normal
    var titleBeforeTransaction: (() throws -> Void)?
    var titleSourceRead: (() throws -> Void)?
    var titleNotifications = 0
    var titleCalendars = 0
    let createEnvironment: TaskCreateCommandEnvironment
    var titleEnvironment: TaskTitleCommandEnvironment!

    init() throws {
        creation = try TaskCreateCommandIO()
        creation.capture.calendarEnabled = true
        creation.notificationResult = .succeeded
        creation.calendarResult = .succeeded
        createEnvironment = try creation.environment()
        var boundary = creation.capture.boundary
        boundary.save = { [unowned self] context in
            creation.capture.trace.append("saveTitle")
            if titleSaveMode == .throwBefore { throw TaskCreateCommandIO.Failure.injected }
            try context.save()
            if titleSaveMode == .throwAfter { throw TaskCreateCommandIO.Failure.injected }
        }
        titleEnvironment = try .init(context: creation.capture.context, center: creation.capture.center,
            dependencies: .init(repository: { SwiftDataTaskRepository(context: $0) }, transaction: boundary,
                registerLocalModification: { [unowned self] id in creation.capture.registered.append(id) },
                requestReminderAccessIfNeeded: creation.capture.dependencies.requestReminderAccessIfNeeded,
                validateBeforeTransaction: { [unowned self] in try titleBeforeTransaction?() }),
            source: { [unowned self] _ in
                try titleSourceRead?()
                return .init(revision: revision, protection: .ordinary, notes: notes)
            }, refresh: { [unowned self] _, includeCalendar in
                titleNotifications += 1
                if includeCalendar { titleCalendars += 1 }
                return .init(notificationRequested: true, calendarRequested: includeCalendar,
                             notificationResult: .succeeded, calendarResult: .succeeded)
            }, requestAuthorization: { [unowned self] minutes in
                creation.capture.authorizations.append(minutes)
                return .granted
            })
    }
}

@MainActor final class TaskChainCommandFixture {
    let io: TaskChainCommandIO
    let handoff: HandoffFixture
    let adapter: TaskChainCommandAdapter
    init() throws {
        io = try TaskChainCommandIO()
        handoff = try HandoffFixture()
        adapter = .init(create: .init(coordinator: handoff.coordinator, environment: io.createEnvironment),
                        title: .init(coordinator: handoff.coordinator, environment: io.titleEnvironment))
    }
    func queue(_ title: String = "第二步 #新增 !p3 @09:30") throws {
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                               arguments: TaskCreateCommandFixture.arguments("第一步")))
        let producer = try #require(handoff.state().plan.items.first)
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.title"),
                               arguments: [.init(parameter: .title, operation: .assign, value: .shortText(title))]))
        let consumer = try #require(handoff.state().plan.items.last)
        try handoff.plan(.link(consumer.stamp, .init(results: [.target: .init(producer: producer.stamp, outputType: .todo)])))
    }
    func create() throws -> CommandTaskCreateFacts {
        let prepared = try adapter.prepareCreation(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
        #expect(try io.creation.capture.readTodos().isEmpty)
        return try adapter.submitCreation(prepared, expecting: handoff.owned().lease)
    }
    func prepareTitle() throws -> CommandTaskTitlePreview { try adapter.prepareTitle(expecting: handoff.owned().lease) }
    func accept(_ preview: CommandTaskTitlePreview) throws -> CommandTaskTitleAcceptance {
        try adapter.acceptTitle(preview, expecting: handoff.owned().lease)
    }
    func submit(_ accepted: CommandTaskTitleAcceptance) throws -> CommandTaskTitleFacts {
        try adapter.submitTitle(accepted, expecting: handoff.owned().lease)
    }
    var run: CommandExecutionRun { get throws { try #require(handoff.state().execution) } }
}
