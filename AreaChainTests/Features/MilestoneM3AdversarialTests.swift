import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct MilestoneM3AdversarialTests {
    private func makeContainer() throws -> (ModelContainer, ModelContext) {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, ModelContext(container))
    }

    // MARK: - 1. TaskRowFactory & DTO Stress Tests

    @Test func taskRowFactoryTodoWithNilNotesAndEmptyTags() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "Simple Todo", dayKey: "2026-09-10")
        todo.notes = ""
        context.insert(todo)

        let catalogContext = TaskCatalogContext(projects: [], tags: [], attachments: [], context: context)
        let display = TodoRowDisplayOptions(isDone: false, isSelected: false, note: nil)
        var selectCalled = false
        var deleteCalled = false
        let actions = TodoRowActions(onSelect: { _ in selectCalled = true }, onDelete: { deleteCalled = true })

        let row = TaskRowFactory.todo(TodoRowContext(
            todo: todo,
            todayKey: "2026-09-10",
            catalogs: catalogContext,
            display: display,
            actions: actions
        ))

        #expect(row.state.title == "Simple Todo")
        #expect(row.state.notes == "")
        #expect(row.state.note == nil)
        #expect(row.state.classify?.projects.isEmpty == true)
        #expect(row.state.classify?.tags.isEmpty == true)
        #expect(row.state.isSelected == false)
        #expect(row.state.isExternalEditing == false)

        row.dispatch(.select())
        #expect(selectCalled)
        row.dispatch(.delete)
        #expect(deleteCalled)
    }

    @Test func taskRowFactoryTodoLongStringsAndExternalEditing() throws {
        let (_, context) = try makeContainer()
        let longTitle = String(repeating: "LongTitle-🌟-", count: 400)
        let longNote = String(repeating: "Line1\nLine2\n", count: 500)
        let todo = TodoItem(title: longTitle, dayKey: "2026-09-10")
        todo.notes = longNote
        context.insert(todo)

        let catalogContext = TaskCatalogContext(projects: [], tags: [], attachments: [], context: context)
        let selection = TaskRowSelectionState(isSelected: true, isExternalEditing: true)
        let display = TodoRowDisplayOptions(
            isDone: true,
            selection: selection,
            dragPayload: "payload-12345",
            note: "Explicit Custom Note",
            includeSubtasks: false
        )
        let actions = TodoRowActions(onSelect: { _ in }, onDelete: {})

        let row = TaskRowFactory.todo(TodoRowContext(
            todo: todo,
            todayKey: "2026-09-10",
            catalogs: catalogContext,
            display: display,
            actions: actions
        ))

        #expect(row.state.title == longTitle)
        #expect(row.state.notes == longNote)
        #expect(row.state.note == "Explicit Custom Note")
        #expect(row.state.isDone == true)
        #expect(row.state.isSelected == true)
        #expect(row.state.isExternalEditing == true)
        #expect(row.state.dragPayload == "payload-12345")
        #expect(row.state.subtasks.isEmpty)
    }

    @Test func taskRowFactoryRoutineNotesStreakAndSkipCombinations() throws {
        let (_, context) = try makeContainer()
        let routine = DailyRoutine(title: "Workout", sortOrder: 0, createdDayKey: "2026-09-01")
        context.insert(routine)
        let check1 = RoutineCheck(dayKey: "2026-09-09", isDone: true, routine: routine)
        let check2 = RoutineCheck(dayKey: "2026-09-10", isDone: true, routine: routine)
        context.insert(check1)
        context.insert(check2)
        try context.save()

        let catalogContext = TaskCatalogContext(projects: [], tags: [], attachments: [], context: context)
        let schedule = RoutineScheduleContext(
            todayKey: "2026-09-10",
            checkDayKey: "2026-09-10",
            checks: [check1, check2],
            locale: Locale(identifier: "zh_CN")
        )

        // Case A1: Everyday routine completed (not skipped) -> default note is nil
        let displayA1 = RoutineRowDisplayOptions(isDone: true, usesDefaultNote: true)
        let actionsA1 = RoutineRowActions(onSelect: { _ in }, onDelete: {}, onSkip: nil)
        let rowA1 = TaskRowFactory.routine(RoutineRowContext(
            routine: routine, schedule: schedule, catalogs: catalogContext, display: displayA1, actions: actionsA1
        ))
        #expect(rowA1.state.streak == 2)
        #expect(rowA1.state.canSkip == false)
        #expect(rowA1.state.note == nil) // Everyday habit completed has no weekday restriction note

        // Case A2: Weekdays-only routine completed -> default note shows weekday label
        let weekdayRoutine = DailyRoutine(title: "Study", sortOrder: 1, createdDayKey: "2026-09-01", weekdaysOnly: true)
        context.insert(weekdayRoutine)
        let rowA2 = TaskRowFactory.routine(RoutineRowContext(
            routine: weekdayRoutine, schedule: schedule, catalogs: catalogContext, display: displayA1, actions: actionsA1
        ))
        #expect(rowA2.state.note != nil)

        // Case A3: Explicit custom note overrides default note
        let displayA3 = RoutineRowDisplayOptions(isDone: true, note: "Custom Note", usesDefaultNote: true)
        let rowA3 = TaskRowFactory.routine(RoutineRowContext(
            routine: routine, schedule: schedule, catalogs: catalogContext, display: displayA3, actions: actionsA1
        ))
        #expect(rowA3.state.note == "Custom Note")

        // Case B: Default note disabled, onSkip provided
        var skipFired = false
        let displayB = RoutineRowDisplayOptions(isDone: false, usesDefaultNote: false)
        let actionsB = RoutineRowActions(onSelect: { _ in }, onDelete: {}, onSkip: { skipFired = true })
        let rowB = TaskRowFactory.routine(RoutineRowContext(
            routine: routine, schedule: schedule, catalogs: catalogContext, display: displayB, actions: actionsB
        ))
        #expect(rowB.state.note == nil)
        #expect(rowB.state.canSkip == true)
        rowB.dispatch(.skip)
        #expect(skipFired)
    }

    @Test func taskRowFactoryLeftoverFallbackStateAndActions() throws {
        let item = UnfinishedItem(id: UUID(), title: "Yesterday Leftover", kind: .todo)
        var toggleCalled = false
        var selectCalled = false
        var movedDay: String? = nil

        let actions = LeftoverRowActions(
            onToggle: { toggleCalled = true },
            onSelect: { _ in selectCalled = true },
            onMoveToDay: { movedDay = $0 }
        )
        let row = TaskRowFactory.leftoverFallback(LeftoverRowContext(
            item: item,
            todayKey: "2026-09-10",
            yesterdayKey: "2026-09-09",
            isSelected: true,
            actions: actions
        ))

        #expect(row.state.id == item.id)
        #expect(row.state.title == "Yesterday Leftover")
        #expect(row.state.isSelected == true)
        #expect(row.state.todayKey == "2026-09-10")
        #expect(row.state.currentDayKey == "2026-09-09")

        row.dispatch(.toggleDone)
        #expect(toggleCalled)
        row.dispatch(.select())
        #expect(selectCalled)
        row.dispatch(.moveToDay("2026-09-11"))
        #expect(movedDay == "2026-09-11")
    }

    // MARK: - 2. Routine Batch Operations Stress Tests

    @Test func routineRepositoryBatchOperationsEmptyAndNonExistent() throws {
        let (container, context) = try makeContainer()
        let repo = SwiftDataRoutineRepository(context: context, container: container)
        let nonExistentIDs: Set<UUID> = [UUID(), UUID(), UUID()]

        // Empty set resilience
        try repo.batchTrashRoutines(ids: [])
        try repo.batchSetProject(ids: [], projectID: UUID())
        try repo.batchSetProject(ids: [], projectID: nil)
        try repo.batchToggleTag(ids: [], tagID: UUID())
        try repo.batchSetRoutineChecks(ids: [], markDone: true, on: "2026-09-10")

        // Non-existent UUIDs resilience
        try repo.batchTrashRoutines(ids: nonExistentIDs)
        try repo.batchSetProject(ids: nonExistentIDs, projectID: UUID())
        try repo.batchToggleTag(ids: nonExistentIDs, tagID: UUID())
        try repo.batchSetRoutineChecks(ids: nonExistentIDs, markDone: true, on: "2026-09-10")

        let allRoutines = try repo.fetchRoutines(includeDisabled: true, includeDeleted: true)
        #expect(allRoutines.isEmpty)
    }

    @Test func routineRepositoryBatchOperationsSelectiveApplication() throws {
        let (container, context) = try makeContainer()
        let repo = SwiftDataRoutineRepository(context: context, container: container)

        let r1 = try repo.addRoutine(title: "R1")
        let r2 = try repo.addRoutine(title: "R2")
        let r3 = try repo.addRoutine(title: "R3")

        let projectID = UUID()
        let tagID = UUID()

        // Batch project on subset
        try repo.batchSetProject(ids: [r1.id, r2.id], projectID: projectID)
        #expect(r1.projectID == projectID)
        #expect(r2.projectID == projectID)
        #expect(r3.projectID == nil)

        // Batch toggle tag on subset
        try repo.batchToggleTag(ids: [r1.id, r3.id], tagID: tagID)
        #expect(TagIDList.contains(r1.tagIDs, tagID))
        #expect(!TagIDList.contains(r2.tagIDs, tagID))
        #expect(TagIDList.contains(r3.tagIDs, tagID))

        // Batch toggle tag off
        try repo.batchToggleTag(ids: [r1.id], tagID: tagID)
        #expect(!TagIDList.contains(r1.tagIDs, tagID))
        #expect(TagIDList.contains(r3.tagIDs, tagID))

        // Batch trash on subset
        try repo.batchTrashRoutines(ids: [r2.id])
        #expect(r1.deletedAt == nil)
        #expect(r2.deletedAt != nil)
        #expect(r3.deletedAt == nil)
    }

    @Test func dayBoardMutationsConcurrentBatchSelections() throws {
        let (container, context) = try makeContainer()
        DayBoardMutations.taskRepositoryProvider = { _ in SwiftDataTaskRepository(context: context, container: container) }
        DayBoardMutations.routineRepositoryProvider = { _ in SwiftDataRoutineRepository(context: context, container: container) }
        defer {
            DayBoardMutations.taskRepositoryProvider = nil
            DayBoardMutations.routineRepositoryProvider = nil
        }

        let t1 = TodoItem(title: "Todo 1", dayKey: "2026-09-10")
        let t2 = TodoItem(title: "Todo 2", dayKey: "2026-09-10")
        let r1 = DailyRoutine(title: "Routine 1", sortOrder: 0, createdDayKey: "2026-09-10")
        let r2 = DailyRoutine(title: "Routine 2", sortOrder: 1, createdDayKey: "2026-09-10")
        context.insert(t1)
        context.insert(t2)
        context.insert(r1)
        context.insert(r2)
        try context.save()

        let projectID = UUID()
        let tagID = UUID()
        let mixedIDs: Set<UUID> = [t1.id, r1.id, UUID()] // includes non-existent UUID

        // 1. Concurrent Batch Project
        DayBoardMutations.batchSetProject(mixedIDs, projectID: projectID, todos: [t1, t2], routines: [r1, r2])
        #expect(t1.projectID == projectID)
        #expect(r1.projectID == projectID)
        #expect(t2.projectID == nil)
        #expect(r2.projectID == nil)

        // 2. Concurrent Batch Tag
        DayBoardMutations.batchToggleTag(mixedIDs, tagID: tagID, todos: [t1, t2], routines: [r1, r2])
        #expect(TagIDList.contains(t1.tagIDs, tagID))
        #expect(TagIDList.contains(r1.tagIDs, tagID))
        #expect(!TagIDList.contains(t2.tagIDs, tagID))
        #expect(!TagIDList.contains(r2.tagIDs, tagID))

        // 3. Concurrent Batch Trash
        DayBoardMutations.batchTrash(mixedIDs, todos: [t1, t2], routines: [r1, r2])
        #expect(t1.deletedAt != nil)
        #expect(r1.deletedAt != nil)
        #expect(t2.deletedAt == nil)
        #expect(r2.deletedAt == nil)
    }

    // MARK: - 3. UI Event Bindings & Callbacks State Retention

    @Test func taskRowTodoCallbacksExecuteWithoutLosingState() throws {
        let (container, context) = try makeContainer()
        DayBoardMutations.taskRepositoryProvider = { _ in SwiftDataTaskRepository(context: context, container: container) }
        defer { DayBoardMutations.taskRepositoryProvider = nil }

        let todo = TodoItem(title: "Original Todo", dayKey: "2026-09-10")
        context.insert(todo)
        let sub = SubtaskItem(title: "Subtask", sortOrder: 0, todo: todo)
        context.insert(sub)
        try context.save()

        let catalogContext = TaskCatalogContext(projects: [], tags: [], attachments: [], context: context)
        var endEditingFired = false
        let actions = TodoRowActions(
            onSelect: { _ in },
            onDelete: {},
            onEndEditing: { endEditingFired = true }
        )
        let row = TaskRowFactory.todo(TodoRowContext(
            todo: todo,
            todayKey: "2026-09-10",
            catalogs: catalogContext,
            display: TodoRowDisplayOptions(isDone: false),
            actions: actions
        ))

        // Toggle Todo & Cascade
        row.dispatch(.toggleDone)
        #expect(todo.isDone == true)
        #expect(sub.isDone == true)

        // Edit Title
        row.dispatch(.editTitle("Renamed Todo"))
        #expect(todo.title == "Renamed Todo")

        // Move to Day
        row.dispatch(.moveToDay("2026-09-15"))
        #expect(todo.dayKey == "2026-09-15")

        // Set Remind Minutes
        row.dispatch(.setRemindMinutes(45))
        #expect(todo.remindMinutes == 45)

        // Toggle Subtask
        row.dispatch(.toggleSubtask(sub.id))
        #expect(sub.isDone == false)

        // End Editing
        row.dispatch(.endEditing)
        #expect(endEditingFired)
    }

    @Test func taskRowRoutineCallbacksExecuteWithoutLosingState() throws {
        let (container, context) = try makeContainer()
        DayBoardMutations.routineRepositoryProvider = { _ in SwiftDataRoutineRepository(context: context, container: container) }
        defer { DayBoardMutations.routineRepositoryProvider = nil }

        let routine = DailyRoutine(title: "Routine Baseline", sortOrder: 0, createdDayKey: "2026-09-01")
        context.insert(routine)
        try context.save()

        let catalogContext = TaskCatalogContext(projects: [], tags: [], attachments: [], context: context)
        let schedule = RoutineScheduleContext(
            todayKey: "2026-09-10",
            checkDayKey: "2026-09-10",
            checks: []
        )
        let actions = RoutineRowActions(onSelect: { _ in }, onDelete: {})
        let row = TaskRowFactory.routine(RoutineRowContext(
            routine: routine,
            schedule: schedule,
            catalogs: catalogContext,
            display: RoutineRowDisplayOptions(isDone: false),
            actions: actions
        ))

        // Toggle routine (without custom onToggle) executes default DayBoardMutations.toggleRoutine
        row.dispatch(.toggleDone)
        let checksAfterToggle = try context.fetch(FetchDescriptor<RoutineCheck>())
        let check = try #require(checksAfterToggle.first { $0.routine?.id == routine.id && $0.dayKey == "2026-09-10" })
        #expect(check.isDone == true)

        // Edit Title
        row.dispatch(.editTitle("Renamed Routine"))
        #expect(routine.title == "Renamed Routine")

        // Set Remind
        row.dispatch(.setRemindMinutes(30))
        #expect(routine.remindMinutes == 30)

        // Set Enabled
        row.dispatch(.setEnabled(false))
        #expect(routine.isEnabled == false)
        #expect(routine.pausedOnDayKey == "2026-09-10")
    }

    @Test func taskClassifyContextCallbacksPersistMutations() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "Classified Todo", dayKey: "2026-09-10")
        context.insert(todo)
        let project = ProjectItem(name: "Work Project", sortOrder: 0)
        let tag = TagItem(name: "UrgentTag", sortOrder: 0)
        context.insert(project)
        context.insert(tag)
        try context.save()

        let classify = CatalogChoices.classify(for: todo, projects: [project], tags: [tag])

        classify.onImportant(true)
        #expect(todo.isImportant == true)

        classify.onUrgent(true)
        #expect(todo.isUrgent == true)

        classify.onProject(project.id)
        #expect(todo.projectID == project.id)

        classify.onToggleTag(tag.id)
        #expect(TagIDList.contains(todo.tagIDs, tag.id))

        classify.onToggleTag(tag.id)
        #expect(!TagIDList.contains(todo.tagIDs, tag.id))

        let clearProject: UUID? = nil
        classify.onProject(clearProject)
        #expect(todo.projectID == nil)
    }
}
