import AppKit
import Foundation
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
        navigation.searchQuery = "报告"
        #expect(navigation.todayDraft == "还没提交")
        #expect(navigation.pendingLaneSession?.lane == .upcoming)
        #expect(navigation.pendingFilter.tagID != nil)
        navigation.searchQuery = ""
        #expect(navigation.pendingLaneSession?.lane == .upcoming)

        navigation.revealTab(.allItems)
        navigation.allItemsQuery.kind = .recurring
        navigation.allItemsQuery.routineStatus = .disabled
        navigation.searchQuery = "标签"
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
}
