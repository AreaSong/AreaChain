import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct SubtaskModelTests {
    private func makeContainer() throws -> (ModelContainer, ModelContext) {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, ModelContext(container))
    }

    @Test func addSubtaskAndSortOrder() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "主任务", dayKey: "2026-09-08")
        context.insert(todo)
        try context.save()

        #expect(DayBoardMutations.addSubtask(to: todo, title: "子任务 1", context: context))
        #expect(DayBoardMutations.addSubtask(to: todo, title: "子任务 2", context: context))
        #expect(!DayBoardMutations.addSubtask(to: todo, title: "   ", context: context))

        let activeSubs = todo.subtasks.filter { $0.deletedAt == nil }.sorted(by: { $0.sortOrder < $1.sortOrder })
        #expect(activeSubs.count == 2)
        #expect(activeSubs[0].title == "子任务 1")
        #expect(activeSubs[0].sortOrder == 0)
        #expect(activeSubs[0].isDone == false)
        #expect(activeSubs[1].title == "子任务 2")
        #expect(activeSubs[1].sortOrder == 1)

        let snapshot = todo.snapshot
        #expect(snapshot.subtasks.count == 2)
        #expect(snapshot.subtasks.map(\.title) == ["子任务 1", "子任务 2"])
    }

    @Test func toggleAndEditSubtask() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "主任务", dayKey: "2026-09-08")
        context.insert(todo)
        _ = DayBoardMutations.addSubtask(to: todo, title: "子任务", context: context)
        let subtask = try #require(todo.subtasks.first)

        #expect(!subtask.isDone)
        DayBoardMutations.toggleSubtask(subtask)
        #expect(subtask.isDone)
        DayBoardMutations.toggleSubtask(subtask)
        #expect(!subtask.isDone)

        DayBoardMutations.editSubtask(subtask, title: "修改后的子任务")
        #expect(subtask.title == "修改后的子任务")
        DayBoardMutations.editSubtask(subtask, title: "   ")
        #expect(subtask.title == "修改后的子任务")
    }

    @Test func deleteAndReorderSubtasks() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "主任务", dayKey: "2026-09-08")
        context.insert(todo)
        _ = DayBoardMutations.addSubtask(to: todo, title: "A", context: context)
        _ = DayBoardMutations.addSubtask(to: todo, title: "B", context: context)
        _ = DayBoardMutations.addSubtask(to: todo, title: "C", context: context)

        let itemB = try #require(todo.subtasks.first(where: { $0.title == "B" }))
        DayBoardMutations.deleteSubtask(itemB)
        #expect(itemB.deletedAt != nil)

        var snapshot = todo.snapshot
        #expect(snapshot.subtasks.map(\.title) == ["A", "C"])

        let itemA = try #require(todo.subtasks.first(where: { $0.title == "A" }))
        let itemC = try #require(todo.subtasks.first(where: { $0.title == "C" }))
        DayBoardMutations.reorderSubtasks(for: todo, orderedIDs: [itemC.id, itemA.id])

        snapshot = todo.snapshot
        #expect(snapshot.subtasks.map(\.title) == ["C", "A"])
    }

    @Test func oneWayCascadeCompletion() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "主任务", dayKey: "2026-09-08")
        context.insert(todo)
        _ = DayBoardMutations.addSubtask(to: todo, title: "子任务 1", context: context)
        _ = DayBoardMutations.addSubtask(to: todo, title: "子任务 2", context: context)
        _ = DayBoardMutations.addSubtask(to: todo, title: "已删除子任务", context: context)

        let deletedSub = try #require(todo.subtasks.first(where: { $0.title == "已删除子任务" }))
        DayBoardMutations.deleteSubtask(deletedSub)

        let sub1 = try #require(todo.subtasks.first(where: { $0.title == "子任务 1" }))
        let sub2 = try #require(todo.subtasks.first(where: { $0.title == "子任务 2" }))

        #expect(!todo.isDone)
        #expect(!sub1.isDone)
        #expect(!sub2.isDone)

        DayBoardMutations.toggleTodo(todo)
        #expect(todo.isDone)
        #expect(sub1.isDone)
        #expect(sub2.isDone)
        #expect(!deletedSub.isDone)

        DayBoardMutations.toggleTodo(todo)
        #expect(!todo.isDone)
        #expect(sub1.isDone)
        #expect(sub2.isDone)
    }

    @Test func updateNotesForTodoAndRoutine() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "任务", dayKey: "2026-09-08", notes: "初始备注")
        let routine = DailyRoutine(title: "习惯", sortOrder: 0, createdDayKey: "2026-09-08", notes: "习惯备注")
        context.insert(todo)
        context.insert(routine)

        #expect(todo.notes == "初始备注")
        #expect(routine.notes == "习惯备注")

        DayBoardMutations.updateNotes(for: todo, notes: "更新后的待办备注\nhttps://example.com")
        DayBoardMutations.updateNotes(for: routine, notes: "更新后的习惯备注")

        #expect(todo.notes == "更新后的待办备注\nhttps://example.com")
        #expect(routine.notes == "更新后的习惯备注")
    }
}
