import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class TaskFieldCommandFixture {
    let io: TaskTitleCommandIO
    let environment: TaskTitleCommandEnvironment
    let adapter: TaskFieldCommandAdapter
    var base: TaskTitleFixture { io.base }
    var handoff: HandoffFixture { base.handoff }

    init() throws {
        io = try TaskTitleCommandIO()
        environment = try io.environment()
        adapter = .init(coordinator: io.base.handoff.coordinator, environment: environment)
    }

    static func argument(_ kind: Int, unchanged: Bool = false) -> CommandArgument {
        switch kind {
        case 0: return .init(parameter: .day, operation: .assign, value: .day(unchanged ? "2026-10-05" : "2026-10-09"))
        case 1: return .init(parameter: .priority, operation: .assign, value: .choice(unchanged ? "p2" : "p3"))
        case 2: return .init(parameter: .time, operation: .setReminder, value: .time(unchanged ? 420 : 570))
        default: return .init(parameter: .time, operation: .cancelReminder, value: nil)
        }
    }
    static func command(_ kind: Int) -> String { kind == 0 ? "todo.move" : kind == 1 ? "todo.priority" : "todo.reminder" }

    func prepare(_ kind: Int, unchanged: Bool = false) throws -> CommandTaskFieldAcceptance {
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source,
            commandID: .init(rawValue: Self.command(kind)), targets: .init(.single, objects: [.init(type: .todo, id: base.todo.id)]),
            arguments: [Self.argument(kind, unchanged: unchanged)])
        try handoff.queue(draft)
        let preview = try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
        #expect(count("save") == 0 && count("ui") == 0)
        return try adapter.accept(preview, expecting: handoff.owned().lease)
    }
    func submit(_ accepted: CommandTaskFieldAcceptance) throws -> CommandTaskFieldFacts {
        try adapter.submit(accepted: accepted, expecting: handoff.owned().lease)
    }
    func count(_ action: String) -> Int { base.io.trace.filter { $0 == action }.count }
}

@Suite(.serialized) @MainActor struct TaskFieldCommandTests {
    @Test(arguments: [0, 1, 2, 3]) func writesOnlyActualFieldsAndPublishesOnce(kind: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        let accepted = try fixture.prepare(kind)
        let before = fixture.base.todo.snapshot
        let facts = try fixture.submit(accepted)
        let todo = try #require(fixture.base.io.readTodos().first)
        #expect(facts.state == .saved && facts.save == .returned && facts.publication == .returned)
        #expect(todo.dayKey == (kind == 0 ? "2026-10-09" : before.dayKey))
        #expect(todo.isImportant == (kind == 1 ? false : before.isImportant))
        #expect(todo.isUrgent == (kind == 1 ? true : before.isUrgent))
        #expect(todo.remindMinutes == (kind == 2 ? 570 : kind == 3 ? nil : before.remindMinutes))
        #expect(todo.title == before.title && todo.notes == before.notes && todo.tagIDs == before.tagIDs)
        #expect(todo.createdAt == before.createdAt && todo.isDone == before.isDone && todo.sourceBundleID == before.sourceBundleID)
        #expect(todo.calendarEventID == "qa.calendar" && todo.sortOrder == 7 && todo.dueMinutes == 600)
        #expect(fixture.base.deleted.deletedAt == TaskTitleFixture.deletion)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(fixture.io.notificationProcessed == 1 && fixture.io.calendarProcessed == 1)
        #expect(fixture.base.io.authorizations == (kind == 2 ? [570] : []))
        #expect(fixture.io.observedContexts.last?.dayKey == todo.dayKey)
        #expect(try fixture.handoff.state().execution?.outputs.isEmpty == true)
        #expect(try fixture.base.io.context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 1)
    }

    @Test(arguments: [0, 1, 2, 3]) func completeNoChangeHasNoWrites(kind: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        if kind == 3 { fixture.base.todo.remindMinutes = nil; try fixture.base.io.context.save() }
        let accepted = try fixture.prepare(kind, unchanged: true)
        #expect(accepted.preview.noChange)
        #expect(try fixture.submit(accepted).state == .noChange)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
        #expect(fixture.base.io.authorizations.isEmpty && fixture.base.io.registered.isEmpty)
    }

    @Test(arguments: [0, 1, 2]) func staleBaselineAndDirtyContextKeepUnrelatedEdits(kind: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        let accepted = try fixture.prepare(kind)
        fixture.base.todo.dueMinutes = 800
        #expect(throws: TaskTitleCommandIssue.dirtyContext) { try fixture.submit(accepted) }
        #expect(fixture.base.todo.dueMinutes == 800 && fixture.base.io.context.hasChanges)
        try fixture.base.io.context.save()
        switch kind {
        case 0: fixture.base.todo.dayKey = "2026-10-10"
        case 1: fixture.base.todo.isUrgent = true
        default: fixture.base.todo.remindMinutes = nil
        }
        try fixture.base.io.context.save()
        #expect(throws: TaskFieldCommandIssue.fieldsChanged) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test(arguments: [0, 1, 2, 3, 4]) func identityCatalogAndSourceAreRechecked(kind: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        let accepted = try fixture.prepare(0)
        switch kind {
        case 0: fixture.base.todo.deletedAt = Date(timeIntervalSince1970: 999)
        case 1: fixture.base.io.context.insert(TodoItem(id: fixture.base.todo.id, title: "duplicate", dayKey: "2026-10-01"))
        case 2: fixture.base.live.name = "目录变化"
        case 3: fixture.io.revision = UUID()
        default: fixture.io.notes = .unknown
        }
        try fixture.base.io.context.save()
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0)
    }

    @Test(arguments: [0, 1, 2, 3]) func transactionFailureFactsCannotReplay(kind: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        let accepted = try fixture.prepare(0)
        switch kind {
        case 0: fixture.io.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        case 1: fixture.io.saveMode = .throwAfter
        case 2: fixture.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected }
        default: fixture.io.afterRegistration = { throw TaskCreateCommandIO.Failure.injected }
        }
        if kind == 0 {
            #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        } else {
            let facts = try fixture.submit(accepted)
            #expect(facts.state == (kind == 1 ? .unknown : .saved))
            #expect(kind != 2 || facts.publicationFailed)
            #expect(kind != 3 || facts.registrationFailed)
        }
        let saves = fixture.count("save")
        let another = TaskFieldCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        #expect(throws: (any Error).self) { try another.submit(accepted: accepted, expecting: fixture.handoff.owned().lease) }
        #expect(fixture.count("save") == saves)
        #expect(try fixture.base.io.context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
    }
}
