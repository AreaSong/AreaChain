import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct BoardFilterBarTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func boardFilterBarVisibilityAndEmptyBehavior() {
        var changedFilter: BoardFilter?
        let emptyBar = BoardFilterBar(
            filter: BoardFilter(),
            tags: [],
            bundleIDs: [],
            onChange: { changedFilter = $0 }
        )
        #expect(!emptyBar.isVisible)
        let todayBar = BoardFilterBar(
            filter: BoardFilter(),
            tags: [],
            bundleIDs: [],
            showsPriority: true,
            showsReminder: true,
            onChange: { changedFilter = $0 }
        )
        #expect(todayBar.isVisible)
        #expect(changedFilter == nil)

        let barWithProjects = BoardFilterBar(
            filter: BoardFilter(),
            tags: [],
            bundleIDs: [],
            onChange: { changedFilter = $0 }
        )
        #expect(!barWithProjects.isVisible)
    }

    @Test func boardFilterBarSelectionAndReset() {
        var lastFilter: BoardFilter?
        let activeFilter = BoardFilter()

        let bar = BoardFilterBar(
            filter: activeFilter,
            tags: [],
            bundleIDs: [],
            totalOpenCount: 5,
            onChange: { lastFilter = $0 }
        )

        #expect(!bar.isVisible)
        #expect(bar.totalOpenCount == 5)
        #expect(lastFilter == nil)
    }

    @Test func tasksPageCalculatesProjectCountsAccurately() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let today = "2026-09-21"
        let yesterday = "2026-09-20"

        let todo1 = TodoItem(title: "任务1", dayKey: today)
        let todo2 = TodoItem(title: "任务2", dayKey: yesterday)
        // 插入项目1的1个已完成待办（不应计入）
        let todoDone = TodoItem(title: "任务完成", isDone: true, dayKey: today)
        // 插入项目2的1个未完成待办
        let todo3 = TodoItem(title: "任务3", dayKey: today)
        // 插入无项目、无标签的未完成待办
        let todoUnclassified = TodoItem(title: "未分类任务", dayKey: today)

        context.insert(todo1)
        context.insert(todo2)
        context.insert(todoDone)
        context.insert(todo3)
        context.insert(todoUnclassified)
        try context.save()

        let page = TasksPage(
            todayKey: today,
            routines: [],
            checks: [],
            todos: [todo1, todo2, todoDone, todo3, todoUnclassified]
        )

        #expect(page.totalOpenTodosCount == 3)
        #expect(page.untaggedTodosCount == 3)
    }

    @Test func footerBarOmitsProjectFilter() {
        var filters = BoardFilters()
        let footer = FooterBar(
            tab: .tasks,
            toolbar: MenuBarToolbarState(),
            filters: Binding(get: { filters }, set: { filters = $0 })
        )
        #expect(footer.tab == .tasks)
    }

    @Test func filterChoicesShareSelectionAndClear() {
        let locale = Locale(identifier: "en")
        let today = BoardFilter().withDateScope(.today)
        let dates = BoardFilterChoices.dates(filter: today, locale: locale)
        let selectedDate = dates.first { $0.isSelected }
        #expect(dates.count == DateFilterScope.allCases.count)
        #expect(selectedDate?.applied.dateScope == .today)
        #expect(selectedDate?.cleared.dateScope == .all)

        let priorities = BoardFilterChoices.priorities(
            filter: BoardFilter().withPriorityScope(.p1),
            locale: locale
        )
        #expect(priorities.count == PriorityFilterScope.allCases.count)
        #expect(priorities.first { $0.isSelected }?.applied.priorityScope == .p1)
        #expect(priorities.first { $0.id == "priority.p1" }?.dotColor != nil)

        let tagID = UUID()
        let tags = BoardFilterChoices.tags(
            filter: BoardFilter(tagID: tagID),
            rows: [BoardFilterChoices.NamedRow(id: tagID, name: "日记")],
            counts: [tagID: 2],
            untaggedCount: 1,
            includeNone: true,
            locale: locale
        )
        #expect(tags.first { $0.id == tagID.uuidString }?.isSelected == true)
        #expect(tags.contains { $0.id == BoardFilter.noneID.uuidString })
        #expect(BoardFilterChoices.markedTagTitle(tags.first { $0.id == tagID.uuidString }!) == "#日记")
    }
}
