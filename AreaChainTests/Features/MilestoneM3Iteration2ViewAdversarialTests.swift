import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct MilestoneM3Iteration2ViewAdversarialTests {
    private func makeContainer() throws -> (ModelContainer, ModelContext) {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, ModelContext(container))
    }

    // MARK: - 1. TasksPage and DayBoardList Configuration & Forwarding

    @Test func tasksPageConfigDefaultsAndCustomForwarding() throws {
        let defaultConfig = TasksPageConfig()
        #expect(defaultConfig.yesterdayKey == nil)
        #expect(defaultConfig.maxScrollHeight == nil)
        #expect(defaultConfig.focusedTaskID == nil)
        #expect(defaultConfig.highlightedTaskID == nil)

        var focusedID: UUID? = UUID()
        let binding = Binding<UUID?>(get: { focusedID }, set: { focusedID = $0 })
        var inspectedID: UUID? = nil
        var returnedToInput = false

        let interaction = DayBoardInteraction(
            focusedTaskID: binding,
            highlightedTaskID: focusedID,
            onInspect: { inspectedID = $0 },
            onReturnToInput: { returnedToInput = true }
        )
        let customConfig = TasksPageConfig(
            yesterdayKey: "2026-09-08",
            maxScrollHeight: 450,
            interaction: interaction
        )

        let page = TasksPage(
            todayKey: "2026-09-09",
            routines: [],
            checks: [],
            todos: [],
            config: customConfig
        )

        #expect(page.todayKey == "2026-09-09")
        #expect(page.yesterdayKey == "2026-09-08")
        #expect(page.maxScrollHeight == 450)
        #expect(page.focusedTaskID?.wrappedValue == focusedID)
        #expect(page.highlightedTaskID == focusedID)

        page.onInspect?(focusedID!)
        #expect(inspectedID == focusedID)

        page.onReturnToInput?()
        #expect(returnedToInput)

        // Verify default yesterdayKey derivation
        let defaultPage = TasksPage(
            todayKey: "2026-09-09",
            routines: [],
            checks: [],
            todos: []
        )
        #expect(defaultPage.yesterdayKey == "2026-09-08")
        #expect(defaultPage.maxScrollHeight == nil)
    }

    @Test func dayBoardListConfigAndInteractionForwarding() throws {
        let defaultList = DayBoardList(
            dayKey: "2026-09-09",
            routines: [],
            checks: [],
            todos: []
        )
        #expect(defaultList.todayKey == "2026-09-09")
        #expect(defaultList.filter.isActive == false)
        #expect(defaultList.allowsTodoDrag == false)
        #expect(defaultList.dayKeyForID == nil)
        #expect(defaultList.focusedTaskID == nil)

        let customID = UUID()
        var inspectedID: UUID? = nil
        let interaction = DayBoardInteraction(
            highlightedTaskID: customID,
            onInspect: { inspectedID = $0 }
        )
        let customConfig = DayBoardListConfig(
            todayKey: "2026-09-09",
            filter: BoardFilter(),
            allowsTodoDrag: true,
            dayKeyForID: { _ in "2026-09-05" },
            interaction: interaction
        )
        let customList = DayBoardList(
            dayKey: "2026-09-05",
            routines: [],
            checks: [],
            todos: [],
            config: customConfig
        )

        #expect(customList.dayKey == "2026-09-05")
        #expect(customList.todayKey == "2026-09-09")
        #expect(customList.allowsTodoDrag == true)
        #expect(customList.highlightedTaskID == customID)
        #expect(customList.dayKeyForID?(UUID()) == "2026-09-05")

        customList.onInspect?(customID)
        #expect(inspectedID == customID)
    }

    @Test func tasksPageAndDayBoardRenderingAcrossContexts() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "Context Test Todo", dayKey: "2026-09-09")
        let routine = DailyRoutine(title: "Context Routine", sortOrder: 0, createdDayKey: "2026-09-01")
        context.insert(todo)
        context.insert(routine)
        try context.save()

        // 1. MenuBarPopoverView context
        var popoverFocusedID: UUID? = nil
        let popoverPage = TasksPage(
            todayKey: "2026-09-09",
            routines: [routine],
            checks: [],
            todos: [todo],
            config: TasksPageConfig(
                yesterdayKey: "2026-09-08",
                interaction: DayBoardInteraction(
                    focusedTaskID: Binding(get: { popoverFocusedID }, set: { popoverFocusedID = $0 }),
                    onReturnToInput: { popoverFocusedID = nil }
                )
            )
        )
        _ = popoverPage.body

        // 2. WorkspaceTodayView context
        let nav = WorkspaceNavigation.shared
        let workspacePage = TasksPage(
            todayKey: "2026-09-09",
            routines: [routine],
            checks: [],
            todos: [todo],
            config: TasksPageConfig(
                yesterdayKey: "2026-09-08",
                interaction: DayBoardInteraction(
                    focusedTaskID: Binding(get: { nav.selectedTaskID }, set: { nav.selectedTaskID = $0 }),
                    highlightedTaskID: nav.selectedTaskID,
                    onInspect: { nav.inspectTask($0) }
                )
            )
        )
        _ = workspacePage.body

        // 3. CalendarPage context
        let calendarList = DayBoardList(
            dayKey: "2026-09-05",
            routines: [routine],
            checks: [],
            todos: [todo],
            config: DayBoardListConfig(
                todayKey: "2026-09-09",
                allowsTodoDrag: true,
                interaction: DayBoardInteraction(
                    highlightedTaskID: nav.selectedTaskID,
                    onInspect: { nav.inspectTask($0) }
                )
            )
        )
        _ = calendarList.body
        #expect(calendarList.allowsTodoDrag == true)
    }

    // MARK: - 2. LeftoverChipsBar Toggling

    @Test func leftoverChipsBarTogglingYesterdayAndUpcoming() throws {
        var yesterdayToggled = false
        var upcomingToggled = false

        let chipConfig = LeftoverChipsBarConfig(
            yesterday: LeftoverChipState(
                count: 3,
                isExpanded: false,
                onToggle: { yesterdayToggled = true }
            ),
            upcoming: LeftoverChipState(
                count: 5,
                isExpanded: true,
                onToggle: { upcomingToggled = true }
            )
        )
        let bar = LeftoverChipsBar(config: chipConfig)
        _ = bar.body

        chipConfig.yesterday.onToggle()
        #expect(yesterdayToggled)

        chipConfig.upcoming.onToggle()
        #expect(upcomingToggled)

        // Zero counts check
        let emptyBar = LeftoverChipsBar(
            config: LeftoverChipsBarConfig(
                yesterday: LeftoverChipState(count: 0, isExpanded: false, onToggle: {}),
                upcoming: LeftoverChipState(count: 0, isExpanded: false, onToggle: {})
            )
        )
        _ = emptyBar.body
    }

    // MARK: - 3. TaskDetailStreakCard Rendering & Indicators

    @Test func taskDetailStreakCardAllFiveStatusStates() throws {
        let streak = StreakResult(currentStreak: 7, bestStreak: 21)

        // State 1: Paused / Disabled
        let pausedConfig = StreakCardConfig(
            streakResult: streak,
            isEnabled: false,
            inspectDayKey: "2026-09-09",
            flags: StreakInspectionFlags(isCompleted: false, isSkipped: false, isDue: true)
        )
        let pausedCard = TaskDetailStreakCard(config: pausedConfig)
        _ = pausedCard.body

        // State 2: Completed
        let completedConfig = StreakCardConfig(
            streakResult: streak,
            isEnabled: true,
            inspectDayKey: "2026-09-09",
            flags: StreakInspectionFlags(isCompleted: true, isSkipped: false, isDue: true)
        )
        let completedCard = TaskDetailStreakCard(config: completedConfig)
        _ = completedCard.body

        // State 3: Skipped
        let skippedConfig = StreakCardConfig(
            streakResult: streak,
            isEnabled: true,
            inspectDayKey: "2026-09-09",
            flags: StreakInspectionFlags(isCompleted: false, isSkipped: true, isDue: true)
        )
        let skippedCard = TaskDetailStreakCard(config: skippedConfig)
        _ = skippedCard.body

        // State 4: Off-Day (Not Due)
        let offdayConfig = StreakCardConfig(
            streakResult: streak,
            isEnabled: true,
            inspectDayKey: "2026-09-09",
            flags: StreakInspectionFlags(isCompleted: false, isSkipped: false, isDue: false)
        )
        let offdayCard = TaskDetailStreakCard(config: offdayConfig)
        _ = offdayCard.body

        // State 5: Pending
        let pendingConfig = StreakCardConfig(
            streakResult: streak,
            isEnabled: true,
            inspectDayKey: "2026-09-09",
            flags: StreakInspectionFlags(isCompleted: false, isSkipped: false, isDue: true)
        )
        let pendingCard = TaskDetailStreakCard(config: pendingConfig)
        _ = pendingCard.body

        #expect(pendingConfig.streakResult.currentStreak == 7)
        #expect(pendingConfig.streakResult.bestStreak == 21)
    }

    // MARK: - 4. CalendarMonthGrid Navigation & Selection

    @Test func calendarMonthGridNavigationAndDateSelection() throws {
        var selectedDate: String? = nil
        var droppedTodo: (UUID, String)? = nil
        let targetTodoID = UUID()

        let dates = CalendarMonthGridDates(
            monthKey: "2026-09-10",
            todayKey: "2026-09-10",
            selectedKey: "2026-09-05"
        )
        let grid = CalendarMonthGrid(
            dates: dates,
            counts: ["2026-09-05": 3, "2026-09-10": 1],
            onSelect: { selectedDate = $0 },
            onDropTodo: { id, day in droppedTodo = (id, day) }
        )

        #expect(grid.monthKey == "2026-09-10")
        #expect(grid.todayKey == "2026-09-10")
        #expect(grid.selectedKey == "2026-09-05")

        grid.onSelect("2026-09-18")
        #expect(selectedDate == "2026-09-18")

        grid.onDropTodo?(targetTodoID, "2026-09-22")
        #expect(droppedTodo?.0 == targetTodoID)
        #expect(droppedTodo?.1 == "2026-09-22")

        // Test month shift calculations used by CalendarPage
        let cal = Calendar.current
        let prevMonth = DayKey.shiftedMonth("2026-09-10", by: -1, calendar: cal)
        let nextMonth = DayKey.shiftedMonth("2026-09-10", by: 1, calendar: cal)
        #expect(prevMonth.hasPrefix("2026-08"))
        #expect(nextMonth.hasPrefix("2026-10"))

        _ = grid.body
    }

    // MARK: - 5. DiaryCardComponents Action Buttons

    @Test func diaryCardComponentsPinAndActions() throws {
        let (_, context) = try makeContainer()
        let entry = DiaryEntry(
            text: "Adversarial Diary Note",
            dayKey: "2026-09-09"
        )
        entry.isPinned = false
        context.insert(entry)
        try context.save()

        // Pin toggling via mutation
        DayBoardMutations.togglePinDiary(entry)
        #expect(entry.isPinned == true)

        DayBoardMutations.togglePinDiary(entry)
        #expect(entry.isPinned == false)

        var deleteCalled = false
        let card = DiaryNoteCard(
            entry: entry,
            activeTags: [],
            attachments: [],
            onDelete: { deleteCalled = true }
        )
        _ = card.managementActionButtons
        _ = card.body

        card.onDelete()
        #expect(deleteCalled)
    }

    // MARK: - 6. BatchActionBar & WorkspaceBatchActionBar Operations

    @Test func batchActionBarCallbacksWiring() throws {
        var movedToday = false
        var movedTomorrow = false
        var toggledDoneVal: Bool? = nil
        var projectSet: UUID? = nil
        var tagToggled: UUID? = nil
        var trashed = false
        var cleared = false

        let projID = UUID()
        let tagID = UUID()

        let bar = BatchActionBar(
            selectedCount: 4,
            schedule: BatchScheduleActions(
                onMoveToday: { movedToday = true },
                onMoveTomorrow: { movedTomorrow = true },
                onToggleDone: { toggledDoneVal = $0 }
            ),
            classify: BatchClassifyActions(
                onSetProject: { projectSet = $0 },
                onToggleTag: { tagToggled = $0 }
            ),
            lifecycle: BatchLifecycleActions(
                onTrash: { trashed = true },
                onClear: { cleared = true }
            )
        )

        bar.onMoveToday()
        #expect(movedToday)

        bar.onMoveTomorrow()
        #expect(movedTomorrow)

        bar.onToggleDone(true)
        #expect(toggledDoneVal == true)

        bar.onSetProject(projID)
        #expect(projectSet == projID)

        bar.onToggleTag(tagID)
        #expect(tagToggled == tagID)

        bar.onTrash()
        #expect(trashed)

        bar.onClear()
        #expect(cleared)

        _ = bar.body
    }

    @Test func workspaceBatchActionBarLiveMutations() throws {
        let (_, context) = try makeContainer()
        let t1 = TodoItem(title: "Batch Todo 1", dayKey: "2026-09-08")
        let t2 = TodoItem(title: "Batch Todo 2", dayKey: "2026-09-08")
        let r1 = DailyRoutine(title: "Batch Routine 1", sortOrder: 0, createdDayKey: "2026-09-01")
        let proj = ProjectItem(name: "Batch Project", sortOrder: 0)
        let tag = TagItem(name: "BatchTag", sortOrder: 0)
        context.insert(t1)
        context.insert(t2)
        context.insert(r1)
        context.insert(proj)
        context.insert(tag)
        try context.save()

        let nav = WorkspaceNavigation.shared
        nav.selectedTaskIDs = [t1.id, t2.id, r1.id]

        let data = WorkspaceBatchData(
            todos: [t1, t2],
            routines: [r1],
            checks: [],
            projects: [proj],
            tags: [tag]
        )
        let actionBar = WorkspaceBatchActionBar(navigation: nav, data: data)
        _ = actionBar.body

        // Verify batch move
        DayBoardMutations.batchMoveTodos([t1.id, t2.id], to: "2026-09-09", todos: [t1, t2])
        #expect(t1.dayKey == "2026-09-09")
        #expect(t2.dayKey == "2026-09-09")

        // Verify batch toggle done
        DayBoardMutations.batchToggleDone([t1.id], markDone: true, todos: [t1, t2])
        #expect(t1.isDone == true)
        #expect(t2.isDone == false)

        // Verify batch project assignment
        DayBoardMutations.batchSetProject([t1.id, r1.id], projectID: proj.id, todos: [t1, t2], routines: [r1])
        #expect(t1.projectID == proj.id)
        #expect(r1.projectID == proj.id)
        #expect(t2.projectID == nil)

        // Verify batch tag assignment
        DayBoardMutations.batchToggleTag([t1.id, r1.id], tagID: tag.id, todos: [t1, t2], routines: [r1])
        #expect(TagIDList.contains(t1.tagIDs, tag.id))
        #expect(TagIDList.contains(r1.tagIDs, tag.id))
        #expect(!TagIDList.contains(t2.tagIDs, tag.id))

        // Verify batch trash
        DayBoardMutations.batchTrash([t1.id, r1.id], todos: [t1, t2], routines: [r1])
        #expect(t1.deletedAt != nil)
        #expect(r1.deletedAt != nil)
        #expect(t2.deletedAt == nil)

        // Clear selection
        nav.clearSelection()
        #expect(nav.selectedTaskIDs.isEmpty)
    }
}
