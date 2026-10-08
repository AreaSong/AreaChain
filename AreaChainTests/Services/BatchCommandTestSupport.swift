import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class BatchCommandFixture {
    let io: TaskCaptureFixture
    let handoff: HandoffFixture
    let todos: [TodoItem]
    let routine: DailyRoutine
    let other: TodoItem
    let tags: [TagItem]
    var context: ModelContext { io.context }
    var sourceRevision = UUID()
    var sourceOverride: [CommandObjectReference: CommandTaskTitleEligibility] = [:]
    var sourceRead: (() throws -> Void)?
    var beforeTransaction: (() throws -> Void)?
    var afterApply: ((CommandObjectReference) throws -> Void)?
    var afterRegistration: (() throws -> Void)?
    var onSave: (() throws -> Void)?
    var refreshTargets: [CommandObjectReference] = []
    var saveMode = TaskCreateCommandIO.SaveMode.normal
    var externalResult = CommandExternalResult.succeeded
    var today = "2026-10-08"
    var history: [UUID: [RoutineScheduleEvidence]] = [:]
    var historyRead: ((UUID) throws -> Void)?
    private(set) var environment: BatchCommandEnvironment!
    private(set) var adapter: BatchCommandAdapter!

    init(count: Int = 3, tagCount: Int = 3, stateOperations: Bool = false) throws {
        io = try TaskCaptureFixture()
        handoff = try HandoffFixture()
        tags = (0..<tagCount).map { TagItem(name: "Batch tag \($0)", sortOrder: $0) }
        tags.last?.deletedAt = Date(timeIntervalSince1970: 100)
        let firstTagID = tags[0].id
        todos = (0..<count).map { index in
            TodoItem(title: "批量任务 \(index) · Synthetic task", isDone: index % 2 == 0,
                dayKey: index == 0 ? "2026-10-09" : "2026-10-05", createdAt: Date(timeIntervalSince1970: 456),
                remindMinutes: 420, tagIDs: index == 0 ? firstTagID.uuidString : "", isImportant: true,
                sourceBundleID: "qa.batch", calendarEventID: "qa.calendar", sortOrder: index, dueMinutes: 600)
        }
        routine = DailyRoutine(id: todos[0].id, title: "同 UUID 的习惯 · Routine", sortOrder: 7,
            isEnabled: false, createdDayKey: "2026-09-01", weekdayMask: WeekdayMask.workdays,
            remindMinutes: 480, tagIDs: tags.last!.id.uuidString, pausedOnDayKey: "2026-10-01")
        other = TodoItem(title: "非目标 · Untouched", dayKey: "2026-10-04", tagIDs: tags[0].id.uuidString)
        for tag in tags { context.insert(tag) }
        for todo in todos { context.insert(todo) }
        context.insert(routine); context.insert(other)
        context.insert(RoutineCheck(dayKey: "2026-10-01", isDone: true, isSkipped: true, routine: routine))
        try context.save()
        var boundary = io.boundary
        boundary.save = { [unowned self] context in
            io.trace.append("save")
            try onSave?()
            if saveMode == .throwBefore { throw TaskCreateCommandIO.Failure.injected }
            try context.save()
            if saveMode == .throwAfter { throw TaskCreateCommandIO.Failure.injected }
        }
        let dependencies = BatchCommandEnvironment.Dependencies(
            tasks: SwiftDataTaskRepository(context: context), routines: SwiftDataRoutineRepository(context: context),
            transaction: boundary, validateBeforeTransaction: { [unowned self] in try beforeTransaction?() },
            afterApply: { [unowned self] target in try afterApply?(target) },
            registerLocalModification: { [unowned self] in io.trace.append("fact"); try afterRegistration?() })
        environment = try .init(context: context, center: io.center, dependencies: dependencies,
            source: { [unowned self] target in
                try sourceRead?()
                return sourceOverride[target] ?? .init(revision: sourceRevision, protection: .ordinary, notes: .absent)
            }, refresh: { [unowned self] target, includeCalendar in
                refreshTargets.append(target)
                return .init(notificationRequested: true, calendarRequested: includeCalendar,
                             notificationResult: externalResult, calendarResult: externalResult)
            }, stateOperations: stateOperations ? .init(now: { [unowned self] in
                DayKey.date(from: today, calendar: RoutineQueryFixture.dates.calendar)!
            }, calendar: RoutineQueryFixture.dates.calendar, history: { [unowned self] id in
                try historyRead?(id)
                return history[id] ?? []
            }) : nil)
        adapter = .init(coordinator: handoff.coordinator, environment: environment)
    }
    var taskTargets: [CommandObjectReference] { todos.map { .init(type: .todo, id: $0.id) } }
    var mixedTargets: [CommandObjectReference] { taskTargets + [.init(type: .routine, id: routine.id)] }
    var move: CommandArgument { .init(parameter: .day, operation: .assign, value: .day("2026-10-09")) }
    func tagArgument(_ operation: CommandFieldOperation = .add, index: Int = 0) -> CommandArgument {
        .init(parameter: .tags, operation: operation, value: .tags([tags[index].id]))
    }
    func queue(_ command: String = "batch.move", argument: CommandArgument? = nil,
               targets: [CommandObjectReference]? = nil) throws {
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
            targets: .init(.selected, objects: targets ?? taskTargets), arguments: [argument ?? move]))
    }
    func preview() throws -> CommandBatchPreview {
        try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept() throws -> CommandBatchAcceptance { try adapter.accept(preview(), expecting: handoff.owned().lease) }
    func submit(_ accepted: CommandBatchAcceptance) throws -> CommandBatchFacts {
        try adapter.submit(accepted: accepted, expecting: handoff.owned().lease)
    }
    func count(_ action: String) -> Int { io.trace.filter { $0 == action }.count }
    func request() throws -> TaskTitleCommandRequest {
        _ = try handoff.seal()
        let attempt = try handoff.begin()
        return try .init(lease: handoff.owned().lease,
                         operation: #require(handoff.state().execution?.operation(attempt.unitID)), attempt: attempt)
    }
}
