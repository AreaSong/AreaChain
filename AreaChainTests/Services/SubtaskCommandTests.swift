import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct SubtaskCommandTests {
    typealias Fixture = SubtaskCommandFixture

    @Test(arguments: [false, true]) func createUsesStableChildIdentityAndOldOrder(parentDone: Bool) throws {
        let fixture = try Fixture()
        fixture.base.todo.isDone = parentDone
        try fixture.context.save()
        let before = fixture.base.todo.snapshot
        let accepted = try fixture.accept("subtask.create", fixture.createArguments("新子项 !p1 @10:00 #恢复 #New",
            tags: TaskTM2Fixture.tags(.add, [fixture.base.live.id])))
        #expect(accepted.object.type == .subtask && accepted.object.id != fixture.base.todo.id)
        #expect(accepted.preview.input.parent?.id == fixture.base.todo.id && accepted.preview.input.target == nil)
        let other = SubtaskCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        #expect(try other.accept(accepted.preview, expecting: fixture.handoff.owned().lease) == accepted)
        let facts = try fixture.submit(accepted)
        let child = try fixture.storedChild(accepted.object.id)
        #expect(child.title == "新子项 !p1 @10:00" && !child.isDone && child.sortOrder == 10)
        #expect(child.todo?.id == fixture.base.todo.id && child.deletedAt == nil)
        #expect(child.createdAt > fixture.child.createdAt && child.createdAt <= Date())
        let newID = try #require(accepted.tagCreationIDs["new"])
        #expect(TagIDList.parse(child.tagIDs) == [fixture.base.deleted.id, newID, fixture.base.live.id])
        #expect(try fixture.tags().count == 3 && fixture.children().count == 4)
        #expect(facts.createdObject == accepted.object && facts.state == .saved && facts.savedTagIDs == TagIDList.parse(child.tagIDs))
        #expect(try fixture.unit().taskCreation == nil && fixture.handoff.state().execution?.outputs.isEmpty == true)
        #expect(try fixture.unit().subtask?.createdObject == accepted.object)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(fixture.notificationProcessed == 1 && fixture.calendarProcessed == 1)
        #expect(throws: (any Error).self) { try other.submit(accepted: accepted, expecting: fixture.handoff.owned().lease) }
        #expect(fixture.count("save") == 1)
        try fixture.assertParentUnchanged(before)
    }

    @Test(arguments: ["新标题 !p1 @10:00 #恢复 #New", "#Work", "子标题", "去掉文字中的标签", "标题 // 原文"])
    func titlePreservesTagOnlyAndMergingSemantics(raw: String) throws {
        let fixture = try Fixture()
        let before = fixture.child.snapshot
        let parent = fixture.base.todo.snapshot
        let accepted = try fixture.accept("subtask.title", [Fixture.title(raw)])
        let facts = try fixture.submit(accepted)
        let child = try fixture.storedChild()
        #expect(child.title == TagSyntax.title(from: raw, includesDiaryTags: false))
        #expect(child.todo?.id == before?.todoId && child.createdAt == before?.createdAt)
        #expect(child.isDone == before?.isDone && child.sortOrder == before?.sortOrder)
        #expect(TagIDList.contains(child.tagIDs, fixture.base.live.id))
        #expect(facts.createdObject == nil && facts.state == (raw == "子标题" ? .noChange : .saved))
        #expect(fixture.count("save") == (raw == "子标题" ? 0 : 1))
        try fixture.assertParentUnchanged(parent)
    }

    @Test func sameTitleWithTagEffectsStillSaves() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.title", [Fixture.title("子标题 #恢复 #New")])
        #expect(!accepted.preview.noChange)
        #expect(try fixture.submit(accepted).state == .saved)
        #expect(try fixture.storedChild().title == "子标题")
        #expect(try fixture.tags().first { $0.id == fixture.base.deleted.id }?.deletedAt == nil)
    }

    @Test(arguments: [0, 1, 2]) func explicitCompletionDoesNotChangeParentOrSibling(kind: Int) throws {
        let fixture = try Fixture()
        fixture.child.isDone = kind != 0
        try fixture.context.save()
        let parent = fixture.base.todo.snapshot
        let sibling = fixture.sibling.snapshot
        let target = kind != 1
        let accepted = try fixture.accept("subtask.completion", [TaskTM2Fixture.completion(target)])
        let facts = try fixture.submit(accepted)
        #expect(try fixture.storedChild().isDone == target)
        #expect(try fixture.storedChild(fixture.sibling.id).snapshot == sibling)
        #expect(facts.state == (kind == 2 ? .noChange : .saved))
        #expect(fixture.count("save") == (kind == 2 ? 0 : 1) && fixture.count("ui") == (kind == 2 ? 0 : 1))
        try fixture.assertParentUnchanged(parent)
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear])
    func tagModesStartFromChildAssociations(mode: CommandFieldOperation) throws {
        let fixture = try Fixture()
        let before = fixture.base.todo.snapshot
        let selected = mode == .remove ? [fixture.base.live.id] : [fixture.base.deleted.id]
        let accepted = try fixture.accept("subtask.tags", [TaskTM2Fixture.tags(mode, selected)])
        let facts = try fixture.submit(accepted)
        let expected = mode == .add ? [fixture.base.live.id, fixture.base.deleted.id]
            : mode == .replaceAll ? [fixture.base.deleted.id] : []
        #expect(try fixture.storedChild().tagIDs == TagIDList.encode(expected))
        #expect(facts.savedTagIDs == expected && facts.state == .saved && facts.createdObject == nil)
        #expect(try fixture.tags().count == 2)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        try fixture.assertParentUnchanged(before)
    }

    @Test(arguments: [0, 1, 2, 3]) func noChangeAndUntouchedTombstones(kind: Int) throws {
        let fixture = try Fixture()
        let argument: CommandArgument
        switch kind {
        case 0: argument = TaskTM2Fixture.tags(.add, [fixture.base.live.id])
        case 1: argument = TaskTM2Fixture.tags(.remove, [fixture.base.deleted.id])
        case 2: fixture.child.tagIDs = ""; argument = TaskTM2Fixture.tags(.clear)
        default:
            fixture.child.tagIDs = TagIDList.encode([fixture.base.live.id, fixture.base.deleted.id])
            argument = TaskTM2Fixture.tags(.remove, [fixture.base.live.id])
        }
        try fixture.context.save()
        let accepted = try fixture.accept("subtask.tags", [argument])
        #expect(try fixture.submit(accepted).state == (kind == 3 ? .saved : .noChange))
        #expect(fixture.count("save") == (kind == 3 ? 1 : 0))
        #expect(try fixture.tags().first { $0.id == fixture.base.deleted.id }?.deletedAt == TaskTitleFixture.deletion)
    }
}
