import AppKit
import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct WorkspaceItemsPageTests {
    @Test func navigationOpensPendingAndAllItemsWithoutPinningToday() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        navigation.revealTab(.pending)
        #expect(navigation.selectedTab == .pending)
        #expect(!InspectDayPolicy.pinsTodayWhenEntering(.pending))
        #expect(!InspectDayPolicy.pinsTodayWhenEntering(.allItems))
        #expect(InspectDayPolicy.pinsTodayWhenEntering(.today))
        navigation.revealTab(.allItems)
        #expect(navigation.selectedTab == .allItems)
        navigation.revealTab(.today)
        #expect(navigation.selectedTab == .today)
    }

    @Test func overdueInspectionKeepsTheRealCheckDay() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let id = UUID()
        navigation.revealTab(.pending)
        navigation.inspectTask(id, dayKey: "2026-09-06")
        #expect(navigation.selectedTaskID == id)
        #expect(navigation.inspectingDayKey == "2026-09-06")
        #expect(navigation.isInspectorPresented)
        navigation.revealTab(.allItems)
        navigation.inspectTask(id, dayKey: "2026-09-07")
        #expect(navigation.inspectingDayKey == "2026-09-07")
    }

    @Test func hiddenSelectionIsRemovedWhenTheLaneChanges() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let visible = [UUID(), UUID()]
        navigation.selectedTaskIDs = [visible[0], UUID()]
        navigation.reconcileTaskSelection(with: visible)
        #expect(navigation.selectedTaskIDs == [visible[0]])
        navigation.reconcileTaskSelection(with: [])
        #expect(navigation.selectedTaskIDs.isEmpty)
    }

    @Test func hiddenFocusClosesTheInspector() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let visible = UUID()
        let hidden = UUID()
        navigation.selectedTaskID = hidden
        navigation.selectedTaskIDs = [visible, hidden]
        navigation.isInspectorPresented = true
        navigation.reconcileTaskSelection(with: [visible])
        #expect(navigation.selectedTaskIDs == [visible])
        #expect(navigation.selectedTaskID == nil)
        #expect(!navigation.isInspectorPresented)
    }

    @Test func escapeClearsSelectionWithoutDeleting() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        navigation.selectedTaskIDs = [UUID()]
        navigation.clearSelection()
        #expect(navigation.selectedTaskIDs.isEmpty)
    }

    @Test func listedPagesHideCompletionUnlessTheRowCanBeChecked() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let due = UUID()
        let upcoming = UUID()
        navigation.replaceListedCheckDays([due: "2026-09-01"])
        #expect(navigation.allowsRoutineCompletion(due))
        #expect(!navigation.allowsRoutineCompletion(upcoming))
        navigation.clearListedCheckDays()
        #expect(navigation.allowsRoutineCompletion(upcoming))
    }

    @Test func pendingLaneChoiceSurvivesCountChangesUntilLeave() {
        var session = PendingLaneSession(overdueCount: 0)
        #expect(session.lane == .upcoming)
        session.choose(.overdue)
        session.refreshDefault(overdueCount: 3)
        #expect(session.lane == .overdue)
        session = PendingLaneSession(overdueCount: 3)
        #expect(session.lane == .overdue)
    }

    @Test func searchKeepsPageMemoryUntilThePageIsActuallyLeft() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        navigation.todayDraft = "还没提交"
        navigation.revealTab(.pending)
        var lane = PendingLaneSession(overdueCount: 2)
        lane.choose(.upcoming)
        navigation.pendingLaneSession = lane
        navigation.pendingFilter.tagID = UUID()
        navigation.searchPresentation = true
        #expect(navigation.todayDraft == "还没提交")
        #expect(navigation.pendingLaneSession?.lane == .upcoming)
        #expect(navigation.pendingFilter.tagID != nil)
        navigation.searchPresentation = false
        #expect(navigation.pendingLaneSession?.lane == .upcoming)

        navigation.revealTab(.allItems)
        navigation.allItemsQuery.kind = .recurring
        navigation.allItemsQuery.routineStatus = .disabled
        navigation.searchPresentation = true
        #expect(navigation.allItemsQuery.kind == .recurring)
        #expect(navigation.pendingLaneSession == nil)
        #expect(navigation.pendingFilter == BoardFilter())

        navigation.selectedTagID = UUID()
        #expect(navigation.allItemsQuery.kind == .all)
        #expect(navigation.allItemsQuery.routineStatus == .all)
        navigation.revealTab(.calendar)
        #expect(navigation.todayDraft == "还没提交")
    }

    @Test func itemsListLeavesControlsAndEmptySelectionAlone() {
        let button = NSButton()
        let editor = NSTextView()
        #expect(!ItemsListKeyRouting.responderClaimsKeys(button))
        #expect(!ItemsListKeyRouting.responderClaimsKeys(editor))
        #expect(ItemsListKeyRouting.responderClaimsKeys(NSView()))
        #expect(ItemsListKeyRouting.responderClaimsKeys(nil))

        let idle = ItemsListKeyContext(
            responderClaimsKeys: true,
            hasRows: true,
            hasSelection: false,
            hasMultiSelection: false,
            inspectorPresented: false
        )
        #expect(ItemsListKeyRouting.consumes(ItemsListKey.arrowDown, context: idle))
        #expect(!ItemsListKeyRouting.consumes(ItemsListKey.space, context: idle))
        #expect(!ItemsListKeyRouting.consumes(ItemsListKey.escape, context: idle))

        var focusedControl = idle
        focusedControl.responderClaimsKeys = false
        focusedControl.hasSelection = true
        #expect(!ItemsListKeyRouting.consumes(ItemsListKey.space, context: focusedControl))
        #expect(!ItemsListKeyRouting.consumes(ItemsListKey.arrowDown, context: focusedControl))

        var selected = idle
        selected.hasSelection = true
        #expect(ItemsListKeyRouting.consumes(ItemsListKey.space, context: selected))
        #expect(ItemsListKeyRouting.consumes(ItemsListKey.escape, context: selected))

        var empty = idle
        empty.hasRows = false
        #expect(!ItemsListKeyRouting.consumes(ItemsListKey.arrowDown, context: empty))
    }

    @Test func listIdentityLooksUpByIDAndKeepsFirstCheck() throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let today = "2026-09-07"
        let todo = TodoItem(title: "一次性", dayKey: today)
        let routine = DailyRoutine(title: "习惯", sortOrder: 0, createdDayKey: "2026-09-01")
        let openFirst = RoutineCheck(dayKey: today, isDone: false, routine: routine)
        let laterDone = RoutineCheck(dayKey: today, isDone: true, routine: routine)
        context.insert(todo)
        context.insert(routine)
        context.insert(openFirst)
        context.insert(laterDone)
        let groups = [
            WorkspaceItemGroup(
                id: "mix",
                title: nil,
                entries: [
                    .todo(todo, checkDayKey: today, subtaskIDs: nil),
                    .routine(routine, checkDayKey: today, allowsCompletion: true, overdueCount: 0, noteDayKey: nil)
                ]
            )
        ]
        let identity = WorkspaceItemsListIdentity.make(
            groups: groups,
            todayKey: today,
            checks: [openFirst, laterDone],
            tags: [],
            attachments: [],
            context: context,
            locale: Locale(identifier: "zh-Hans")
        )
        #expect(identity.entry(todo.id)?.modelID == todo.id)
        #expect(identity.entry(routine.id)?.modelID == routine.id)
        #expect(identity.entryIDs == [todo.id, routine.id])
        let snaps = [openFirst, laterDone].compactMap(\.snapshot)
        #expect(
            identity.checkIndex.isClosed(routineId: routine.id, dayKey: today)
                == DayBoardLogic.isRoutineDone(routine.snapshot, checks: snaps, on: today)
        )
        #expect(!identity.checkIndex.isClosed(routineId: routine.id, dayKey: today))
        #expect(identity.routineLookups(for: routine.id).currentStreak != nil)
    }

    @Test func filteredListOpenCountMatchesCatalogWithoutRescanningRows() throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let today = DayClock.shared.todayKey
        let tag = TagItem(name: "工作", sortOrder: 0)
        let encoded = tag.id.uuidString
        let openTodo = TodoItem(title: "未完成", dayKey: today, tagIDs: encoded)
        let doneTodo = TodoItem(title: "已完成", isDone: true, dayKey: today, tagIDs: encoded)
        let due = DailyRoutine(title: "该打", sortOrder: 0, createdDayKey: "2026-01-01", tagIDs: encoded)
        let doneHabit = DailyRoutine(title: "打完", sortOrder: 1, createdDayKey: "2026-01-01", tagIDs: encoded)
        let check = RoutineCheck(dayKey: today, isDone: true, routine: doneHabit)
        let parent = TodoItem(title: "父", dayKey: today)
        let openSub = SubtaskItem(title: "开子", tagIDs: encoded, todo: parent)
        parent.subtasks = [openSub]
        context.insert(tag)
        context.insert(openTodo)
        context.insert(doneTodo)
        context.insert(due)
        context.insert(doneHabit)
        context.insert(check)
        context.insert(parent)
        context.insert(openSub)
        let todos = [openTodo, doneTodo, parent]
        let routines = [due, doneHabit]
        let checks = [check]
        let model = WorkspaceFilteredListModel.make(
            tag: tag,
            todos: todos,
            routines: routines,
            checks: checks,
            catalogs: TaskCatalogContext(tags: [tag], attachments: [], context: context),
            locale: Locale(identifier: "zh-Hans"),
            showCompleted: false
        )
        #expect(
            model.openCount
                == Catalog.openCount(todos: todos, routines: routines, checks: checks, tag: tag, dayKey: today)
        )
        #expect(model.orderedVisibleIDs == model.openRows.map(\.id))
        #expect(model.openRows.contains { $0.id == openTodo.id })
        #expect(!model.orderedVisibleIDs.contains(doneTodo.id))
        #expect(model.checkIndex.isClosed(routineId: doneHabit.id, dayKey: today))
        #expect(!model.checkIndex.isClosed(routineId: due.id, dayKey: today))
    }

    @Test func sidebarBadgesShareSnapshotsWithoutMixingClosureRules() {
        let today = "2026-09-07"
        let todo = TodoItem(title: "今天", dayKey: today)
        let routine = DailyRoutine(title: "习惯", sortOrder: 0, createdDayKey: "2026-09-01")
        let badges = WorkspaceSidebarBadges.make(
            routines: [routine],
            checks: [],
            todos: [todo],
            todayKey: today
        )
        let routineSnaps = [routine.snapshot]
        let todoSnaps = [todo.snapshot]
        let todayCount = DayBoardLogic.todayBadgeCount(
            routines: routineSnaps, checks: [], todos: todoSnaps, dayKey: today
        )
        let pending = AgendaProjection.pending(
            routines: routineSnaps, checks: [], todos: todoSnaps, todayKey: today
        )
        #expect(badges.todayUnfinished == (todayCount > 0 ? todayCount : nil))
        #expect(badges.pending == (pending.overdueCount + pending.upcomingCount > 0
            ? pending.overdueCount + pending.upcomingCount : nil))
    }

    @Test func allItemsModelInvalidatesCacheWhenItemIsSoftDeleted() {
        let today = "2026-10-13"
        let nav = WorkspaceNavigation(boardSelection: BoardSelection())
        nav.allItemsQuery = ItemsListingQuery(todayKey: today)
        let todo = TodoItem(title: "测试事项", dayKey: today)
        let routine = DailyRoutine(title: "测试习惯", sortOrder: 0, createdDayKey: today)
        let locale = Locale(identifier: "zh-Hans")

        let model1 = WorkspaceAllItemsPageModel.make(
            routines: [routine],
            todos: [todo],
            checks: [],
            todayKey: today,
            navigation: nav,
            locale: locale
        )
        #expect(model1.visibleIDs.contains(todo.id))
        #expect(model1.visibleIDs.contains(routine.id))

        todo.deletedAt = Date()
        let model2 = WorkspaceAllItemsPageModel.make(
            routines: [routine],
            todos: [todo],
            checks: [],
            todayKey: today,
            navigation: nav,
            locale: locale
        )
        #expect(!model2.visibleIDs.contains(todo.id))
        #expect(model2.visibleIDs.contains(routine.id))

        routine.deletedAt = Date()
        let model3 = WorkspaceAllItemsPageModel.make(
            routines: [routine],
            todos: [todo],
            checks: [],
            todayKey: today,
            navigation: nav,
            locale: locale
        )
        #expect(!model3.visibleIDs.contains(todo.id))
        #expect(!model3.visibleIDs.contains(routine.id))
    }

    @Test func batchTrashRemovesAllSelectedTasks() throws {
        let container = try ModelContainer(
            for: TodoItem.self, DailyRoutine.self, RoutineCheck.self, TagItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let today = "2026-10-13"
        let todo1 = TodoItem(title: "事项1", dayKey: today)
        let todo2 = TodoItem(title: "事项2", dayKey: today)
        let routine1 = DailyRoutine(title: "习惯1", sortOrder: 0, createdDayKey: today)
        context.insert(todo1)
        context.insert(todo2)
        context.insert(routine1)
        try context.save()

        let selectedIDs: Set<UUID> = [todo1.id, todo2.id, routine1.id]
        let result = DayBoardMutations.batchTrash(selectedIDs, todos: [todo1, todo2], routines: [routine1])
        #expect(result)
        #expect(todo1.deletedAt != nil)
        #expect(todo2.deletedAt != nil)
        #expect(routine1.deletedAt != nil)

        let nav = WorkspaceNavigation(boardSelection: BoardSelection())
        nav.allItemsQuery = ItemsListingQuery(todayKey: today)
        let model = WorkspaceAllItemsPageModel.make(
            routines: [routine1],
            todos: [todo1, todo2],
            checks: [],
            todayKey: today,
            navigation: nav,
            locale: Locale(identifier: "zh-Hans")
        )
        #expect(model.visibleIDs.isEmpty)
    }
}
