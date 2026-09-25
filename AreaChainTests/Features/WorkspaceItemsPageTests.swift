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

    @Test func escapeClearsSelectionWithoutDeleting() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        navigation.selectedTaskIDs = [UUID()]
        navigation.clearSelection()
        #expect(navigation.selectedTaskIDs.isEmpty)
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
}
