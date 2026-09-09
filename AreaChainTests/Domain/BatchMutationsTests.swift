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

    @Test func batchSetProject() throws {
        let (_, context) = try makeContainer()
        let t1 = TodoItem(title: "任务 1", dayKey: "2026-09-08")
        let r1 = DailyRoutine(title: "习惯 1", sortOrder: 0, createdDayKey: "2026-09-08")
        context.insert(t1)
        context.insert(r1)

        let projID = UUID()
        DayBoardMutations.batchSetProject([t1.id, r1.id], projectID: projID, todos: [t1], routines: [r1])

        #expect(t1.projectID == projID)
        #expect(r1.projectID == projID)

        // Clear project
        DayBoardMutations.batchSetProject([t1.id, r1.id], projectID: nil, todos: [t1], routines: [r1])
        #expect(t1.projectID == nil)
        #expect(r1.projectID == nil)
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
            checks: [],
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
            checks: [inserted],
            context: context
        )
        #expect(!inserted.isDone)
        #expect(!inserted.isSkipped)
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
}
