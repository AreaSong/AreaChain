import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct MilestoneM3Iteration2DTOStressTests {
    private func makeContainer() throws -> (ModelContainer, ModelContext) {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, ModelContext(container))
    }

    private func makeSampleState() -> TaskRowState {
        TaskRowState(
            identity: TaskRowIdentityState(
                title: "Original Title",
                priority: TaskPriorityFlags(isImportant: false, isUrgent: false)
            ),
            schedule: TaskRowScheduleState(todayKey: "2026-09-10", streak: 3),
            content: TaskRowContentState(note: "Note 1", notes: "Notes 1"),
            interaction: TaskRowInteractionState(
                selection: TaskRowSelectionState(isSelected: false, isExternalEditing: false),
                dragPayload: "payload-1"
            )
        )
    }

    // MARK: - 1. TaskRowState Bidirectional Property Forwarding

    @Test func taskRowStateIdentityAndScheduleForwarding() throws {
        var state = makeSampleState()

        state.title = "Updated Title"
        state.isDone = true
        state.isResident = true
        state.isImportant = true
        state.isUrgent = true
        state.todayKey = "2026-09-11"
        state.currentDayKey = "2026-09-12"
        state.remindMinutes = 45
        state.weekdaysOnly = true
        state.streak = 10

        #expect(state.identity.title == "Updated Title")
        #expect(state.identity.isDone == true)
        #expect(state.identity.isResident == true)
        #expect(state.identity.priority.isImportant == true)
        #expect(state.identity.priority.isUrgent == true)
        #expect(state.identity.isImportant == true)
        #expect(state.identity.isUrgent == true)

        #expect(state.schedule.todayKey == "2026-09-11")
        #expect(state.schedule.currentDayKey == "2026-09-12")
        #expect(state.schedule.remindMinutes == 45)
        #expect(state.schedule.weekdaysOnly == true)
        #expect(state.schedule.streak == 10)

        // Inverse mutation
        state.identity.priority = TaskPriorityFlags(isImportant: false, isUrgent: true)
        #expect(state.isImportant == false)
        #expect(state.isUrgent == true)
        state.schedule.streak = 99
        #expect(state.streak == 99)
    }

    @Test func taskRowStateInteractionAndInverseForwarding() throws {
        var state = makeSampleState()

        state.note = "Updated Note"
        state.notes = "Updated Notes"
        state.isSelected = true
        state.isExternalEditing = true
        state.dragPayload = "payload-updated"
        state.canSetRemind = true
        state.canSkip = true
        state.isEnabled = false

        #expect(state.content.note == "Updated Note")
        #expect(state.content.notes == "Updated Notes")
        #expect(state.interaction.selection.isSelected == true)
        #expect(state.interaction.selection.isExternalEditing == true)
        #expect(state.interaction.isSelected == true)
        #expect(state.interaction.isExternalEditing == true)
        #expect(state.interaction.dragPayload == "payload-updated")
        #expect(state.interaction.canSetRemind == true)
        #expect(state.interaction.canSkip == true)
        #expect(state.interaction.isEnabled == false)

        // Inverse mutation
        state.interaction.selection = TaskRowSelectionState(isSelected: false, isExternalEditing: false)
        #expect(state.isSelected == false)
        #expect(state.isExternalEditing == false)
    }

    @Test func taskRowStateContentSubtasksAndContextForwarding() throws {
        let parentID = UUID()
        let sub1 = SubtaskSnapshot(id: UUID(), todoId: parentID, title: "Sub 1", isDone: false, sortOrder: 0)
        let sub2 = SubtaskSnapshot(id: UUID(), todoId: parentID, title: "Sub 2", isDone: true, sortOrder: 1)
        var state = TaskRowState(identity: TaskRowIdentityState(title: "Task With Subtasks"))

        state.subtasks = [sub1, sub2]
        #expect(state.content.subtasks.count == 2)
        #expect(state.subtasks[0].title == "Sub 1")
        #expect(state.subtasks[1].isDone == true)

        let attachContext = TaskAttachmentContext(items: [], onPickFile: {}, onPaste: {})
        state.attachments = attachContext
        #expect(state.content.attachments != nil)
        #expect(state.attachments != nil)

        let classifyActions = TaskClassifyActions(
            onProject: { _ in }, onToggleTag: { _ in }, onImportant: { _ in }, onUrgent: { _ in }
        )
        let classifyContext = TaskClassifyContext(
            priority: TaskPriorityFlags(isImportant: true, isUrgent: false),
            catalog: TaskCatalogBinding(tagIDs: "tag-1"),
            actions: classifyActions
        )
        state.classify = classifyContext
        #expect(state.content.classify?.isImportant == true)
        #expect(state.classify?.tagIDs == "tag-1")
    }

    @Test func taskRowStateValueSemanticsAndEquatableStress() throws {
        let base = TaskRowState(
            identity: TaskRowIdentityState(title: "Immutable Base"),
            schedule: TaskRowScheduleState(streak: 5)
        )

        var copy = base
        copy.isImportant = true
        copy.streak = 6

        #expect(base.isImportant == false)
        #expect(base.streak == 5)
        #expect(copy.isImportant == true)
        #expect(copy.streak == 6)
        #expect(base != copy)

        let clone = TaskRowState(
            identity: TaskRowIdentityState(id: base.id, title: "Immutable Base"),
            schedule: TaskRowScheduleState(streak: 5)
        )
        #expect(base == clone)
    }

    // MARK: - 2. TaskClassifyContext Sub-DTO Forwarding & Callbacks

    @Test func taskClassifyContextForwardingAndPriorityToggles() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "Priority Target", dayKey: "2026-09-10")
        context.insert(todo)
        try context.save()

        var classify = CatalogChoices.classify(for: todo, projects: [], tags: [])
        #expect(classify.isImportant == false)
        #expect(classify.isUrgent == false)
        #expect(classify.priority.isImportant == false)

        classify.onImportant(true)
        #expect(todo.isImportant == true)

        classify.onUrgent(true)
        #expect(todo.isUrgent == true)

        classify = CatalogChoices.classify(for: todo, projects: [], tags: [])
        #expect(classify.isImportant == true)
        #expect(classify.isUrgent == true)
        #expect(classify.priority.isImportant == true)
        #expect(classify.priority.isUrgent == true)
    }

    @Test func taskClassifyContextCatalogAndProjectActions() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "Catalog Target", dayKey: "2026-09-10")
        let project = ProjectItem(name: "Engineering", sortOrder: 0)
        let tag = TagItem(name: "Core", sortOrder: 0)
        context.insert(todo)
        context.insert(project)
        context.insert(tag)
        try context.save()

        let classify = CatalogChoices.classify(for: todo, projects: [project], tags: [tag])
        #expect(classify.projectID == nil)
        #expect(classify.tagIDs == "")
        #expect(classify.projects.count == 1)
        #expect(classify.tags.count == 1)

        classify.onProject(project.id)
        #expect(todo.projectID == project.id)

        classify.onToggleTag(tag.id)
        #expect(TagIDList.contains(todo.tagIDs, tag.id))

        classify.onToggleTag(tag.id)
        #expect(!TagIDList.contains(todo.tagIDs, tag.id))

        classify.onProject(nil)
        #expect(todo.projectID == nil)
    }

    // MARK: - 3. DayBoardListConfig & TasksPageConfig Interaction Closures

    @Test func dayBoardListConfigInteractionForwarding() throws {
        var boundID: UUID? = UUID()
        let binding = Binding<UUID?>(get: { boundID }, set: { boundID = $0 })
        let highlightID = UUID()
        var inspectedID: UUID?
        var returnCalled = false

        let interaction = DayBoardInteraction(
            focusedTaskID: binding,
            highlightedTaskID: highlightID,
            onInspect: { inspectedID = $0 },
            onReturnToInput: { returnCalled = true }
        )
        let listConfig = DayBoardListConfig(
            todayKey: "2026-09-10",
            allowsTodoDrag: true,
            interaction: interaction
        )

        #expect(listConfig.focusedTaskID?.wrappedValue == boundID)
        #expect(listConfig.highlightedTaskID == highlightID)
        #expect(listConfig.allowsTodoDrag == true)

        let newTargetID = UUID()
        listConfig.focusedTaskID?.wrappedValue = newTargetID
        #expect(boundID == newTargetID)

        listConfig.onInspect?(newTargetID)
        #expect(inspectedID == newTargetID)

        listConfig.onReturnToInput?()
        #expect(returnCalled)
    }

    @Test func tasksPageConfigInteractionForwarding() throws {
        let highlightID = UUID()
        var inspectedID: UUID?
        var returnCalled = false

        let interaction = DayBoardInteraction(
            highlightedTaskID: highlightID,
            onInspect: { inspectedID = $0 },
            onReturnToInput: { returnCalled = true }
        )
        let pageConfig = TasksPageConfig(
            yesterdayKey: "2026-09-09",
            maxScrollHeight: 600,
            interaction: interaction
        )

        #expect(pageConfig.highlightedTaskID == highlightID)
        #expect(pageConfig.maxScrollHeight == 600)

        pageConfig.onInspect?(highlightID)
        #expect(inspectedID == highlightID)

        pageConfig.onReturnToInput?()
        #expect(returnCalled)
    }

    @Test func dayBoardListSelectionAndInspectExecution() throws {
        let (_, context) = try makeContainer()
        let todo = TodoItem(title: "Target Todo", dayKey: "2026-09-10")
        context.insert(todo)
        try context.save()

        var boundID: UUID?
        let binding = Binding<UUID?>(get: { boundID }, set: { boundID = $0 })
        var inspectedID: UUID?

        let config = DayBoardListConfig(
            todayKey: "2026-09-10",
            interaction: DayBoardInteraction(
                focusedTaskID: binding,
                onInspect: { inspectedID = $0 }
            )
        )
        let list = DayBoardList(
            dayKey: "2026-09-10",
            routines: [],
            checks: [],
            todos: [todo],
            config: config
        )

        list.selectTask(todo.id)
        #expect(boundID == todo.id)
        #expect(inspectedID == todo.id)
        #expect(BoardSelection.shared.inspectingDayKey == "2026-09-10")

        inspectedID = nil
        list.inspectSelected(id: todo.id)
        #expect(inspectedID == todo.id)
    }

    // MARK: - 4. Sub-DTO Configuration Cards (StreakCardConfig & LeftoverChipsBarConfig)

    @Test func streakCardConfigStateMapping() {
        let streak = StreakResult(currentStreak: 4, bestStreak: 12)

        let pausedConfig = StreakCardConfig(
            streakResult: streak,
            isEnabled: false,
            inspectDayKey: "2026-09-10",
            flags: StreakInspectionFlags(isCompleted: false, isSkipped: false, isDue: true)
        )
        #expect(pausedConfig.isEnabled == false)
        #expect(pausedConfig.streakResult.currentStreak == 4)

        let completedConfig = StreakCardConfig(
            streakResult: streak,
            isEnabled: true,
            inspectDayKey: "2026-09-10",
            flags: StreakInspectionFlags(isCompleted: true, isSkipped: false, isDue: true)
        )
        #expect(completedConfig.flags.isCompleted == true)
        #expect(completedConfig.flags.isSkipped == false)

        let skippedConfig = StreakCardConfig(
            streakResult: streak,
            isEnabled: true,
            inspectDayKey: "2026-09-10",
            flags: StreakInspectionFlags(isCompleted: false, isSkipped: true, isDue: true)
        )
        #expect(skippedConfig.flags.isSkipped == true)
    }

    @Test func leftoverChipsBarConfigTogglePreservation() {
        var yesterdayToggled = false
        var upcomingToggled = false

        let config = LeftoverChipsBarConfig(
            yesterday: LeftoverChipState(
                count: 3,
                isExpanded: false,
                onToggle: { yesterdayToggled = true }
            ),
            upcoming: LeftoverChipState(
                count: 7,
                isExpanded: true,
                onToggle: { upcomingToggled = true }
            )
        )

        #expect(config.yesterday.count == 3)
        #expect(config.yesterday.isExpanded == false)
        #expect(config.upcoming.count == 7)
        #expect(config.upcoming.isExpanded == true)

        config.yesterday.onToggle()
        #expect(yesterdayToggled)

        config.upcoming.onToggle()
        #expect(upcomingToggled)
    }
}
