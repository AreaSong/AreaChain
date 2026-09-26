import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct BatchMutationsTests {
    private func makeContainer() throws -> (ModelContainer, ModelContext) {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, ModelContext(container))
    }

    @Test func batchMoveTodos() throws {
        let (_, context) = try makeContainer()
        let t1 = TodoItem(title: "任务 1", dayKey: "2026-09-08")
        let t2 = TodoItem(title: "任务 2", dayKey: "2026-09-08")
        let t3 = TodoItem(title: "任务 3", dayKey: "2026-09-08")
        context.insert(t1)
        context.insert(t2)
        context.insert(t3)

        DayBoardMutations.batchMoveTodos([t1.id, t2.id], to: "2026-09-09", todos: [t1, t2, t3])

        #expect(t1.dayKey == "2026-09-09")
        #expect(t2.dayKey == "2026-09-09")
        #expect(t3.dayKey == "2026-09-08")
    }

    @Test func batchToggleDoneAndSubtasksCascade() throws {
        let (_, context) = try makeContainer()
        let t1 = TodoItem(title: "任务 1", dayKey: "2026-09-08")
        let t2 = TodoItem(title: "任务 2", dayKey: "2026-09-08")
        context.insert(t1)
        context.insert(t2)

        _ = DayBoardMutations.addSubtask(to: t1, title: "子任务 1-1", context: context)
        let sub1 = try #require(t1.subtasks.first)

        #expect(!t1.isDone)
        #expect(!sub1.isDone)

        // Batch mark as done
        DayBoardMutations.batchToggleDone([t1.id, t2.id], markDone: true, todos: [t1, t2])
        #expect(t1.isDone)
        #expect(t2.isDone)
        #expect(sub1.isDone)

        // Batch mark as not done
        DayBoardMutations.batchToggleDone([t1.id, t2.id], markDone: false, todos: [t1, t2])
        #expect(!t1.isDone)
        #expect(!t2.isDone)
        // Subtask remains done due to one-way cascade rule
        #expect(sub1.isDone)
    }

    @Test func batchApplyTagAddsAndRemoves() throws {
        let (_, context) = try makeContainer()
        let t1 = TodoItem(title: "任务 1", dayKey: "2026-09-08")
        let r1 = DailyRoutine(title: "习惯 1", sortOrder: 0, createdDayKey: "2026-09-08")
        context.insert(t1)
        context.insert(r1)

        let tagID = UUID()
        DayBoardMutations.batchApplyTag([t1.id, r1.id], tagID: tagID, present: true, todos: [t1], routines: [r1])
        #expect(TagIDList.contains(t1.tagIDs, tagID))
        #expect(TagIDList.contains(r1.tagIDs, tagID))

        DayBoardMutations.batchApplyTag([t1.id, r1.id], tagID: tagID, present: false, todos: [t1], routines: [r1])
        #expect(!TagIDList.contains(t1.tagIDs, tagID))
        #expect(!TagIDList.contains(r1.tagIDs, tagID))
    }

    @Test func batchToggleTag() throws {
        let (_, context) = try makeContainer()
        let t1 = TodoItem(title: "任务 1", dayKey: "2026-09-08")
        let r1 = DailyRoutine(title: "习惯 1", sortOrder: 0, createdDayKey: "2026-09-08")
        context.insert(t1)
        context.insert(r1)

        let tagID = UUID()
        // Toggle on
        DayBoardMutations.batchToggleTag([t1.id, r1.id], tagID: tagID, todos: [t1], routines: [r1])
        #expect(t1.tagIDs.contains(tagID.uuidString))
        #expect(r1.tagIDs.contains(tagID.uuidString))

        // Toggle off
        DayBoardMutations.batchToggleTag([t1.id, r1.id], tagID: tagID, todos: [t1], routines: [r1])
        #expect(!t1.tagIDs.contains(tagID.uuidString))
        #expect(!r1.tagIDs.contains(tagID.uuidString))
    }

    @Test func batchTrash() throws {
        let (_, context) = try makeContainer()
        let t1 = TodoItem(title: "任务 1", dayKey: "2026-09-08")
        let r1 = DailyRoutine(title: "习惯 1", sortOrder: 0, createdDayKey: "2026-09-08")
        context.insert(t1)
        context.insert(r1)

        _ = DayBoardMutations.addSubtask(to: t1, title: "子任务 1-1", context: context)
        let sub1 = try #require(t1.subtasks.first)

        #expect(t1.deletedAt == nil)
        #expect(sub1.deletedAt == nil)
        #expect(r1.deletedAt == nil)

        DayBoardMutations.batchTrash([t1.id, r1.id], todos: [t1], routines: [r1])

        #expect(t1.deletedAt != nil)
        #expect(sub1.deletedAt != nil)
        #expect(r1.deletedAt != nil)
    }

    @Test func batchToggleListedWritesTodosAndRoutinesTogether() throws {
        let (_, context) = try makeContainer()
        let calendar = Calendar(identifier: .gregorian)
        let created = "2026-09-01"
        let unscheduled = try #require(firstDay(from: created, calendar: calendar) {
            !WeekdayMask.contains(WeekdayMask.workdays, dayKey: $0, calendar: calendar)
        })
        let scheduled = try #require(firstDay(from: created, calendar: calendar) {
            WeekdayMask.contains(WeekdayMask.workdays, dayKey: $0, calendar: calendar)
        })
        let todo = TodoItem(title: "待办", dayKey: scheduled)
        let routine = DailyRoutine(
            title: "仅工作日",
            sortOrder: 0,
            createdDayKey: created,
            weekdayMask: WeekdayMask.workdays
        )
        context.insert(todo)
        context.insert(routine)
        #expect(DayBoardMutations.addSubtask(to: todo, title: "子任务", context: context))
        let child = try #require(todo.subtasks.first)

        let rejected = DayBoardMutations.batchToggleListed(
            todoIDs: [todo.id],
            routineChecks: [unscheduled: [routine.id]],
            markDone: true,
            todos: [todo],
            routines: [routine],
            context: context
        )
        #expect(!rejected)
        #expect(!todo.isDone)
        #expect(!child.isDone)
        #expect(routine.checks.isEmpty)

        let saved = DayBoardMutations.batchToggleListed(
            todoIDs: [todo.id],
            routineChecks: [scheduled: [routine.id]],
            markDone: true,
            todos: [todo],
            routines: [routine],
            context: context
        )
        #expect(saved)
        #expect(todo.isDone)
        #expect(child.isDone)
        #expect(routine.checks.contains { $0.dayKey == scheduled && $0.isDone && !$0.isSkipped })
    }

    @Test func batchSetRoutineChecksMarksToday() throws {
        let (_, context) = try makeContainer()
        let routine = DailyRoutine(title: "习惯", sortOrder: 0, createdDayKey: "2026-09-01")
        context.insert(routine)
        try context.save()

        DayBoardMutations.batchSetRoutineChecks(
            [routine.id],
            markDone: true,
            on: "2026-09-09",
            routines: [routine],
            context: context
        )
        let inserted = try #require(routine.checks.first { $0.dayKey == "2026-09-09" })
        #expect(inserted.isDone)
        #expect(!inserted.isSkipped)

        DayBoardMutations.batchSetRoutineChecks(
            [routine.id],
            markDone: false,
            on: "2026-09-09",
            routines: [routine],
            context: context
        )
        #expect(!inserted.isDone)
        #expect(!inserted.isSkipped)
    }

    @Test func batchSetRoutineChecksRejectsUnscheduledDayWithoutWriting() throws {
        let (_, context) = try makeContainer()
        let calendar = Calendar(identifier: .gregorian)
        let created = "2026-09-01"
        let unscheduled = try #require(firstDay(from: created, calendar: calendar) {
            !WeekdayMask.contains(WeekdayMask.workdays, dayKey: $0, calendar: calendar)
        })
        let scheduled = try #require(firstDay(from: created, calendar: calendar) {
            WeekdayMask.contains(WeekdayMask.workdays, dayKey: $0, calendar: calendar)
        })
        let routine = DailyRoutine(
            title: "仅工作日",
            sortOrder: 0,
            createdDayKey: created,
            weekdayMask: WeekdayMask.workdays
        )
        context.insert(routine)

        let rejected = DayBoardMutations.batchSetRoutineChecks(
            [routine.id], markDone: true, on: unscheduled, routines: [routine], context: context
        )
        #expect(!rejected)
        #expect(routine.checks.isEmpty)

        let mixed = DayBoardMutations.batchSetRoutineChecks(
            groupedByDay: [unscheduled: [routine.id], scheduled: [routine.id]],
            markDone: true,
            routines: [routine],
            context: context
        )
        #expect(!mixed)
        #expect(routine.checks.isEmpty)

        let accepted = DayBoardMutations.batchSetRoutineChecks(
            [routine.id], markDone: true, on: scheduled, routines: [routine], context: context
        )
        #expect(accepted)
        #expect(routine.checks.contains { $0.dayKey == scheduled && $0.isDone })
    }

    private func firstDay(from start: String, calendar: Calendar, matching: (String) -> Bool) -> String? {
        var cursor = start
        for _ in 0..<14 {
            if matching(cursor) { return cursor }
            let next = DayKey.shifted(cursor, by: 1, calendar: calendar)
            if next <= cursor { return nil }
            cursor = next
        }
        return nil
    }

    @Test func enablingLegacyPausedHabitFillsSkippedDays() throws {
        let (_, context) = try makeContainer()
        let routine = DailyRoutine(
            title: "旧停用",
            sortOrder: 0,
            isEnabled: false,
            createdDayKey: "2026-09-01"
        )
        context.insert(routine)
        let last = RoutineCheck(dayKey: "2026-09-05", isDone: true, routine: routine)
        context.insert(last)

        DayBoardMutations.setRoutineEnabled(
            routine,
            enabled: true,
            todayKey: "2026-09-09",
            checks: [last],
            context: context
        )

        #expect(routine.isEnabled)
        #expect(routine.pausedOnDayKey == nil)
        let skipped = Set(routine.checks.filter(\.isSkipped).map(\.dayKey))
        #expect(skipped.isSuperset(of: ["2026-09-06", "2026-09-07", "2026-09-08"]))
        #expect(!skipped.contains("2026-09-09"))
        #expect(!skipped.contains("2026-09-05"))
    }

    @Test func enablingAlreadyEnabledHabitDoesNotBackfillSkips() throws {
        let (_, context) = try makeContainer()
        let routine = DailyRoutine(
            title: "在用",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01"
        )
        context.insert(routine)
        let last = RoutineCheck(dayKey: "2026-09-05", isDone: true, routine: routine)
        context.insert(last)

        DayBoardMutations.setRoutineEnabled(
            routine,
            enabled: true,
            todayKey: "2026-09-09",
            checks: [last],
            context: context
        )

        #expect(routine.checks.filter(\.isSkipped).isEmpty)
    }

    @Test func addCapturedTodoTokenOnlySucceeds() throws {
        let (_, context) = try makeContainer()
        let result = DayBoardMutations.addCapturedTodo(text: "#1", dayKey: "2026-09-18", context: context)
        #expect(result == true)

        let fetchDescriptor = FetchDescriptor<TodoItem>()
        let items = try context.fetch(fetchDescriptor)
        #expect(items.count == 1)
        let todo = try #require(items.first)
        #expect(todo.title == "")
        #expect(!todo.tagIDs.isEmpty)
    }

    @Test func addCapturedTodoWithContentSucceeds() throws {
        let (_, context) = try makeContainer()
        let result = DayBoardMutations.addCapturedTodo(text: "@01:00 开会 #工作 !p1", dayKey: "2026-09-18", context: context)
        #expect(result == true)

        let fetchDescriptor = FetchDescriptor<TodoItem>()
        let items = try context.fetch(fetchDescriptor)
        #expect(items.count == 1)
        let todo = try #require(items.first)
        #expect(todo.title == "开会")
        #expect(todo.remindMinutes == 60)
        #expect(todo.isImportant == true)
        #expect(todo.isUrgent == true)
    }
}
