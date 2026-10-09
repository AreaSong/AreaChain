import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanOutputBoundaryTests {
    @Test(arguments: [false, true]) func legacyAssemblyCannotAcquireTypedChains(branch: Bool) throws {
        let fixture = try MultiPlanOutputFixture(capability: .taskTitle)
        if branch {
            let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments())
            for title in ["一个", "两个"] { _ = try fixture.queue("todo.title", [SubtaskCommandFixture.title(title)], from: producer) }
        } else { _ = try fixture.chain() }
        #expect(throws: CommandMultiPlanIssue.unsupported) { _ = try fixture.prepare() }
        #expect(fixture.count("save") == 0 && fixture.subtaskSourceRequests.isEmpty)
    }

    @Test(arguments: [false, true]) func crossContextAndStorageRejectBeforeProducerWrites(sameStorage: Bool) throws {
        let fixture = try MultiPlanOutputFixture()
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments())
        _ = try fixture.queue("todo.title", [SubtaskCommandFixture.title("改名")], from: producer)
        let other = try TaskChainCommandIO()
        let original = other.titleEnvironment!
        let context = sameStorage ? ModelContext(fixture.context.container) : original.context
        context.autosaveEnabled = false
        let environment = try TaskTitleCommandEnvironment(context: context, center: original.center,
            dependencies: original.dependencies, source: original.source, refresh: original.refresh,
            requestAuthorization: original.requestAuthorization)
        let coordinator = fixture.handoff.coordinator
        let adapter = MultiPlanCommandAdapter(coordinator: coordinator, adapters: .init(
            taskCreate: fixture.adapter.taskCreate, taskTitle: .init(coordinator: coordinator, environment: environment)), outputCapability: .typedCreation)
        #expect(throws: CommandMultiPlanIssue.unsupported) {
            _ = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        #expect(fixture.count("save") == 0 && other.creation.capture.trace.isEmpty)
    }

    @Test(arguments: [0, 1, 2]) func changedCatalogSourceOrParentRequiresNewAcceptance(kind: Int) throws {
        let fixture = try MultiPlanOutputFixture()
        _ = try fixture.chain()
        try fixture.start()
        if kind == 0 { fixture.context.insert(TagItem(name: "新目录", sortOrder: 1)); try fixture.context.save() }
        if kind == 1 { fixture.sourceRevision = UUID() }
        if kind == 2 {
            let parent = try #require(fixture.context.fetch(FetchDescriptor<TodoItem>()).first)
            parent.title = "真实父名已改"
            try fixture.context.save()
        }
        #expect(throws: CommandMultiPlanIssue.confirmationRequired) { try fixture.confirm() }
        #expect(fixture.count("saveSubtask") == 0 && fixture.count("ui") == 1)
        try fixture.drain()
        #expect(try fixture.run.units.allSatisfy { $0.state == .succeeded } && fixture.children().count == 1)
    }

    @Test func sameUUIDReplacementCannotInheritSavedRecordOrAcceptedTarget() throws {
        let fixture = try MultiPlanOutputFixture()
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments())
        _ = try fixture.queue("todo.title", [SubtaskCommandFixture.title("不得写入替身")], from: producer)
        try fixture.start()
        let run = try fixture.run
        let id = try #require(run.outputs[producer.id]?.id)
        let original = try #require(fixture.context.fetch(FetchDescriptor<TodoItem>()).first)
        let record = original.persistentModelID
        fixture.context.delete(original)
        try fixture.context.save()
        let replacement = TodoItem(id: id, title: "同UUID另一记录", dayKey: "2026-10-05")
        fixture.context.insert(replacement)
        try fixture.context.save()
        #expect(replacement.persistentModelID != record)
        #expect(throws: (any Error).self) { try fixture.confirm() }
        #expect(replacement.title == "同UUID另一记录" && fixture.count("saveTitle") == 0)
        #expect(try fixture.run.outputs == run.outputs)
    }

    @Test func crossRunWrongTypeAndAlteredFactsCannotIssueOutputCredential() throws {
        let fixture = try MultiPlanOutputFixture()
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments())
        _ = try fixture.queue("todo.title", [SubtaskCommandFixture.title("改名")], from: producer)
        try fixture.start()
        let run = try fixture.run
        let coordinator = fixture.handoff.coordinator
        let reference = CommandCreationReference(producer: producer.stamp, outputType: .todo)
        let actual = try coordinator.multiPlanOutput(reference, in: run)
        #expect(actual.object.type == .todo && actual.object.id == run.units[0].taskCreation?.savedID)
        #expect(throws: (any Error).self) { _ = try coordinator.multiPlanOutput(.init(producer: producer.stamp, outputType: .subtask), in: run) }
        var altered = run
        altered.units[0].taskCreation?.save = .called
        #expect(throws: (any Error).self) { _ = try coordinator.multiPlanOutput(reference, in: altered) }
        let other = try MultiPlanOutputFixture()
        #expect(throws: (any Error).self) { _ = try other.handoff.coordinator.multiPlanOutput(reference, in: run) }
        var stale = producer.stamp
        stale = .init(id: stale.id, version: stale.version + 1)
        #expect(throws: (any Error).self) { _ = try coordinator.multiPlanOutput(.init(producer: stale, outputType: .todo), in: run) }
        #expect(fixture.count("saveTitle") == 0)
    }

    @Test(arguments: [0, 1, 2]) func producerProofDoesNotGrantConsumerOrdinaryQualification(kind: Int) throws {
        let fixture = try MultiPlanOutputFixture()
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments())
        _ = try fixture.queue("todo.title", [SubtaskCommandFixture.title("改名")], from: producer)
        if kind == 0 { fixture.io.notes = .present }
        else if kind == 1 { fixture.io.notes = .unknown }
        else { fixture.io.titleSourceRead = { throw TaskCreateCommandIO.Failure.injected } }
        try fixture.start()
        #expect(try fixture.run.units[0].state == .succeeded && fixture.run.units[1].state == .failed)
        #expect(fixture.adapter.pending == nil && fixture.count("saveTitle") == 0 && fixture.count("save") == 1)
    }

    @Test func graphRejectsUnknownSelfCycleForwardStaleAndMutuallyExclusiveInputs() throws {
        let fixture = try MultiPlanOutputFixture()
        let chain = try fixture.chain()
        for kind in 0..<6 {
            var items = chain
            switch kind {
            case 0: items[1].links.results[.parent] = .init(producer: .init(id: UUID(), version: 0), outputType: .todo)
            case 1: items[1].links.predecessors.insert(items[1].id)
            case 2: items[0].links.predecessors.insert(items[2].id)
            case 3: items.swapAt(0, 1)
            case 4: items[0].version += 1
            default:
                items[1].draft.edit(.init(parameter: .parent, operation: .assign, value: .object(.init(type: .todo, id: UUID()))),
                                    expecting: items[1].draft.stamp)
            }
            #expect(!CommandPlanValidation.check(items).canSealProtocol)
        }
        #expect(fixture.count("save") == 0)
    }

    @Test func typeCompatibilityDoesNotEnableBatchNotesOccurrenceOrMissingAdapters() throws {
        let capability = CommandMultiPlanOutputCapability.typedCreation
        for command in ["batch.move", "todo.notes", "todo.delete", "occurrence.complete", "routine.create", "tag.create"] {
            #expect(!capability.accepts(.init(rawValue: command), parameter: .target, type: .todo))
            #expect(!capability.accepts(.init(rawValue: command), parameter: .target, type: .routine))
        }
        let fixture = try MultiPlanOutputFixture()
        let items = try fixture.chain()
        let missing = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
            adapters: .init(taskCreate: fixture.adapter.taskCreate), outputCapability: .typedCreation)
        #expect(!missing.permitsReference(items[0], consumer: items[1], parameter: .parent))
        #expect(throws: CommandMultiPlanIssue.unassembled) {
            _ = try missing.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        #expect(fixture.count("save") == 0)
    }

    @Test(arguments: ["todo.title", "subtask.create", "todo.createTag"]) func knownProtectedInputIsRejectedBeforeCreation(command: String) throws {
        let fixture = try MultiPlanOutputFixture()
        let producer = try fixture.queue("todo.create", TaskCreateCommandFixture.arguments())
        let argument = command == "todo.createTag" ? CommandArgument(parameter: .name, operation: .assign, value: .shortText("密码"))
            : SubtaskCommandFixture.title("普通文字 #密码")
        _ = try fixture.queue(command, [argument], from: producer, parameter: command == "subtask.create" ? .parent : .target)
        #expect(throws: (any Error).self) { _ = try fixture.prepare() }
        #expect(fixture.count("save") == 0 && fixture.subtaskSourceRequests.isEmpty)
        #expect(try fixture.handoff.state().execution == nil)
    }
}
