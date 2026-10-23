import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct WorkspaceHeaderStateTests {
    @Test func spaceOnlyClosesPresentationAndNeverRestoresInvalidTargets() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let id = UUID()
        navigation.revealTab(.calendar)
        navigation.updateInspectorTargets([id])
        navigation.inspectTask(id, dayKey: "2026-10-03")
        navigation.updateInspectorSpace(available: false)
        #expect(!navigation.isInspectorPresented && !navigation.canPresentInspector)
        #expect(navigation.selectedTaskID == id && navigation.inspectingDayKey == "2026-10-03")
        #expect(navigation.canInspectSelectedTask)
        navigation.inspectTask(id, dayKey: "2026-10-03")
        #expect(!navigation.isInspectorPresented)
        navigation.updateInspectorSpace(available: true)
        #expect(!navigation.isInspectorPresented && navigation.canPresentInspector)
        navigation.isInspectorPresented = true
        #expect(navigation.isInspectorPresented)
        navigation.searchPresentation = true
        #expect(navigation.selectedTaskID == nil && !navigation.canPresentInspector)
        navigation.updateInspectorSpace(available: false)
        navigation.updateInspectorSpace(available: true)
        #expect(!navigation.isInspectorPresented && !navigation.canPresentInspector)
    }

    @Test func staleSelectionCannotEnableAnotherContentInspector() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let task = UUID()
        navigation.revealTab(.today)
        navigation.updateInspectorTargets([task])
        navigation.inspectTask(task)
        #expect(navigation.canInspectSelectedTask && navigation.isInspectorPresented)
        navigation.closeInspector()
        #expect(navigation.canInspectSelectedTask)
        navigation.revealTab(.settings)
        #expect(!navigation.supportsTaskInspector && !navigation.isInspectorPresented)
        navigation.selectedTaskID = task
        #expect(!navigation.canInspectSelectedTask)
        navigation.searchPresentation = true
        #expect(navigation.supportsTaskInspector && !navigation.canInspectSelectedTask)
        navigation.updateInspectorTargets([task])
        navigation.inspectTask(task)
        #expect(navigation.canInspectSelectedTask)
        navigation.updateInspectorTargets([])
        #expect(navigation.selectedTaskID == nil && !navigation.isInspectorPresented)
        navigation.searchPresentation = nil
        #expect(navigation.selectedTab == .settings && !navigation.supportsTaskInspector)
    }

    @Test func allRoutesDeclareOnlyTheirTaskCapability() {
        let allowed: Set<WorkspaceTab> = [.today, .pending, .allItems, .calendar, .gantt, .quadrant]
        for tab in WorkspaceTab.allCases {
            #expect(tab.supportsTaskInspector == allowed.contains(tab))
        }
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        navigation.selectedTagID = UUID()
        #expect(navigation.supportsTaskInspector)
        #expect(!navigation.canInspectSelectedTask)
    }

    @Test func searchPreservesExistingTodayAndFilterLifetimes() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        navigation.revealTab(.today)
        navigation.todayDraft = "草稿 #工作"
        navigation.searchPresentation = true
        navigation.searchPresentation = nil
        #expect(navigation.todayDraft == "草稿 #工作")
        navigation.revealTab(.pending)
        navigation.pendingLaneSession = PendingLaneSession(overdueCount: 2)
        navigation.pendingFilter.tagID = UUID()
        let tag = navigation.pendingFilter.tagID
        navigation.searchPresentation = true
        navigation.searchPresentation = nil
        #expect(navigation.pendingLaneSession != nil && navigation.pendingFilter.tagID == tag)
        navigation.revealTab(.settings)
        #expect(navigation.pendingLaneSession == nil && navigation.pendingFilter.tagID == nil)
    }
}
