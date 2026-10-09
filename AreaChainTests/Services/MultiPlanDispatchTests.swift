import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor enum MultiPlanDispatchFixture {
    /// 用另一个显式隔离存储的真实创建作前置，检查后项不能误用首项/全局输出限制。
    static func execute(_ handoff: HandoffFixture, adapters: MultiPlanCommandAdapter.Adapters) throws -> CommandExecutionRun {
        let creation = try TaskCreateCommandIO()
        creation.capture.calendarEnabled = true
        creation.notificationResult = .succeeded
        creation.calendarResult = .succeeded
        var adapters = adapters
        adapters.taskCreate = .init(coordinator: handoff.coordinator, environment: try creation.environment())
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                               arguments: TaskCreateCommandFixture.arguments("真实前置")))
        let items = try handoff.state().plan.items
        try handoff.plan(.reorder([items.last!.id] + items.dropLast().map(\.id)))
        let adapter = MultiPlanCommandAdapter(coordinator: handoff.coordinator, adapters: adapters)
        let preview = try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
        try adapter.submit(preview, expecting: handoff.owned().lease)
        let run = try #require(handoff.state().execution)
        #expect(run.units.allSatisfy { $0.state == .succeeded })
        #expect(run.outputs.count == 1 && run.outputs[items.last!.id] != nil)
        #expect(try creation.capture.readTodos().count == 1)
        return run
    }
}

@Suite(.serialized) @MainActor struct MultiPlanDispatchTests {
    @Test(arguments: ["move", "priority", "reminder", "due", "completion", "tags", "createTag"])
    func eachTaskFieldActuallySavesItsOwnMember(command: String) throws {
        let fixture = try TaskFieldCommandFixture()
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        let argument: CommandArgument
        switch command {
        case "move": argument = TaskFieldCommandFixture.argument(0)
        case "priority": argument = TaskFieldCommandFixture.argument(1)
        case "reminder": argument = TaskFieldCommandFixture.argument(2)
        case "due": argument = .init(parameter: .time, operation: .assign, value: .time(710))
        case "completion": argument = .init(parameter: .enabled, operation: .assign, value: .boolean(false))
        case "tags": argument = .init(parameter: .tags, operation: .clear, value: nil)
        default: argument = .init(parameter: .name, operation: .assign, value: .shortText("多项新标签"))
        }
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo." + command),
            targets: .init(.single, objects: [.init(type: .todo, id: fixture.base.todo.id)]), arguments: [argument]))
        let adapter = TaskFieldCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment, capability: .milestone2)
        let run = try MultiPlanDispatchFixture.execute(fixture.handoff, adapters: .init(taskField: adapter))
        #expect(run.units[1].taskField?.state == .saved && run.units[1].taskField?.targetID == fixture.base.todo.id)
        let todo = try #require(fixture.base.io.readTodos().first)
        switch command {
        case "move": #expect(todo.dayKey == "2026-10-09")
        case "priority": #expect(!todo.isImportant && todo.isUrgent)
        case "reminder": #expect(todo.remindMinutes == 570)
        case "due": #expect(todo.dueMinutes == 710)
        case "completion": #expect(!todo.isDone)
        case "tags": #expect(todo.tagIDs.isEmpty)
        default: #expect(TagIDList.parse(todo.tagIDs).count == 2)
        }
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }

    @Test(arguments: ["create", "title", "completion", "tags"])
    func eachSubtaskEntryActuallySavesItsOwnMember(command: String) throws {
        let fixture = try SubtaskCommandFixture()
        let arguments: [CommandArgument]
        switch command {
        case "create": arguments = fixture.createArguments("计划子项")
        case "title": arguments = [SubtaskCommandFixture.title("计划改名")]
        case "completion": arguments = [.init(parameter: .enabled, operation: .assign, value: .boolean(true))]
        default: arguments = [.init(parameter: .tags, operation: .clear, value: nil)]
        }
        try fixture.queue("subtask." + command, arguments)
        let run = try MultiPlanDispatchFixture.execute(fixture.handoff, adapters: .init(subtask: fixture.adapter))
        let facts = try #require(run.units[1].subtask)
        #expect(facts.state == .saved && facts.parentID == fixture.base.todo.id)
        let stored = try fixture.storedChild(facts.object.id)
        switch command {
        case "create": #expect(stored.title == "计划子项" && facts.createdObject == facts.object)
        case "title": #expect(stored.title == "计划改名")
        case "completion": #expect(stored.isDone)
        default: #expect(stored.tagIDs.isEmpty)
        }
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(run.outputs[facts.object.id] == nil)
    }

    @Test(arguments: ["title", "weekdays", "reminder", "priority", "tags"])
    func eachRoutineDefinitionEntryActuallySaves(command: String) throws {
        let fixture = try RoutineCommandFixture()
        let argument: CommandArgument
        switch command {
        case "title": argument = RoutineCommandFixture.title("计划习惯")
        case "weekdays": argument = .init(parameter: .weekdays, operation: .assign, value: .weekdays(WeekdayMask.all))
        case "reminder": argument = .init(parameter: .time, operation: .setReminder, value: .time(570))
        case "priority": argument = .init(parameter: .priority, operation: .assign, value: .choice("p3"))
        default: argument = .init(parameter: .tags, operation: .clear, value: nil)
        }
        try fixture.queue("routine." + command, argument)
        let run = try MultiPlanDispatchFixture.execute(fixture.handoff, adapters: .init(routine: fixture.adapter))
        #expect(run.units[1].routine?.state == .saved && run.units[1].routine?.object.id == fixture.routine.id)
        let stored = try fixture.stored()
        switch command {
        case "title": #expect(stored.title == "计划习惯")
        case "weekdays": #expect(stored.weekdayMask == WeekdayMask.all && !stored.weekdaysOnly)
        case "reminder": #expect(stored.remindMinutes == 570)
        case "priority": #expect(!stored.isImportant && stored.isUrgent)
        default: #expect(stored.tagIDs.isEmpty)
        }
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }

    @Test(arguments: ["enabled", "complete", "skip", "reopen"])
    func eachRoutineStateEntryActuallySaves(command: String) throws {
        let fixture = try RoutineStateFixture(enabled: command != "enabled")
        let day = "2026-10-07"
        if command != "enabled" {
            fixture.history(day)
            if command == "reopen" { fixture.row(day, true) }
            try fixture.context.save()
        }
        try fixture.queue(command == "enabled" ? "routine.enabled" : "occurrence." + command,
                          day: command == "enabled" ? nil : day)
        let run = try MultiPlanDispatchFixture.execute(fixture.base.handoff, adapters: .init(routine: fixture.base.adapter))
        #expect(run.units[1].routine?.state == .saved)
        if command == "enabled" { #expect(fixture.routine.isEnabled) }
        else {
            let row = try #require(fixture.routine.checks.first { $0.dayKey == day })
            #expect(row.isDone == (command != "reopen") && row.isSkipped == (command == "skip"))
        }
        #expect(fixture.base.count("save") == 1 && fixture.base.count("ui") == 1)
    }

    @Test func routineCreationRetainsRealFactWithoutOutputDependency() throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue(title: "计划新增")
        let run = try MultiPlanDispatchFixture.execute(fixture.handoff, adapters: .init(routine: fixture.adapter))
        let facts = try #require(run.units[1].routineCreation)
        let saved = try fixture.stored(facts.creationID)
        #expect(facts.savedID == saved.id && saved.title == "计划新增")
        #expect(fixture.base.count("save") == 1 && fixture.base.count("ui") == 1)
        #expect(run.outputs[run.units[1].id] == nil)
    }
}
