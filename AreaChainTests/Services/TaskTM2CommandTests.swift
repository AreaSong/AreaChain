import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TaskTM2CommandTests {
    typealias Fixture = TaskTM2Fixture

    @Test(arguments: [0, 1, 2]) func completionUsesExplicitSingleTargetSemantics(kind: Int) throws {
        let fixture = try Fixture()
        fixture.base.todo.isDone = kind != 0
        let open = try fixture.child("open")
        let done = try fixture.child("done", done: true)
        let deleted = try fixture.child("deleted", deleted: true)
        let before = fixture.base.todo.snapshot
        let accepted = try fixture.accept("todo.completion", Fixture.completion(kind != 1))
        #expect(accepted.preview.completion?.affected.map(\.id) == (kind == 0 ? [open.id] : []))
        let facts = try fixture.submit(accepted)
        #expect(facts.state == (kind == 2 ? .noChange : .saved))
        let todo = try fixture.todo()
        #expect(todo.isDone == (kind != 1))
        #expect(todo.subtasks.first { $0.id == open.id }?.isDone == (kind == 0))
        #expect(todo.subtasks.first { $0.id == done.id }?.isDone == true)
        #expect(todo.subtasks.first { $0.id == deleted.id }?.isDone == false)
        #expect(todo.subtasks.first { $0.id == deleted.id }?.deletedAt == TaskTitleFixture.deletion)
        #expect(fixture.count("save") == (kind == 2 ? 0 : 1) && fixture.count("ui") == (kind == 2 ? 0 : 1))
        try fixture.assertUnchanged(before, except: "completion")
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear])
    func tagsUseCurrentAssociationsAndPreserveOrder(mode: CommandFieldOperation) throws {
        let fixture = try Fixture()
        let extra = TagItem(name: "Extra", sortOrder: 2)
        fixture.context.insert(extra)
        fixture.base.todo.tagIDs = TagIDList.encode([fixture.base.live.id, extra.id])
        try fixture.context.save()
        let before = fixture.base.todo.snapshot
        let selected = mode == .remove ? [fixture.base.live.id] : [extra.id, fixture.base.deleted.id]
        let accepted = try fixture.accept("todo.tags", Fixture.tags(mode, selected))
        #expect(try fixture.tags().first { $0.id == fixture.base.deleted.id }?.deletedAt != nil)
        let facts = try fixture.submit(accepted)
        let expected: [UUID]
        switch mode {
        case .add: expected = [fixture.base.live.id, extra.id, fixture.base.deleted.id]
        case .remove: expected = [extra.id]
        case .replaceAll: expected = [extra.id, fixture.base.deleted.id]
        default: expected = []
        }
        #expect(try fixture.todo().tagIDs == TagIDList.encode(expected))
        #expect(facts.savedTagIDs == expected && facts.state == .saved)
        #expect(try fixture.tags().count == 3)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        try fixture.assertUnchanged(before, except: "tags")
    }

    @Test(arguments: [0, 1, 2, 3]) func createTagDistinguishesActualEffects(kind: Int) throws {
        let fixture = try Fixture()
        if kind == 1 { fixture.base.todo.tagIDs = ""; try fixture.context.save() }
        let names = [" New tag ", "work", "恢复", "Work"]
        let accepted = try fixture.accept("todo.createTag", Fixture.name(names[kind]))
        let effects = accepted.preview.tags?.actions.final.map(\.effect)
        #expect(effects == (kind == 0 ? [.createAndAssociate] : kind == 1 ? [.associateLive]
            : kind == 2 ? [.restoreAndAssociate] : []))
        let other = TaskFieldCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment, capability: .milestone2)
        #expect(try other.accept(accepted.preview, expecting: fixture.handoff.owned().lease) == accepted)
        let facts = try fixture.submit(accepted)
        #expect(facts.state == (kind == 3 ? .noChange : .saved))
        let tags = try fixture.tags()
        #expect(tags.count == (kind == 0 ? 3 : 2))
        if kind == 0 {
            let created = try #require(tags.first { $0.name == "New tag" })
            #expect(created.id == accepted.tagCreationIDs[TagSyntax.normalizedName("New tag")])
            #expect(try TagIDList.contains(fixture.todo().tagIDs, created.id))
        }
        if kind == 2 { #expect(tags.first { $0.id == fixture.base.deleted.id }?.deletedAt == nil) }
        #expect(throws: (any Error).self) { try other.submit(accepted: accepted, expecting: fixture.handoff.owned().lease) }
        #expect(fixture.count("save") == (kind == 3 ? 0 : 1))
    }

    @Test(arguments: [0, 1439, 600, -1]) func dueAssignClearAndNoChange(minutes: Int) throws {
        let fixture = try Fixture()
        let before = fixture.base.todo.snapshot
        let accepted = try fixture.accept("todo.due", Fixture.due(minutes < 0 ? nil : minutes))
        let facts = try fixture.submit(accepted)
        #expect(try fixture.todo().dueMinutes == (minutes < 0 ? nil : minutes))
        #expect(facts.state == (minutes == 600 ? .noChange : .saved))
        #expect(fixture.count("save") == (minutes == 600 ? 0 : 1) && fixture.count("ui") == (minutes == 600 ? 0 : 1))
        try fixture.assertUnchanged(before, except: "due")
    }

    @Test(arguments: [0, 1, 2, 3]) func unchangedTagOperationsAndEmptyDueNeverSave(kind: Int) throws {
        let fixture = try Fixture()
        let argument: CommandArgument
        switch kind {
        case 0: argument = Fixture.tags(.add, [fixture.base.live.id])
        case 1: argument = Fixture.tags(.remove, [fixture.base.deleted.id])
        case 2: fixture.base.todo.tagIDs = ""; argument = Fixture.tags(.clear)
        default: fixture.base.todo.dueMinutes = nil; argument = Fixture.due(nil)
        }
        try fixture.context.save()
        let accepted = try fixture.accept(kind == 3 ? "todo.due" : "todo.tags", argument)
        #expect(try fixture.submit(accepted).state == .noChange)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }
}
