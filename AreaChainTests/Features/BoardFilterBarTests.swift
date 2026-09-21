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
            projects: [],
            tags: [],
            bundleIDs: [],
            onChange: { changedFilter = $0 }
        )
        #expect(!emptyBar.isVisible)
        #expect(changedFilter == nil)

        let projectID = UUID()
        let barWithProjects = BoardFilterBar(
            filter: BoardFilter(),
            projects: [CatalogChoice(id: projectID, name: "测试项目")],
            tags: [],
            bundleIDs: [],
            onChange: { changedFilter = $0 }
        )
        #expect(barWithProjects.isVisible)
    }

    @Test func boardFilterBarSelectionAndReset() {
        var lastFilter: BoardFilter?
        let projectID = UUID()
        let activeFilter = BoardFilter(projectID: projectID)

        let bar = BoardFilterBar(
            filter: activeFilter,
            projects: [CatalogChoice(id: projectID, name: "开发")],
            tags: [],
            bundleIDs: [],
            projectCounts: [projectID: 3],
            totalOpenCount: 5,
            onChange: { lastFilter = $0 }
        )

        #expect(bar.isVisible)
        #expect(bar.projectCounts[projectID] == 3)
        #expect(bar.totalOpenCount == 5)
        #expect(lastFilter == nil)
    }

    @Test func tasksPageCalculatesProjectCountsAccurately() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let today = "2026-09-21"
        let yesterday = "2026-09-20"

        let project1 = ProjectItem(name: "工程A", sortOrder: 0)
        let project2 = ProjectItem(name: "工程B", sortOrder: 1)
        context.insert(project1)
        context.insert(project2)
        try context.save()

        // 插入项目1的2个未完成待办（1个今天，1个昨天）
        let todo1 = TodoItem(title: "任务1", dayKey: today, projectID: project1.id)
        let todo2 = TodoItem(title: "任务2", dayKey: yesterday, projectID: project1.id)
        // 插入项目1的1个已完成待办（不应计入）
        let todoDone = TodoItem(title: "任务完成", isDone: true, dayKey: today, projectID: project1.id)
        // 插入项目2的1个未完成待办
        let todo3 = TodoItem(title: "任务3", dayKey: today, projectID: project2.id)

        context.insert(todo1)
        context.insert(todo2)
        context.insert(todoDone)
        context.insert(todo3)
        try context.save()

        let page = TasksPage(
            todayKey: today,
            routines: [],
            checks: [],
            todos: [todo1, todo2, todoDone, todo3]
        )

        let counts = page.projectCounts
        #expect(counts[project1.id] == 2)
        #expect(counts[project2.id] == 1)
        #expect(page.totalOpenTodosCount == 3)
    }
}
