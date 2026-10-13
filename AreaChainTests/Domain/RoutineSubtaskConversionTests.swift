import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct RoutineSubtaskConversionTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func todoToRoutineConversionPreservesSubtasks() throws {
        let store = try container()
        defer { withExtendedLifetime(store) {} }
        let context = store.mainContext

        let todo = TodoItem(title: "晨间流程", dayKey: "2026-10-13", notes: "保持专注")
        context.insert(todo)
        let sub1 = SubtaskItem(title: "喝水", sortOrder: 0, tagIDs: "tag-1", todo: todo)
        let sub2 = SubtaskItem(title: "拉伸", sortOrder: 1, tagIDs: "tag-2", todo: todo)
        context.insert(sub1)
        context.insert(sub2)
        try context.save()

        let routineID = DayBoardMutations.convertTodoToRoutine(todo)
        #expect(routineID != nil)
        guard let id = routineID else { return }

        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let created = routines.first { $0.id == id }
        #expect(created != nil)
        #expect(created?.notes == "保持专注")
        #expect(created?.subtaskTemplates.count == 2)
        #expect(created?.subtaskTemplates.map(\.title) == ["喝水", "拉伸"])
        #expect(created?.subtaskTemplates.first?.tagIDs == "tag-1")
        #expect(todo.deletedAt != nil)
    }

    @Test func routineToTodoConversionReconstructsSubtasks() throws {
        let store = try container()
        defer { withExtendedLifetime(store) {} }
        let context = store.mainContext

        let routine = DailyRoutine(title: "阅读习惯", sortOrder: 0, notes: "每日一章")
        routine.subtaskTemplates = [
            RoutineSubtaskTemplate(id: UUID(), title: "准备书籍", sortOrder: 0, tagIDs: "book"),
            RoutineSubtaskTemplate(id: UUID(), title: "记录笔记", sortOrder: 1, tagIDs: "note")
        ]
        context.insert(routine)
        try context.save()

        let todoID = DayBoardMutations.convertRoutineToTodo(routine)
        #expect(todoID != nil)
        guard let id = todoID else { return }

        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let created = todos.first { $0.id == id }
        #expect(created != nil)
        #expect(created?.notes == "每日一章")
        let liveSubtasks = created?.subtasks.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder } ?? []
        #expect(liveSubtasks.count == 2)
        #expect(liveSubtasks.map(\.title) == ["准备书籍", "记录笔记"])
        #expect(liveSubtasks.first?.tagIDs == "book")
        #expect(routine.deletedAt != nil)
    }

    @Test func routineSubtaskToggleAndAutoCompletionLinkage() throws {
        let store = try container()
        defer { withExtendedLifetime(store) {} }
        let context = store.mainContext

        let sub1ID = UUID()
        let sub2ID = UUID()
        let routine = DailyRoutine(title: "晨跑", sortOrder: 0)
        routine.subtaskTemplates = [
            RoutineSubtaskTemplate(id: sub1ID, title: "热身", sortOrder: 0),
            RoutineSubtaskTemplate(id: sub2ID, title: "慢跑3公里", sortOrder: 1)
        ]
        context.insert(routine)
        try context.save()

        let dayKey = "2026-10-13"

        // 勾选第一个子任务
        let ok1 = DayBoardMutations.toggleRoutineSubtask(routine, subtaskID: sub1ID, on: dayKey, context: context)
        #expect(ok1)
        var checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        var check = checks.first { $0.routine?.id == routine.id && $0.dayKey == dayKey }
        #expect(check != nil)
        #expect(check?.completedSubtaskIDSet == [sub1ID])
        #expect(check?.isDone == false)

        // 勾选第二个子任务 -> 全部完成，联动父事项打卡成功
        let ok2 = DayBoardMutations.toggleRoutineSubtask(routine, subtaskID: sub2ID, on: dayKey, context: context)
        #expect(ok2)
        checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        check = checks.first { $0.routine?.id == routine.id && $0.dayKey == dayKey }
        #expect(check?.completedSubtaskIDSet == [sub1ID, sub2ID])
        #expect(check?.isDone == true)

        // 取消勾选第一个子任务 -> 父事项重置为未完成
        let ok3 = DayBoardMutations.toggleRoutineSubtask(routine, subtaskID: sub1ID, on: dayKey, context: context)
        #expect(ok3)
        checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        check = checks.first { $0.routine?.id == routine.id && $0.dayKey == dayKey }
        #expect(check?.completedSubtaskIDSet == [sub2ID])
        #expect(check?.isDone == false)
    }

    @Test func parentRoutineCheckMarksAllSubtasksDoneAndClearsOnUncheck() throws {
        let store = try container()
        defer { withExtendedLifetime(store) {} }
        let context = store.mainContext

        let sub1ID = UUID()
        let sub2ID = UUID()
        let routine = DailyRoutine(title: "早睡", sortOrder: 0)
        routine.subtaskTemplates = [
            RoutineSubtaskTemplate(id: sub1ID, title: "泡脚", sortOrder: 0),
            RoutineSubtaskTemplate(id: sub2ID, title: "放下手机", sortOrder: 1)
        ]
        context.insert(routine)
        try context.save()

        let dayKey = "2026-10-13"

        // 直接勾选父事项打卡
        let ok = DayBoardMutations.toggleRoutine(routine, on: dayKey, context: context)
        #expect(ok)
        var checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        var check = checks.first { $0.routine?.id == routine.id && $0.dayKey == dayKey }
        #expect(check != nil)
        #expect(check?.isDone == true)
        #expect(check?.completedSubtaskIDSet == [sub1ID, sub2ID])

        // 再次勾选父事项取消打卡
        let okUncheck = DayBoardMutations.toggleRoutine(routine, on: dayKey, context: context)
        #expect(okUncheck)
        checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        check = checks.first { $0.routine?.id == routine.id && $0.dayKey == dayKey }
        #expect(check?.isDone == false)
        #expect(check?.completedSubtaskIDSet.isEmpty == true)
    }
}
