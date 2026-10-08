import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class RoutineCommandFixture {
    let base: TaskTitleFixture
    let routine: DailyRoutine
    let other: DailyRoutine
    var context: ModelContext { base.io.context }
    var handoff: HandoffFixture { base.handoff }
    var targetRevision = UUID()
    var inputRevision = UUID()
    var targetProtection = CommandProtectionRequirement.ordinary
    var inputProtection = CommandProtectionRequirement.ordinary
    var notes = CommandTaskTitleEligibility.Notes.absent
    var stateOperations = false
    var today = "2026-10-08"
    var stateHistory: [RoutineScheduleEvidence] = []
    var sourceRead: (() throws -> Void)?
    var beforeTransaction: (() throws -> Void)?
    var afterRegistration: (() throws -> Void)?
    var onRefresh: (() throws -> Void)?
    var onSave: (() throws -> Void)?
    var saveMode = TaskCreateCommandIO.SaveMode.normal
    var notificationResult = CommandExternalResult.succeeded
    var calendarResult = CommandExternalResult.succeeded
    var notificationProcessed = 0
    var calendarProcessed = 0
    var sourceTargets: [CommandObjectReference?] = []
    var repository: ((ModelContext) -> any RoutineRepositoryProtocol)?
    private(set) var environment: RoutineCommandEnvironment!
    private(set) var adapter: RoutineCommandAdapter!

    init(enabled: Bool = true, stateOperations: Bool = false) throws {
        self.stateOperations = stateOperations
        base = try TaskTitleFixture()
        base.todo.notes = ""
        routine = DailyRoutine(id: base.todo.id, title: "原习惯", sortOrder: 6, isEnabled: enabled,
            createdDayKey: "2026-09-01", weekdayMask: WeekdayMask.workdays,
            createdAt: Date(timeIntervalSince1970: 456), remindMinutes: 420,
            tagIDs: base.live.id.uuidString, isImportant: true, sourceBundleID: "qa.routine",
            pausedOnDayKey: enabled ? nil : "2026-10-01")
        other = DailyRoutine(title: "另一习惯", sortOrder: 9)
        context.insert(routine)
        context.insert(other)
        for index in 0..<4 {
            context.insert(RoutineCheck(dayKey: "2026-10-0\(index + 1)", isDone: index != 0,
                isSkipped: index == 2, routine: index == 3 ? other : routine))
        }
        try context.save()
        environment = try makeEnvironment()
        adapter = .init(coordinator: handoff.coordinator, environment: environment)
    }

    func makeEnvironment() throws -> RoutineCommandEnvironment {
        var boundary = base.io.boundary
        boundary.save = { [unowned self] context in
            base.io.trace.append("save")
            try onSave?()
            if saveMode == .throwBefore { throw TaskCreateCommandIO.Failure.injected }
            try context.save()
            base.io.trace.append("saved")
            if saveMode == .throwAfter { throw TaskCreateCommandIO.Failure.injected }
        }
        let dependencies = RoutineMutationService.Dependencies(repository: { [unowned self] context in
            if let repository { return repository(context) }
            return SwiftDataRoutineRepository(context: context)
        }, transaction: boundary, registerLocalModification: { [unowned self] id in
            base.io.registered.append(id)
            base.io.trace.append("fact")
            try afterRegistration?()
        }, requestReminderAccessIfNeeded: base.io.dependencies.requestReminderAccessIfNeeded,
           validateBeforeTransaction: { [unowned self] in try beforeTransaction?() })
        return try .init(context: context, center: base.io.center, dependencies: dependencies, source: { [unowned self] request in
            sourceTargets.append(request.target)
            try sourceRead?()
            return .init(target: .init(revision: targetRevision, protection: targetProtection, notes: notes),
                         input: .init(revision: inputRevision, protection: inputProtection))
        }, refresh: { [unowned self] _, includeCalendar in
            base.io.events.requestRefresh(includeCalendar)
            try onRefresh?()
            notificationProcessed += 1
            if includeCalendar { calendarProcessed += 1 }
            return .init(notificationRequested: true, calendarRequested: includeCalendar,
                         notificationResult: notificationResult, calendarResult: calendarResult)
        }, requestAuthorization: { [unowned self] minutes in
            base.io.authorizations.append(minutes)
            return .granted
        }, stateOperations: stateOperations ? .init(now: { [unowned self] in
            DayKey.date(from: today, calendar: RoutineQueryFixture.dates.calendar)!
        }, calendar: RoutineQueryFixture.dates.calendar, history: { [unowned self] _ in stateHistory }) : nil)
    }

    func queue(_ command: String, _ argument: CommandArgument, target: CommandObjectReference? = nil) throws {
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
            targets: .init(.single, objects: [target ?? .init(type: .routine, id: routine.id)]), arguments: [argument]))
    }
    func preview() throws -> CommandRoutinePreview {
        try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept(_ command: String, _ argument: CommandArgument) throws -> CommandRoutineAcceptance {
        try queue(command, argument)
        let accepted = try adapter.accept(preview(), expecting: handoff.owned().lease)
        #expect(count("save") == 0 && count("ui") == 0 && !context.hasChanges)
        return accepted
    }
    func submit(_ accepted: CommandRoutineAcceptance) throws -> CommandRoutineFacts {
        try adapter.submit(accepted: accepted, expecting: handoff.owned().lease)
    }
    func request() throws -> RoutineCommandRequest {
        _ = try handoff.seal()
        let attempt = try handoff.begin()
        return try .init(lease: handoff.owned().lease,
                        operation: #require(handoff.state().execution?.operation(attempt.unitID)), attempt: attempt)
    }
    func unit() throws -> CommandExecutionUnit { try #require(handoff.state().execution?.units.first) }
    func count(_ value: String) -> Int { base.io.trace.filter { $0 == value }.count }
    func stored() throws -> DailyRoutine {
        let reader = ModelContext(context.container)
        reader.autosaveEnabled = false
        return try #require(SwiftDataRoutineRepository(context: reader).fetchRoutines(withID: routine.id).first)
    }
    func tags() throws -> [TagItem] {
        let reader = ModelContext(context.container)
        reader.autosaveEnabled = false
        return try reader.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
    }
    struct Check: Equatable {
        let id: UUID
        let day: String
        let done: Bool
        let skipped: Bool
        let parent: UUID?
    }
    func checks() throws -> [Check] {
        let reader = ModelContext(context.container)
        reader.autosaveEnabled = false
        return try reader.fetch(FetchDescriptor<RoutineCheck>()).map {
            Check(id: $0.id, day: $0.dayKey, done: $0.isDone, skipped: $0.isSkipped, parent: $0.routine?.id)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
    func assertUnchanged(_ before: RoutineSnapshot, except fields: Set<RoutineField>) throws {
        let stored = try stored()
        let actual = stored.snapshot
        var expected = before
        if fields.contains(.title) { expected.title = actual.title }
        if fields.contains(.tagIDs) { expected.tagIDs = actual.tagIDs }
        if fields.contains(.isImportant) { expected.isImportant = actual.isImportant }
        if fields.contains(.isUrgent) { expected.isUrgent = actual.isUrgent }
        if fields.contains(.remindMinutes) { expected.remindMinutes = actual.remindMinutes }
        if fields.contains(.weekdayMask) { expected.weekdayMask = actual.weekdayMask }
        #expect(actual == expected)
        #expect(try context.fetchCount(FetchDescriptor<DailyRoutine>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
    }
    static func title(_ raw: String) -> CommandArgument { .init(parameter: .title, operation: .assign, value: .shortText(raw)) }
    static func argument(_ kind: Int, unchanged: Bool = false) -> CommandArgument {
        switch kind {
        case 0: return title(unchanged ? "原习惯" : "新习惯 !p3 @09:30 #New #恢复")
        case 1: return .init(parameter: .weekdays, operation: .assign, value: .weekdays(unchanged ? WeekdayMask.workdays : 65))
        case 2: return .init(parameter: .time, operation: .setReminder, value: .time(unchanged ? 420 : 570))
        case 3: return .init(parameter: .priority, operation: .assign, value: .choice(unchanged ? "p2" : "p3"))
        case 4: return .init(parameter: .tags, operation: unchanged ? .replaceAll : .clear,
                             value: unchanged ? .tags([TaskTitleFixture.liveID]) : nil)
        default: return .init(parameter: .time, operation: .cancelReminder, value: nil)
        }
    }
    static func command(_ kind: Int) -> String {
        "routine." + ["title", "weekdays", "reminder", "priority", "tags", "reminder"][kind]
    }
}
