import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanOutputTests {
    @Test func threeLevelChainUsesRealParentAndChildAndSeparateAcceptances() throws {
        let fixture = try MultiPlanOutputFixture()
        let items = try fixture.chain()
        let preview = try fixture.prepare()
        #expect(fixture.subtaskSourceRequests.isEmpty && fixture.count("save") == 0)
        #expect(preview.identity.outputCapability == .typedCreation)
        try fixture.adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let parentID = try #require(fixture.run.outputs[items[0].id]?.id)
        guard case .subtask(let childPreview) = fixture.adapter.pending else { Issue.record("缺少真实父预览"); return }
        #expect(childPreview.parent.id == parentID && childPreview.original == nil && childPreview.input.target == nil)
        #expect(childPreview.input.parent?.id == parentID && childPreview.arguments.count == 1)
        #expect(try fixture.children().isEmpty && fixture.run.units[1].attempt == 0)
        try fixture.confirm()
        let childID = try #require(fixture.run.outputs[items[1].id]?.id)
        #expect(childID != parentID)
        guard case .subtask(let titlePreview) = fixture.adapter.pending else { Issue.record("缺少真实子项预览"); return }
        #expect(titlePreview.original?.id == childID && titlePreview.original?.title == "子任务")
        try fixture.confirm()
        let run = try fixture.run
        #expect(run.units.allSatisfy { $0.state == .succeeded })
        #expect(run.resolvedInput(items[1].id)?.targets == CommandDraftTargets.none)
        #expect(run.resolvedInput(items[1].id)?.arguments.contains(.init(parameter: .parent, operation: .assign,
            value: .object(.init(type: .todo, id: parentID)))) == true)
        #expect(run.bindings[items[2].id] == [.target: .init(type: .subtask, id: childID)])
        #expect(run.snapshot.items[1].links.results[.parent]?.producer == items[0].stamp)
        let child = try #require(fixture.children().first)
        #expect(child.id == childID && child.todo?.id == parentID && child.title == "新子标题")
        #expect(fixture.count("save") == 1 && fixture.count("saveSubtask") == 2 && fixture.count("ui") == 3)
        for index in 0..<2 {
            let type: CommandObjectType = index == 0 ? .todo : .subtask
            let output = try fixture.handoff.coordinator.multiPlanOutput(.init(producer: items[index].stamp, outputType: type), in: run)
            #expect(output.localAttempt.execution == run.stamp && output.producer == items[index].stamp)
            #expect(output.draft == items[index].draft.stamp)
            #expect(output.contextID == ObjectIdentifier(fixture.context) && output.storageID == ObjectIdentifier(fixture.context.container))
            #expect(fixture.handoff.coordinator.wasAttemptInvoked(output.localAttempt))
        }
    }

    @Test(arguments: Array(0..<8)) func everyTaskConsumerUsesActualOutput(kind: Int) throws {
        let fixture = try MultiPlanOutputFixture(composition: .ordinaryComposition)
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments("任务 #创建标签 !p2"))
        let commands = ["todo.title", "todo.move", "todo.priority", "todo.reminder", "todo.completion", "todo.tags", "todo.createTag", "todo.due"]
        let arguments: [CommandArgument] = [SubtaskCommandFixture.title("改后任务"),
            .init(parameter: .day, operation: .assign, value: .day("2026-10-12")),
            .init(parameter: .priority, operation: .assign, value: .choice("p3")),
            .init(parameter: .time, operation: .setReminder, value: .time(570)),
            .init(parameter: .enabled, operation: .assign, value: .boolean(true)),
            .init(parameter: .tags, operation: .clear),
            .init(parameter: .name, operation: .assign, value: .shortText("消费标签")),
            .init(parameter: .time, operation: .assign, value: .time(600))]
        let consumer = try fixture.queue(commands[kind], [arguments[kind]], from: producer)
        try fixture.start()
        #expect(fixture.adapter.pending != nil && fixture.count("saveTitle") == 0)
        try fixture.drain()
        let run = try fixture.run
        let id = try #require(run.outputs[producer.id]?.id)
        let todo = try #require(fixture.io.creation.capture.readTodos().first)
        #expect(todo.id == id && run.units.allSatisfy { $0.state == .succeeded })
        #expect(run.bindings[consumer.id] == [.target: .init(type: .todo, id: id)])
        #expect(fixture.count("save") == 1 && fixture.count("saveTitle") == 1 && fixture.count("ui") == 2)
        switch kind {
        case 0: #expect(todo.title == "改后任务")
        case 1: #expect(todo.dayKey == "2026-10-12")
        case 2: #expect(!todo.isImportant && todo.isUrgent)
        case 3: #expect(todo.remindMinutes == 570)
        case 4: #expect(todo.isDone)
        case 5: #expect(todo.tagIDs.isEmpty)
        case 6: #expect(TagIDList.parse(todo.tagIDs).count == 2)
        default: #expect(todo.dueMinutes == 600)
        }
    }

    @Test(arguments: [false, true]) func subtaskCompletionAndTagsConsumeChild(done: Bool) throws {
        let fixture = try MultiPlanOutputFixture()
        let parent = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments())
        let child = try fixture.queue("subtask.create", [SubtaskCommandFixture.title("子任务 #原标签")], from: parent, parameter: .parent)
        _ = try fixture.queue(done ? "subtask.completion" : "subtask.tags", [done
            ? .init(parameter: .enabled, operation: .assign, value: .boolean(true)) : .init(parameter: .tags, operation: .clear)], from: child)
        try fixture.start()
        try fixture.drain()
        let actual = try #require(fixture.children().first)
        #expect(try fixture.run.units.allSatisfy { $0.state == .succeeded })
        #expect(actual.isDone == done && (done || actual.tagIDs.isEmpty))
        #expect(fixture.count("save") == 1 && fixture.count("saveSubtask") == 2 && fixture.count("ui") == 3)
    }

    @Test func branchReadsPrecedingConsumerChangesAndRetainsOutput() throws {
        let fixture = try MultiPlanOutputFixture()
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments("原值"))
        _ = try fixture.queue("todo.title", [SubtaskCommandFixture.title("第一次 #新增")], from: producer)
        _ = try fixture.queue("todo.title", [SubtaskCommandFixture.title("第二次")], from: producer)
        _ = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments("独立任务"))
        try fixture.start()
        try fixture.confirm()
        guard case .taskTitle(let latest) = fixture.adapter.pending else { Issue.record("缺少后项确认"); return }
        #expect(latest.impact.originalValues[.title] == .text("第一次") && latest.impact.tags.original.count == 1)
        let producerUnit = try fixture.run.units[0]
        try fixture.drain()
        #expect(try fixture.run.units[0] == producerUnit && fixture.run.units.allSatisfy { $0.state == .succeeded })
        #expect(try fixture.io.creation.capture.readTodos().count == 2)
        #expect(fixture.count("save") == 2 && fixture.count("saveTitle") == 2 && fixture.count("ui") == 4)
    }

    @Test(arguments: Array(0..<6)) func everyRoutineConsumerUsesDefinitionOutput(kind: Int) throws {
        let fixture = try RoutineCreateFixture(stateOperations: true)
        try fixture.queue(title: "新习惯 #原标签")
        let producer = try #require(fixture.handoff.state().plan.items.first)
        let commands = ["routine.title", "routine.weekdays", "routine.reminder", "routine.priority", "routine.tags", "routine.enabled"]
        let arguments: [CommandArgument] = [RoutineCommandFixture.title("改后习惯"),
            .init(parameter: .weekdays, operation: .assign, value: .weekdays(WeekdayMask.all)),
            .init(parameter: .time, operation: .setReminder, value: .time(570)),
            .init(parameter: .priority, operation: .assign, value: .choice("p3")),
            .init(parameter: .tags, operation: .clear), .init(parameter: .enabled, operation: .assign, value: .boolean(false))]
        _ = try MultiPlanRoutineOutputSupport.queue(fixture, command: commands[kind], argument: arguments[kind], producer: producer)
        let adapter = MultiPlanRoutineOutputSupport.adapter(fixture)
        let beforeCount = try fixture.snapshots().count
        let preview = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        #expect(fixture.base.count("save") == 0)
        try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let created = try #require(fixture.handoff.state().execution?.outputs[producer.id])
        #expect(created.type == .routine && created.dayKey == nil)
        try adapter.confirmPending(expecting: fixture.handoff.owned().lease)
        let run = try #require(fixture.handoff.state().execution)
        let actual = try fixture.stored(created.id)
        #expect(run.units.allSatisfy { $0.state == .succeeded } && actual.checks.isEmpty)
        #expect(try fixture.snapshots().count == beforeCount + 1)
        #expect(fixture.base.count("save") == 2 && fixture.base.count("ui") == 2)
        switch kind {
        case 0: #expect(actual.title == "改后习惯")
        case 1: #expect(actual.weekdayMask == WeekdayMask.all)
        case 2: #expect(actual.remindMinutes == 570)
        case 3: #expect(!actual.isImportant && actual.isUrgent)
        case 4: #expect(actual.tagIDs.isEmpty)
        default: #expect(!actual.isEnabled)
        }
        let output = try fixture.handoff.coordinator.multiPlanOutput(.init(producer: producer.stamp, outputType: .routine), in: run)
        #expect(output.object == created && fixture.handoff.coordinator.wasAttemptInvoked(output.localAttempt))
    }
}
