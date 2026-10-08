import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct SubtaskLegacyMutationTests {
    @Test(arguments: ["新标题 !p1 @18:00 #恢复 #New", "#Work", "  带空格   标题  ", "多行\n标题 #恢复"])
    func oldTextEntryPreservesOriginalTagAlgorithm(raw: String) throws {
        let fixture = try SubtaskCommandFixture()
        let parent = fixture.base.todo.snapshot
        let before = fixture.child.snapshot
        var saved = false
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.boundary) {
            saved = DayBoardMutations.editSubtask(fixture.child, title: raw)
        }
        #expect(saved)
        let child = try fixture.storedChild()
        #expect(child.title == TagSyntax.title(from: raw, includesDiaryTags: false))
        #expect(child.isDone == before?.isDone && child.sortOrder == before?.sortOrder && child.createdAt == before?.createdAt)
        #expect(TagIDList.contains(child.tagIDs, fixture.base.live.id))
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        try fixture.assertParentUnchanged(parent)
    }

    @Test func oldAddTitleCompletionAndTagEntriesKeepParentAndSaveSemantics() throws {
        let fixture = try SubtaskCommandFixture()
        let before = fixture.base.todo.snapshot
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.boundary) {
            #expect(DayBoardMutations.addSubtask(to: fixture.base.todo, title: "#恢复 !p1 @18:00", context: fixture.context))
        }
        let added = try #require(fixture.context.fetch(FetchDescriptor<SubtaskItem>()).first { $0.sortOrder == 10 })
        #expect(added.title == "!p1 @18:00" && !added.isDone && added.todo === fixture.base.todo)
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.boundary) {
            try SwiftDataTaskRepository(context: fixture.context).toggleSubtask(id: added.id)
            #expect(DayBoardMutations.toggleSubtaskTag(added, tagID: fixture.base.live.id))
            #expect(DayBoardMutations.editSubtask(added, title: "不再写标签"))
        }
        #expect(added.isDone && TagIDList.parse(added.tagIDs) == [fixture.base.deleted.id, fixture.base.live.id])
        #expect(fixture.count("save") == 2 && fixture.count("ui") == 2)
        #expect(!DayBoardMutations.editSubtask(added, title: "   "))
        #expect(!DayBoardMutations.addSubtask(to: fixture.base.todo, title: "", context: fixture.context))
        try fixture.assertParentUnchanged(before)
    }

    @Test func fixedCreationCollisionIncludesTombstoneAndLegacyDefaultStillCreatesFreshID() throws {
        let fixture = try SubtaskCommandFixture()
        let repo = SwiftDataTaskRepository(context: fixture.context)
        #expect(throws: (any Error).self) { try repo.updateSubtask(id: fixture.child.id, update: .title(" ", tagIDs: "")) }
        #expect(fixture.child.title == "子标题" && !fixture.context.hasChanges)
        #expect(throws: (any Error).self) {
            try repo.addSubtask(.init(parentID: fixture.base.todo.id, title: "collision", creationID: fixture.tombstone.id))
        }
        var first: UUID?
        var second: UUID?
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.boundary) {
            first = try repo.addSubtask(to: fixture.base.todo.id, title: "same").id
            second = try repo.addSubtask(to: fixture.base.todo.id, title: "same").id
        }
        #expect(first != second && first != fixture.tombstone.id)
    }
}
