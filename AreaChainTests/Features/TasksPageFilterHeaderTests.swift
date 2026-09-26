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
}
