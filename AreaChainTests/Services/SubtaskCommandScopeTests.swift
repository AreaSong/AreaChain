import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct SubtaskCommandScopeTests {
    typealias Fixture = SubtaskCommandFixture

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear])
    func explicitCreationTagsComposeWithoutReparsingTitle(mode: CommandFieldOperation) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.create", fixture.createArguments("标题 #Work #New",
            tags: TaskTM2Fixture.tags(mode, [fixture.base.live.id])))
        let facts = try fixture.submit(accepted)
        let created = try fixture.storedChild(accepted.object.id)
        let expected: [UUID]
        switch mode {
        case .add: expected = [fixture.base.live.id, try #require(accepted.tagCreationIDs["new"])]
        case .remove: expected = [try #require(accepted.tagCreationIDs["new"])]
        case .replaceAll: expected = [fixture.base.live.id]
        default: expected = []
        }
        #expect(created.title == "标题" && facts.savedTagIDs == expected)
        #expect(created.tagIDs == TagIDList.encode(expected))
        #expect(try fixture.tags().count == (mode == .add || mode == .remove ? 3 : 2))
    }

    @Test(arguments: [false, true]) func tagOnlyTitleAndProtectedClearKeepTheirDistinctPolicies(protected: Bool) throws {
        let fixture = try Fixture()
        let text = protected ? "#密码" : "#New"
        try fixture.queue("subtask.create", fixture.createArguments(text,
            tags: protected ? TaskTM2Fixture.tags(.clear) : nil))
        if protected { #expect(throws: (any Error).self) { try fixture.preview() } }
        else {
            let accepted = try fixture.adapter.accept(fixture.preview(), expecting: fixture.handoff.owned().lease)
            #expect(try fixture.submit(accepted).state == .saved)
            #expect(try fixture.storedChild(accepted.object.id).title == text)
        }
    }

    @Test(arguments: 0..<6) func incorrectRolesMultipleTargetsAndExtraArgumentsAreRejected(kind: Int) throws {
        let fixture = try Fixture()
        var targets = CommandDraftTargets(.single, objects: [.init(type: .subtask, id: fixture.child.id)])
        var arguments = [Fixture.title("New")]
        var command = "subtask.title"
        switch kind {
        case 0: targets = .init(.single, objects: [.init(type: .todo, id: fixture.base.todo.id)])
        case 1: targets = .init(.single, objects: [.init(type: .subtask, id: fixture.base.todo.id)])
        case 2: targets = .init(.selected, objects: [.init(type: .subtask, id: fixture.child.id), .init(type: .subtask, id: fixture.sibling.id)])
        case 3: arguments.append(.init(parameter: .notes, operation: .replace, value: .longText("unsupported")))
        case 4: command = "subtask.create"; arguments = fixture.createArguments()
        default: command = "subtask.completion"; arguments = [.init(parameter: .enabled, operation: .assign, value: nil)]
        }
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
                                       targets: targets, arguments: arguments))
        #expect(throws: (any Error).self) { try fixture.preview() }
        #expect(try fixture.handoff.state().plan.items.first?.draft.targets == targets)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test func sameUUIDAcrossTypesStillSelectsTheActualSubtask() throws {
        let fixture = try Fixture()
        fixture.child.id = fixture.base.todo.id
        try fixture.context.save()
        let parent = fixture.base.todo.snapshot
        let accepted = try fixture.accept("subtask.title", [Fixture.title("child only")])
        let facts = try fixture.submit(accepted)
        #expect(facts.object == .init(type: .subtask, id: fixture.base.todo.id) && facts.createdObject == nil)
        #expect(try fixture.storedChild().title == "child only")
        try fixture.assertParentUnchanged(parent)
    }

    @Test func multiItemAndUnassembledCapabilitiesRemainClosed() throws {
        let fixture = try Fixture()
        let closed = SubtaskCommandAdapter(coordinator: fixture.handoff.coordinator)
        for command in CommandSubtaskEdit.commands { #expect(!closed.supports(.init(rawValue: command))) }
        for command in ["subtask.order", "subtask.delete", "todo.create", "routine.title"] {
            #expect(!fixture.adapter.supports(.init(rawValue: command)))
        }
        try fixture.queue("subtask.title", [Fixture.title("one")])
        try fixture.queue("subtask.title", [Fixture.title("two")])
        #expect(throws: SubtaskCommandIssue.unsupportedPlan) { try fixture.preview() }
        #expect(try fixture.handoff.state().plan.items.count == 2 && fixture.count("save") == 0)
        #expect(CommandCatalog.standard.command(id: .init(rawValue: "subtask.create"))?.createdObjectType == .subtask)
    }
}
