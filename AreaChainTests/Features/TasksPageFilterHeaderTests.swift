import Foundation
import Testing
@testable import AreaChain

@MainActor
struct TasksPageFilterHeaderTests {
    @Test func workspaceTodayShowsFilterBarWithSharedEmptyFilter() {
        #expect(
            TasksPage.showsFilterBar(embedded: true, hasExternalFilter: true, filterIsActive: false)
        )
        #expect(
            !TasksPage.showsFilterBar(embedded: false, hasExternalFilter: true, filterIsActive: true)
        )
        #expect(
            TasksPage.showsFilterBar(embedded: false, hasExternalFilter: false, filterIsActive: true)
        )
        #expect(
            !TasksPage.showsFilterBar(embedded: false, hasExternalFilter: false, filterIsActive: false)
        )
    }

    @Test func workspaceTodayKeepsTagChoicesWhenSharingFilter() {
        let tag = TagItem(name: "工作", sortOrder: 0)
        #expect(TasksPage.filterTagChoices(tags: [tag], embedded: true).map(\.name) == ["工作"])
        #expect(TasksPage.filterTagChoices(tags: [tag], embedded: false).isEmpty)
    }

    @Test func sharedDateFilterAlsoAppliesToLeftoverChipsAndTodayIDs() throws {
        let yesterday = TodoItem(title: "昨天", dayKey: "2026-09-10")
        let today = TodoItem(title: "今天", dayKey: "2026-09-11")
        let future = TodoItem(title: "即将", dayKey: "2026-09-12")
        let yesterdayDate = try #require(DayKey.date(from: "2026-09-10"))
        let yesterdayWeekday = Calendar.current.component(.weekday, from: yesterdayDate)
        let habit = DailyRoutine(
            title: "昨天习惯",
            sortOrder: 0,
            createdDayKey: "2026-09-01",
            weekdayMask: 1 << (yesterdayWeekday - 1)
        )
        let todos = [yesterday, today, future]
        let overdue = page(todos: todos, routines: [habit], scope: .overdue)
        #expect(overdue.yesterdayItems.map(\.id) == [habit.id, yesterday.id])
        #expect(overdue.upcomingModels.isEmpty)
        #expect(overdue.todayVisibleIDs.isEmpty)

        let todayOnly = page(todos: todos, routines: [habit], scope: .today)
        #expect(todayOnly.yesterdayItems.isEmpty)
        #expect(todayOnly.upcomingModels.isEmpty)
        #expect(todayOnly.todayVisibleIDs == [today.id])

        let upcoming = page(todos: todos, routines: [habit], scope: .upcoming)
        #expect(upcoming.yesterdayItems.isEmpty)
        #expect(upcoming.upcomingModels.map(\.id) == [future.id])
        #expect(upcoming.todayVisibleIDs.isEmpty)
    }

    private func page(
        todos: [TodoItem],
        routines: [DailyRoutine],
        scope: DateFilterScope
    ) -> TasksPage {
        TasksPage(
            todayKey: "2026-09-11",
            routines: routines,
            checks: [],
            todos: todos,
            config: TasksPageConfig(externalFilter: .constant(BoardFilter().withDateScope(scope)))
        )
    }
}
