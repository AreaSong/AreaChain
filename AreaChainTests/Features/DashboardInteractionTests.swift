import Foundation
import Testing
@testable import AreaChain

@MainActor
struct DashboardInteractionTests {
    @Test func summaryRoutesUseTodayAndPending() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection(now: date("2026-09-25T00:00:00Z")))
        DashboardNavigation.openToday(navigation)
        #expect(navigation.selectedTab == .today)
        DashboardNavigation.openPending(navigation, lane: .overdue)
        #expect(navigation.selectedTab == .pending)
        #expect(navigation.pendingLaneSession?.lane == .overdue)
        #expect(navigation.pendingLaneSession?.userChose == true)
    }

    @Test func upcomingMetricKeepsTheUpcomingLaneWhenOverdueExists() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection(now: date("2026-09-25T00:00:00Z")))
        DashboardNavigation.openPending(navigation, lane: .upcoming)
        #expect(navigation.selectedTab == .pending)
        var session = navigation.pendingLaneSession
        #expect(session?.lane == .upcoming)
        session?.refreshDefault(overdueCount: 4)
        #expect(session?.lane == .upcoming)
    }

    @Test func heatmapPaddingDoesNotMoveTheCalendar() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection(now: date("2026-09-25T00:00:00Z")))
        let original = navigation.inspectingDayKey
        DashboardNavigation.openCalendar(dayKey: "pad-0", isPadding: true, navigation: navigation)
        #expect(navigation.selectedTab == .dashboard)
        #expect(navigation.inspectingDayKey == original)
        DashboardNavigation.openCalendar(dayKey: "2026-08-03", isPadding: false, navigation: navigation)
        #expect(navigation.selectedTab == .calendar)
        #expect(navigation.inspectingDayKey == "2026-08-03")
    }

    @Test func activityRoutesOpenTheMatchingSurface() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection(now: date("2026-09-25T00:00:00Z")))
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        DashboardNavigation.open(
            .inspectItem(id: id, dayKey: "2026-09-20", kind: .todo),
            navigation: navigation
        )
        #expect(navigation.selectedTab == .calendar)
        #expect(navigation.selectedTaskID == id)
        #expect(navigation.inspectingDayKey == "2026-09-20")
        #expect(navigation.isInspectorPresented)
        let diaryID = UUID(uuidString: "22222222-2222-3333-4444-555555555555")!
        DashboardNavigation.open(.openDiary(id: diaryID), navigation: navigation)
        #expect(navigation.selectedTab == .calendar)
        DashboardNavigation.open(.focusTrash(id: diaryID), navigation: navigation)
        #expect(navigation.selectedTab == .trash)
        #expect(navigation.focusedTrashID == diaryID)
    }

    @Test func heatmapLayoutChunksWeeksAndIgnoresPaddingCompletions() {
        #expect(DashboardHeatmapLayout.columns(from: []).isEmpty)
        #expect(!DashboardHeatmapLayout.hasCompletions([]))
        let padding = heatmapDay("pad-0", completed: 3, padding: true)
        let empty = heatmapDay("2026-09-01", completed: 0, padding: false)
        let done = heatmapDay("2026-09-02", completed: 2, padding: false)
        #expect(!DashboardHeatmapLayout.hasCompletions([padding, empty]))
        #expect(DashboardHeatmapLayout.hasCompletions([padding, done]))
        let cells = (0..<14).map { index in
            heatmapDay(String(format: "2026-09-%02d", index + 1), completed: 0, padding: false)
        }
        let columns = DashboardHeatmapLayout.columns(from: cells)
        #expect(columns.count == 2)
        #expect(columns[0].count == 7)
        #expect(columns[1].count == 7)
        #expect(columns[0].first?.dayKey == "2026-09-01")
        #expect(columns[1].first?.dayKey == "2026-09-08")
    }

    @Test func dashboardCopyResolvesInEnglishAndChinese() {
        for identifier in ["en", "zh-Hans"] {
            let locale = Locale(identifier: identifier)
            for key in [
                "dashboard.title", "dashboard.today.title", "dashboard.today.accessibility",
                "dashboard.today.skipNote",
                "dashboard.pending.overdue",
                "dashboard.heatmap.title", "dashboard.heatmap.empty", "dashboard.activity.empty",
                "dashboard.activity.kind.completed", "dashboard.heatmap.hint"
            ] {
                let value = L10n.string(String.LocalizationValue(key), locale: locale)
                #expect(value != key)
                #expect(!value.isEmpty)
            }
        }
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    private func heatmapDay(_ dayKey: String, completed: Int, padding: Bool) -> DashboardHeatmapDay {
        DashboardHeatmapDay(
            dayKey: dayKey,
            completedCount: completed,
            skippedCount: 0,
            scheduledCount: completed,
            intensityLevel: min(4, completed),
            isPaddingCell: padding
        )
    }
}
