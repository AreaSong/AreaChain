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
        let groups = AttachmentClusters.grouped([keep, note], liveOwnerIDs: [diaryID])
        #expect(groups.map(\.kind) == [.diary])
        #expect(groups.first?.items.map(\.filename) == ["c.png"])
        #expect(AttachmentClusters.grouped([keep, note], liveOwnerIDs: []).isEmpty)
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

    @Test func liveTaskTagsSkipDiaryPresets() {
        let password = TagItem(name: "密码", sortOrder: 0)
        let idea = TagItem(name: "小巧思", sortOrder: 1)
        let journal = TagItem(name: "日记", sortOrder: 2)
        let work = TagItem(name: "工作", sortOrder: 3)
        let buried = TagItem(name: "归档", sortOrder: 4, deletedAt: Date(timeIntervalSince1970: 1))
        let tags = [password, idea, journal, work, buried]
        #expect(Catalog.liveTags(tags).map(\.name) == ["密码", "小巧思", "日记", "工作"])
        #expect(Catalog.liveTaskTags(tags).map(\.name) == ["工作"])
    }

    @Test func taskPickerTagsKeepAttachedPresets() {
        let password = TagItem(name: "密码", sortOrder: 0)
        let work = TagItem(name: "工作", sortOrder: 1)
        let attached = TagIDList.encode([password.id])
        #expect(Catalog.taskPickerTags([password, work], attachedIDs: "").map(\.name) == ["工作"])
        #expect(Catalog.taskPickerTags([password, work], attachedIDs: attached).map(\.name) == ["密码", "工作"])
    }

    @Test @MainActor func catalogChoicesTagsSkipDiaryPresets() {
        let password = TagItem(name: "密码", sortOrder: 0)
        let work = TagItem(name: "工作", sortOrder: 1)
        #expect(CatalogChoices.tags([password, work]).map(\.name) == ["工作"])
        let attached = TagIDList.encode([password.id])
        #expect(CatalogChoices.tags([password, work], attachedIDs: attached).map(\.name) == ["密码", "工作"])
    }

    @Test func matchingIncludesSubtreeTodosAndRoutines() {
        let rootID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let childID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let otherID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let root = ProjectItem(id: rootID, name: "工作", sortOrder: 0)
        let child = ProjectItem(id: childID, name: "客户端", sortOrder: 1, parentID: rootID)
        let other = ProjectItem(id: otherID, name: "生活", sortOrder: 2)
        let inRoot = TodoItem(title: "根任务", dayKey: "2026-09-09", projectID: rootID)
        let inChild = TodoItem(title: "子任务", dayKey: "2026-09-09", projectID: childID)
        let elsewhere = TodoItem(title: "其它", dayKey: "2026-09-09", projectID: otherID)
        let buried = TodoItem(title: "已删", dayKey: "2026-09-09", deletedAt: Date(timeIntervalSince1970: 1), projectID: rootID)
        let habit = DailyRoutine(title: "习惯", sortOrder: 0, projectID: childID)
        let projects = [root, child, other]
        let todos = Catalog.matchingTodos([inRoot, inChild, elsewhere, buried], project: root, tag: nil, projects: projects)
        #expect(Set(todos.map(\.title)) == ["根任务", "子任务"])
        #expect(Catalog.matchingRoutines([habit], project: root, tag: nil, projects: projects).map(\.title) == ["习惯"])
        #expect(Catalog.matchingRoutines([habit], project: other, tag: nil, projects: projects).isEmpty)
    }

    @Test func matchingRoutinesByTag() {
        let tagID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let tag = TagItem(id: tagID, name: "跟进", sortOrder: 0)
        let hit = DailyRoutine(title: "带标", sortOrder: 0, tagIDs: tagID.uuidString)
        let miss = DailyRoutine(title: "无标", sortOrder: 1)
        #expect(Catalog.matchingRoutines([hit, miss], project: nil, tag: tag, projects: []).map(\.title) == ["带标"])
    }

    @Test func reindexRoutinesMovesSortOrder() {
        let first = DailyRoutine(title: "甲", sortOrder: 0)
        let second = DailyRoutine(title: "乙", sortOrder: 1)
        let third = DailyRoutine(title: "丙", sortOrder: 2)
        Catalog.reindexRoutines([first, second, third], from: IndexSet(integer: 0), to: 3)
        let ordered = [first, second, third].sorted { $0.sortOrder < $1.sortOrder }
        #expect(ordered.map(\.title) == ["乙", "丙", "甲"])
    }

    @Test func openCountIncludesDueHabits() {
        let projectID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let project = ProjectItem(id: projectID, name: "工作", sortOrder: 0)
        let openTodo = TodoItem(title: "未完成", dayKey: "2026-09-09", projectID: projectID)
        let doneTodo = TodoItem(title: "已完成", isDone: true, dayKey: "2026-09-09", projectID: projectID)
        let due = DailyRoutine(title: "该打", sortOrder: 0, createdDayKey: "2026-09-01", projectID: projectID)
        let paused = DailyRoutine(
            title: "停用",
            sortOrder: 1,
            isEnabled: false,
            createdDayKey: "2026-09-01",
            projectID: projectID
        )
        #expect(
            Catalog.openCount(
                todos: [openTodo, doneTodo],
                routines: [due, paused],
                checks: [],
                project: project,
                tag: nil,
                projects: [project],
                dayKey: "2026-09-09"
            ) == 2
        )
    }
}
