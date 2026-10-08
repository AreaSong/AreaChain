import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class TaskTM2Fixture {
    let io: TaskTitleCommandIO
    let environment: TaskTitleCommandEnvironment
    let adapter: TaskFieldCommandAdapter
    var base: TaskTitleFixture { io.base }
    var context: ModelContext { base.io.context }
    var handoff: HandoffFixture { base.handoff }

    init(failingRepository: Bool = false) throws {
        io = try TaskTitleCommandIO()
        let original = try io.environment()
        if failingRepository {
            var dependencies = original.dependencies
            dependencies.repository = { TaskTM2FailureRepository($0) }
            environment = try .init(context: original.context, center: original.center, dependencies: dependencies,
                source: original.source, refresh: original.refresh, requestAuthorization: original.requestAuthorization)
        } else { environment = original }
        adapter = .init(coordinator: io.base.handoff.coordinator, environment: environment, capability: .milestone2)
        io.notificationResult = .succeeded
        io.calendarResult = .succeeded
    }

    func queue(_ command: String, _ argument: CommandArgument) throws {
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
            targets: .init(.single, objects: [.init(type: .todo, id: base.todo.id)]), arguments: [argument]))
    }
    func preview() throws -> CommandTaskFieldPreview {
        try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept(_ command: String, _ argument: CommandArgument) throws -> CommandTaskFieldAcceptance {
        try queue(command, argument)
        let preview = try preview()
        let accepted = try adapter.accept(preview, expecting: handoff.owned().lease)
        #expect(count("save") == 0 && count("ui") == 0 && !context.hasChanges)
        return accepted
    }
    func submit(_ accepted: CommandTaskFieldAcceptance) throws -> CommandTaskFieldFacts {
        try adapter.submit(accepted: accepted, expecting: handoff.owned().lease)
    }
    func count(_ action: String) -> Int { base.io.trace.filter { $0 == action }.count }
    func tags() throws -> [TagItem] {
        let reader = ModelContext(context.container)
        reader.autosaveEnabled = false
        return try reader.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
    }
    func todo() throws -> TodoItem { try #require(base.io.readTodos().first) }
    func child(_ title: String, done: Bool = false, deleted: Bool = false) throws -> SubtaskItem {
        let child = SubtaskItem(title: title, isDone: done, deletedAt: deleted ? TaskTitleFixture.deletion : nil, todo: base.todo)
        context.insert(child)
        try context.save()
        return child
    }
    func assertUnchanged(_ before: TodoSnapshot, except: String) throws {
        let todo = try todo()
        #expect(todo.title == before.title && todo.notes == before.notes && todo.createdAt == before.createdAt)
        #expect(todo.dayKey == before.dayKey && todo.remindMinutes == before.remindMinutes)
        #expect(todo.isImportant == before.isImportant && todo.isUrgent == before.isUrgent)
        #expect(todo.sortOrder == 7 && todo.calendarEventID == "qa.calendar" && todo.sourceBundleID == before.sourceBundleID)
        if except != "completion" { #expect(todo.isDone == before.isDone) }
        if except != "tags" { #expect(todo.tagIDs == before.tagIDs) }
        if except != "due" { #expect(todo.dueMinutes == 600) }
        #expect(base.io.authorizations.isEmpty)
    }
    static func completion(_ done: Bool) -> CommandArgument { .init(parameter: .enabled, operation: .assign, value: .boolean(done)) }
    static func name(_ name: String) -> CommandArgument { .init(parameter: .name, operation: .assign, value: .shortText(name)) }
    static func tags(_ mode: CommandFieldOperation, _ ids: [UUID] = []) -> CommandArgument {
        .init(parameter: .tags, operation: mode, value: mode == .clear ? nil : .tags(ids))
    }
    static func due(_ minutes: Int?) -> CommandArgument {
        .init(parameter: .time, operation: minutes == nil ? .clear : .assign, value: minutes.map(CommandValue.time))
    }
}
