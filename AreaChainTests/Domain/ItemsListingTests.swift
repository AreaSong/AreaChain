import Foundation
import Testing
@testable import AreaChain

struct ItemsListingTests {
    private let today = "2026-09-07"
    private let tomorrow = "2026-09-08"
    private let tag = UUID()

    private func todo(
        _ title: String,
        day: String,
        done: Bool = false,
        tags: String = "",
        important: Bool = false,
        bundle: String = "",
        deleted: Bool = false,
        subtasks: [SubtaskSnapshot] = [],
        createdAt: Date = Date(timeIntervalSince1970: 1)
    ) -> TodoSnapshot {
        TodoSnapshot(
            id: UUID(),
            title: title,
            isDone: done,
            dayKey: day,
            createdAt: createdAt,
            deletedAt: deleted ? Date() : nil,
            tagIDs: tags,
            isImportant: important,
            sourceBundleID: bundle,
            subtasks: subtasks
        )
    }

    private func routine(
        _ title: String,
        enabled: Bool = true,
        order: Int = 0,
        tags: String = "",
        deleted: Bool = false
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: UUID(),
            title: title,
            sortOrder: order,
            isEnabled: enabled,
            createdDayKey: "2026-09-01",
            deletedAt: deleted ? Date() : nil,
            tagIDs: tags
        )
    }

    @Test func allItemsKeepOpenDoneEnabledAndDisabled() {
        let open = todo("未完成", day: "2026-09-08")
        let done = todo("已完成", day: today, done: true, createdAt: Date(timeIntervalSince1970: 2))
        let deleted = todo("删除", day: today, deleted: true)
        let child = SubtaskSnapshot(id: UUID(), todoId: open.id, title: "子任务", isDone: false)
        let parent = todo("父", day: today, subtasks: [child])
        let on = routine("启用", order: 1)
        let off = routine("停用", enabled: false, order: 0)
        let gone = routine("删除习惯", deleted: true)
        let query = ItemsListingQuery(todayKey: today)
        let listed = ItemsListing.todos([done, open, deleted, parent], query: query)
        #expect(listed.map(\.todo.title) == ["父", "未完成", "已完成"])
        #expect(listed.first { $0.todo.title == "父" }?.subtasks.map(\.title) == ["子任务"])
        let habits = ItemsListing.routines([off, on, gone], checks: [], query: query)
        #expect(habits.map(\.title) == ["启用", "停用"])
    }

    @Test func subtaskTagShowsParentWithoutPromotingTheChild() {
        let child = SubtaskSnapshot(id: UUID(), todoId: UUID(), title: "命中", isDone: false, tagIDs: tag.uuidString)
        let parent = todo("父事项", day: today, subtasks: [child])
        let other = SubtaskSnapshot(id: UUID(), todoId: parent.id, title: "其他", isDone: false)
        var withBoth = parent
        withBoth.subtasks = [child, other]
        let query = ItemsListingQuery(filter: BoardFilter().withTag(tag), todayKey: today)
        let listed = ItemsListing.todos([withBoth], query: query)
        #expect(listed.map(\.todo.title) == ["父事项"])
        #expect(listed.first?.subtasks.map(\.title) == ["命中"])
        #expect(listed.allSatisfy { $0.id == withBoth.id })
    }

    @Test func filtersCoverTagPriorityBundleDateKindAndStatus() {
        let tagged = todo("标签", day: "2026-09-01", tags: tag.uuidString, important: true, bundle: "app.one")
        let plain = todo("无标签", day: tomorrow, bundle: "app.two")
        let done = todo("完成", day: today, done: true)
        let query = ItemsListingQuery(
            kind: .oneOff,
            todoStatus: .open,
            filter: BoardFilter().withTag(tag).withBundle("app.one").withPriorityScope(.p2).withDateScope(.overdue),
            todayKey: today
        )
        #expect(ItemsListing.todos([tagged, plain, done], query: query).map(\.todo.title) == ["标签"])
        let cleared = query.cleared()
        #expect(!cleared.isNarrowed)
        #expect(ItemsListing.todos([tagged, plain, done], query: cleared).count == 3)
        let none = ItemsListingQuery(filter: BoardFilter().withTag(BoardFilter.noneID), todayKey: today)
        #expect(ItemsListing.todos([tagged, plain], query: none).map(\.todo.title) == ["无标签"])
        let upcoming = ItemsListingQuery(filter: BoardFilter().withDateScope(.upcoming), todayKey: today)
        #expect(ItemsListing.todos([tagged, plain], query: upcoming).map(\.todo.title) == ["无标签"])
        let habits = [
            routine("开", tags: tag.uuidString),
            routine("关", enabled: false, tags: tag.uuidString)
        ]
        let enabled = ItemsListingQuery(kind: .recurring, routineStatus: .enabled, filter: BoardFilter().withTag(tag), todayKey: today)
        #expect(ItemsListing.routines(habits, checks: [], query: enabled).map(\.title) == ["开"])
        let dated = ItemsListingQuery(filter: BoardFilter().withDateScope(.today), todayKey: today)
        #expect(ItemsListing.routines(habits, checks: [], query: dated).map(\.title) == ["开"])
        #expect(ItemsListing.routines([habits[1]], checks: [], query: dated).isEmpty)
    }

    @Test func routineSortKeepsUserOrderAheadOfStreak() {
        let later = routine("后", order: 2)
        let earlier = routine("先", enabled: false, order: 0)
        let middle = routine("中", order: 1)
        #expect(ItemsListing.sortedRoutines([later, earlier, middle]).map(\.title) == ["中", "后", "先"])
    }
}
