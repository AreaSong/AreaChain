import Foundation
import Testing
@testable import AreaChain

struct CatalogTests {
    @Test func liveTagsStayFlatAndSorted() {
        let later = TagItem(name: "后", sortOrder: 2)
        let first = TagItem(name: "先", sortOrder: 0)
        let buried = TagItem(name: "删", sortOrder: 1, deletedAt: Date(timeIntervalSince1970: 1))
        #expect(Catalog.liveTags([later, buried, first]).map(\.name) == ["先", "后"])
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

    @Test func unlinkTagClearsSubtasksToo() {
        let tagID = UUID()
        let todo = TodoItem(title: "任务", dayKey: "2026-09-08")
        let subtask = SubtaskItem(title: "子", tagIDs: tagID.uuidString, todo: todo)
        todo.subtasks = [subtask]
        Catalog.unlinkTag(tagID, todos: [todo], routines: [], diaries: [])
        #expect(!TagIDList.contains(subtask.tagIDs, tagID))
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

    @Test func matchingTodosAndRoutinesUseTheSameTag() {
        let tag = TagItem(name: "工作", sortOrder: 0)
        let hit = TodoItem(title: "根任务", dayKey: "2026-09-09", tagIDs: tag.id.uuidString)
        let miss = TodoItem(title: "其它", dayKey: "2026-09-09")
        let buried = TodoItem(title: "已删", dayKey: "2026-09-09", deletedAt: Date(timeIntervalSince1970: 1), tagIDs: tag.id.uuidString)
        let habit = DailyRoutine(title: "习惯", sortOrder: 0, tagIDs: tag.id.uuidString)
        #expect(Catalog.matchingTodos([hit, miss, buried], tag: tag).map(\.title) == ["根任务"])
        #expect(Catalog.matchingRoutines([habit], tag: tag).map(\.title) == ["习惯"])
        #expect(Catalog.matchingTodos([hit], tag: nil).isEmpty)
    }

    @Test func matchingRoutinesByTag() {
        let tagID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let tag = TagItem(id: tagID, name: "跟进", sortOrder: 0)
        let hit = DailyRoutine(title: "带标", sortOrder: 0, tagIDs: tagID.uuidString)
        let miss = DailyRoutine(title: "无标", sortOrder: 1)
        #expect(Catalog.matchingRoutines([hit, miss], tag: tag).map(\.title) == ["带标"])
    }

    @Test func reindexRoutinesMovesSortOrder() {
        let first = DailyRoutine(title: "甲", sortOrder: 0)
        let second = DailyRoutine(title: "乙", sortOrder: 1)
        let third = DailyRoutine(title: "丙", sortOrder: 2)
        Catalog.reindexRoutines([first, second, third], from: IndexSet(integer: 0), to: 3)
        let ordered = [first, second, third].sorted { $0.sortOrder < $1.sortOrder }
        #expect(ordered.map(\.title) == ["乙", "丙", "甲"])
    }

    @Test func listedRoutinesIncludeOffDayAndPausedWhileOpenCountKeepsThem() {
        let tag = TagItem(name: "工作", sortOrder: 0)
        let encoded = tag.id.uuidString
        let openTodo = TodoItem(title: "未完成", dayKey: "2026-09-09", tagIDs: encoded)
        let doneTodo = TodoItem(title: "已完成", isDone: true, dayKey: "2026-09-09", tagIDs: encoded)
        let due = DailyRoutine(title: "该打", sortOrder: 0, createdDayKey: "2026-09-01", tagIDs: encoded)
        let paused = DailyRoutine(
            title: "停用", sortOrder: 1, isEnabled: false, createdDayKey: "2026-09-01", tagIDs: encoded
        )
        let weekend = DailyRoutine(
            title: "周末", sortOrder: 2, createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.all ^ WeekdayMask.workdays, tagIDs: encoded
        )
        let doneHabit = DailyRoutine(
            title: "打完", sortOrder: 3, createdDayKey: "2026-09-01", tagIDs: encoded
        )
        let check = RoutineCheck(dayKey: "2026-09-09", isDone: true, routine: doneHabit)
        let listed = Catalog.matchingListedRoutines(
            [due, paused, weekend, doneHabit], checks: [check], tag: tag, dayKey: "2026-09-09", open: true
        )
        #expect(listed.map(\.title) == ["该打", "停用", "周末"])
        #expect(
            Catalog.matchingListedRoutines(
                [due, paused, weekend, doneHabit], checks: [check], tag: tag, dayKey: "2026-09-09", open: false
            ).map(\.title) == ["打完"]
        )
        #expect(
            Catalog.matchingOpenRoutines(
                [due, paused, weekend, doneHabit], checks: [check], tag: tag, dayKey: "2026-09-09"
            ).map(\.title) == ["该打"]
        )
        #expect(
            Catalog.openCount(
                todos: [openTodo, doneTodo],
                routines: [due, paused, weekend, doneHabit],
                checks: [check],
                tag: tag,
                dayKey: "2026-09-09"
            ) == 4
        )
    }
}
