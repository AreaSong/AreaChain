import Foundation
import Testing
@testable import AreaChain

struct InspectDayPolicyTests {
    @Test func pinsTodayOnFilteredListsOnly() {
        #expect(!InspectDayPolicy.pinsTodayWhenInspecting(tab: .dashboard, projectID: nil, tagID: nil))
        #expect(InspectDayPolicy.pinsTodayWhenInspecting(tab: .today, projectID: UUID(), tagID: nil))
        #expect(InspectDayPolicy.pinsTodayWhenInspecting(tab: .today, projectID: nil, tagID: UUID()))
        #expect(!InspectDayPolicy.pinsTodayWhenInspecting(tab: .today, projectID: nil, tagID: nil))
        #expect(!InspectDayPolicy.pinsTodayWhenInspecting(tab: .calendar, projectID: nil, tagID: nil))
        #expect(!InspectDayPolicy.pinsTodayWhenInspecting(tab: .search, projectID: nil, tagID: nil))
    }

    @Test func pinsTodayWhenEnteringTodayOnly() {
        #expect(InspectDayPolicy.pinsTodayWhenEntering(.today))
        #expect(!InspectDayPolicy.pinsTodayWhenEntering(.dashboard))
        #expect(!InspectDayPolicy.pinsTodayWhenEntering(.pending))
        #expect(!InspectDayPolicy.pinsTodayWhenEntering(.calendar))
        #expect(!InspectDayPolicy.pinsTodayWhenEntering(.quadrant))
        #expect(!InspectDayPolicy.pinsTodayWhenEntering(.gantt))
    }

    @Test @MainActor func newWorkspaceOpensDashboardAndEnteringTodayPinsTheDay() {
        let board = BoardSelection.shared
        let previous = board.inspectingDayKey
        defer { board.inspectBoard(previous) }

        let nav = WorkspaceNavigation()
        #expect(nav.selectedTab == .dashboard)
        board.inspectBoard("2026-01-01")
        nav.selectedTab = .today
        #expect(board.inspectingDayKey == DayClock.shared.todayKey)

        board.inspectBoard("2026-01-01")
        nav.selectedTab = .dashboard
        nav.inspectTask(UUID())
        #expect(board.inspectingDayKey == "2026-01-01")
        #expect(nav.isInspectorPresented)
    }

    @Test @MainActor func inspectTaskOnTodayKeepsCallerDay() {
        let board = BoardSelection.shared
        let previous = board.inspectingDayKey
        defer { board.inspectBoard(previous) }

        let nav = WorkspaceNavigation()
        board.inspectBoard("2026-01-01")
        nav.inspectTask(UUID())
        #expect(board.inspectingDayKey == "2026-01-01")
    }

    @Test @MainActor func selectingProjectPinsToday() {
        let board = BoardSelection.shared
        let previous = board.inspectingDayKey
        defer { board.inspectBoard(previous) }

        let nav = WorkspaceNavigation()
        nav.selectedTab = .calendar
        board.inspectBoard("2026-01-01")
        nav.selectedProjectID = UUID()
        #expect(board.inspectingDayKey == DayClock.shared.todayKey)
        nav.inspectTask(UUID())
        #expect(board.inspectingDayKey == DayClock.shared.todayKey)
    }
}
