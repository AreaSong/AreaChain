import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class SubtaskCommandFixture {
    let base: TaskTitleFixture
    let child: SubtaskItem
    let sibling: SubtaskItem
    let tombstone: SubtaskItem
    var context: ModelContext { base.io.context }
    var handoff: HandoffFixture { base.handoff }
    var parentRevision = UUID()
    var childRevision = UUID()
    var inputRevision = UUID()
    var parentProtection = CommandProtectionRequirement.ordinary
    var childProtection: CommandProtectionRequirement? = .ordinary
    var inputProtection = CommandProtectionRequirement.ordinary
    var notes = CommandTaskTitleEligibility.Notes.absent
    var sourceRead: (() throws -> Void)?
    var beforeTransaction: (() throws -> Void)?
    var afterRegistration: (() throws -> Void)?
    var onRefresh: (() throws -> Void)?
    var onSave: (() throws -> Void)?
    var saveMode = TaskCreateCommandIO.SaveMode.normal
    var failMutation = false
    var notificationResult = CommandExternalResult.succeeded
    var calendarResult = CommandExternalResult.succeeded
    var notificationProcessed = 0
    var calendarProcessed = 0
    var sourceTargets: [CommandObjectReference?] = []
    var repository: ((ModelContext) -> any TaskRepositoryProtocol)?
    private(set) var environment: SubtaskCommandEnvironment!
    private(set) var adapter: SubtaskCommandAdapter!

    init() throws {
        base = try TaskTitleFixture()
        base.todo.notes = ""
        child = SubtaskItem(title: "子标题", sortOrder: 3, createdAt: Date(timeIntervalSince1970: 789),
                            tagIDs: TagIDList.encode([base.live.id]), todo: base.todo)
        sibling = SubtaskItem(title: "兄弟项", isDone: true, sortOrder: 9, todo: base.todo)
        tombstone = SubtaskItem(title: "墓碑", sortOrder: 99, deletedAt: TaskTitleFixture.deletion, todo: base.todo)
        context.insert(child)
        context.insert(sibling)
        context.insert(tombstone)
        try context.save()
        environment = try makeEnvironment()
        adapter = .init(coordinator: handoff.coordinator, environment: environment)
    }

    func makeEnvironment() throws -> SubtaskCommandEnvironment {
        var boundary = base.io.boundary
        boundary.save = { [unowned self] context in
            base.io.trace.append("save")
            try onSave?()
            if saveMode == .throwBefore { throw TaskCreateCommandIO.Failure.injected }
            try context.save()
            base.io.trace.append("saved")
            if saveMode == .throwAfter { throw TaskCreateCommandIO.Failure.injected }
        }
        let dependencies = TaskMutationService.SubtaskDependencies(repository: { [unowned self] context in
            if let repository { return repository(context) }
            return failMutation ? SubtaskFailureRepository(context) : SwiftDataTaskRepository(context: context)
        }, transaction: boundary, registerLocalModification: { [unowned self] id in
            base.io.registered.append(id)
            base.io.trace.append("fact")
            try afterRegistration?()
        }, validateBeforeTransaction: { [unowned self] in try beforeTransaction?() })
        return try .init(context: context, center: base.io.center, dependencies: dependencies, source: { [unowned self] request in
            sourceTargets.append(request.target)
            try sourceRead?()
            return .init(parent: .init(revision: parentRevision, protection: parentProtection, notes: notes),
                subtask: request.target == nil ? nil : childProtection.map { .init(revision: childRevision, protection: $0) },
                input: .init(revision: inputRevision, protection: inputProtection))
        }, refresh: { [unowned self] _, includeCalendar in
            base.io.events.requestRefresh(includeCalendar)
            try onRefresh?()
            notificationProcessed += 1
            if includeCalendar { calendarProcessed += 1 }
            return .init(notificationRequested: true, calendarRequested: includeCalendar,
                         notificationResult: notificationResult, calendarResult: calendarResult)
        })
    }

    func queue(_ command: String, _ arguments: [CommandArgument], target: CommandObjectReference? = nil) throws {
        let targets = command == "subtask.create" ? CommandDraftTargets.none
            : .init(.single, objects: [target ?? .init(type: .subtask, id: child.id)])
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
                               targets: targets, arguments: arguments))
    }
    func createArguments(_ title: String = "新子项", tags: CommandArgument? = nil) -> [CommandArgument] {
        [.init(parameter: .parent, operation: .assign, value: .object(.init(type: .todo, id: base.todo.id))), Self.title(title)]
            + (tags.map { [$0] } ?? [])
    }
    func preview() throws -> CommandSubtaskPreview {
        try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept(_ command: String, _ arguments: [CommandArgument]) throws -> CommandSubtaskAcceptance {
        try queue(command, arguments)
        let accepted = try adapter.accept(preview(), expecting: handoff.owned().lease)
        #expect(count("save") == 0 && count("ui") == 0 && !context.hasChanges)
        return accepted
    }
    func submit(_ accepted: CommandSubtaskAcceptance) throws -> CommandSubtaskFacts {
        try adapter.submit(accepted: accepted, expecting: handoff.owned().lease)
    }
    func request() throws -> TaskTitleCommandRequest {
        _ = try handoff.seal()
        let attempt = try handoff.begin()
        return try .init(lease: handoff.owned().lease,
                        operation: #require(handoff.state().execution?.operation(attempt.unitID)), attempt: attempt)
    }
    func unit() throws -> CommandExecutionUnit { try #require(handoff.state().execution?.units.first) }
    func count(_ value: String) -> Int { base.io.trace.filter { $0 == value }.count }
    func children() throws -> [SubtaskItem] {
        let reader = ModelContext(context.container)
        reader.autosaveEnabled = false
        return try reader.fetch(FetchDescriptor<SubtaskItem>())
    }
    func storedChild(_ id: UUID? = nil) throws -> SubtaskItem { try #require(children().first { $0.id == (id ?? child.id) }) }
    func tags() throws -> [TagItem] {
        let reader = ModelContext(context.container)
        reader.autosaveEnabled = false
        return try reader.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
    }
    func assertParentUnchanged(_ before: TodoSnapshot) throws {
        var expected = before
        expected.subtasks = []
        let parent = try #require(base.io.readTodos().first { $0.id == base.todo.id })
        var actual = parent.snapshot
        actual.subtasks = []
        #expect(actual == expected)
        #expect(parent.sortOrder == 7 && parent.dueMinutes == 600 && parent.calendarEventID == "qa.calendar")
        #expect(base.io.authorizations.isEmpty)
    }
    static func title(_ raw: String) -> CommandArgument { .init(parameter: .title, operation: .assign, value: .shortText(raw)) }
}
