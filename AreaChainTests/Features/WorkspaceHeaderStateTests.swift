import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct WorkspaceHeaderStateTests {
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
        navigation.searchQuery = "example"
        #expect(navigation.supportsTaskInspector && !navigation.canInspectSelectedTask)
        navigation.updateInspectorTargets([task])
        navigation.inspectTask(task)
        #expect(navigation.canInspectSelectedTask)
        navigation.updateInspectorTargets([])
        #expect(navigation.selectedTaskID == nil && !navigation.isInspectorPresented)
        navigation.clearSearch()
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

    @Test func searchUsesParentTasksAndAttachmentOwnersWithoutDiaryTargets() {
        let parent = UUID()
        let child = UUID()
        let diary = UUID()
        let taskFile = AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: parent, filename: "a.png")
        let page = WorkspaceSearchPageModel(hits: [
            BoardSearchHit(id: child, kind: .subtask, title: "child", dayKey: "2026-10-01", createdAt: .now, parentID: parent),
            BoardSearchHit(id: diary, kind: .diary, title: "note", dayKey: "2026-10-01", createdAt: .now)
        ], matchingAttachments: [taskFile])
        #expect(Set(page.inspectorIDs) == [parent])
    }

    @Test func searchPreservesExistingTodayAndFilterLifetimes() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        navigation.revealTab(.today)
        navigation.todayDraft = "草稿 #工作"
        navigation.searchQuery = "其他"
        navigation.clearSearch()
        #expect(navigation.todayDraft == "草稿 #工作")
        navigation.revealTab(.pending)
        navigation.pendingLaneSession = PendingLaneSession(overdueCount: 2)
        navigation.pendingFilter.tagID = UUID()
        let tag = navigation.pendingFilter.tagID
        navigation.searchQuery = "内容"
        navigation.clearSearch()
        #expect(navigation.pendingLaneSession != nil && navigation.pendingFilter.tagID == tag)
        navigation.revealTab(.settings)
        #expect(navigation.pendingLaneSession == nil && navigation.pendingFilter.tagID == nil)
    }
}
