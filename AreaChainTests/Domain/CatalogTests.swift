import Foundation
import Testing
@testable import AreaChain

struct CatalogTests {
    @Test func subtreeIncludesDescendantsAndCycleGuard() {
        let rootID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let childID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let leafID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let otherID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        let root = ProjectItem(id: rootID, name: "工作", sortOrder: 0)
        let child = ProjectItem(id: childID, name: "客户端", sortOrder: 1, parentID: rootID)
        let leaf = ProjectItem(id: leafID, name: "角标", sortOrder: 2, parentID: childID)
        let other = ProjectItem(id: otherID, name: "生活", sortOrder: 3)
        let items = [root, child, leaf, other]
        #expect(ProjectTree.subtreeIDs(root: rootID, in: items) == [rootID, childID, leafID])
        #expect(ProjectTree.wouldCycle(moving: rootID, to: leafID, in: items))
        #expect(ProjectTree.wouldCycle(moving: childID, to: childID, in: items))
        #expect(!ProjectTree.wouldCycle(moving: childID, to: otherID, in: items))
        #expect(!ProjectTree.wouldCycle(moving: childID, to: nil, in: items))
        let rows = ProjectTree.outline(items)
        #expect(rows.map(\.id) == [rootID, childID, leafID, otherID])
        #expect(rows.map(\.depth) == [0, 1, 2, 0])
        #expect(ProjectTree.pathLabel(leafID, in: items) == "工作 / 客户端 / 角标")
        #expect(ProjectTree.allowedParents(for: rootID, in: items).map(\.id) == [otherID])
    }

    @Test func attachmentClustersGroupByOwnerAndSkipDeleted() {
        let todoID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let diaryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let keep = AttachmentItem(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: todoID,
            filename: "a.png",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let extra = AttachmentItem(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: todoID,
            filename: "b.png",
            createdAt: Date(timeIntervalSince1970: 3)
        )
        let note = AttachmentItem(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            ownerKind: AttachmentOwner.diary.rawValue,
            ownerID: diaryID,
            filename: "c.png",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let gone = AttachmentItem(
            id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
            ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: todoID,
            filename: "gone.png",
            createdAt: Date(timeIntervalSince1970: 4),
            deletedAt: Date(timeIntervalSince1970: 5)
        )
        let groups = AttachmentClusters.grouped([keep, extra, note, gone])
        #expect(groups.map(\.kind) == [.todo, .diary])
        #expect(groups.first?.items.map(\.filename) == ["b.png", "a.png"])
        #expect(groups.last?.items.map(\.filename) == ["c.png"])
    }

    @Test func attachmentClustersHideOwnersInTrash() {
        let todoID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let diaryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let keep = AttachmentItem(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: todoID,
            filename: "a.png",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let note = AttachmentItem(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            ownerKind: AttachmentOwner.diary.rawValue,
            ownerID: diaryID,
            filename: "c.png",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let groups = AttachmentClusters.grouped([keep, note], hiddenOwnerIDs: [todoID])
        #expect(groups.map(\.kind) == [.diary])
        #expect(groups.first?.items.map(\.filename) == ["c.png"])
    }

    @Test func unlinkProjectClearsRefsAndChildParent() {
        let parentID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let childID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let parent = ProjectItem(id: parentID, name: "父", sortOrder: 0)
        let child = ProjectItem(id: childID, name: "子", sortOrder: 1, parentID: parentID)
        let todo = TodoItem(title: "任务", dayKey: "2026-09-08", projectID: parentID)
        let routine = DailyRoutine(title: "习惯", sortOrder: 0, projectID: parentID)
        Catalog.unlinkProject(parentID, todos: [todo], routines: [routine], projects: [parent, child])
        #expect(todo.projectID == nil)
        #expect(routine.projectID == nil)
        #expect(child.parentID == nil)
    }

    @Test func unlinkTagClearsTodosRoutinesAndDiaries() {
        let tagID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let encoded = tagID.uuidString
        let todo = TodoItem(title: "任务", dayKey: "2026-09-08", tagIDs: encoded)
        let routine = DailyRoutine(title: "习惯", sortOrder: 0, tagIDs: encoded)
        let diary = DiaryEntry(text: "手记", dayKey: "2026-09-08", tagIDs: encoded)
        Catalog.unlinkTag(tagID, todos: [todo], routines: [routine], diaries: [diary])
        #expect(!TagIDList.contains(todo.tagIDs, tagID))
        #expect(!TagIDList.contains(routine.tagIDs, tagID))
        #expect(!TagIDList.contains(diary.tagIDs, tagID))
    }
}
