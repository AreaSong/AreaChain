import Foundation
import Testing
@testable import AreaChain

@MainActor
struct DashboardInteractionTests {
    @Test func summaryRoutesUseTodayAndPending() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection(now: date("2026-09-25T00:00:00Z")))
        DashboardNavigation.openToday(navigation)
        #expect(navigation.selectedTab == .today)
        DashboardNavigation.openPending(navigation)
        #expect(navigation.selectedTab == .pending)
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

    @Test func activityRoutesStayOnExistingSurfaces() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection(now: date("2026-09-25T00:00:00Z")))
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        DashboardNavigation.open(
            .inspectItem(id: id, dayKey: "2026-09-20", kind: .todo),
            navigation: navigation
        )
        #expect(navigation.selectedTaskID == id)
        #expect(navigation.inspectingDayKey == "2026-09-20")
        #expect(navigation.isInspectorPresented)
        DashboardNavigation.open(.diaryPage, navigation: navigation)
        #expect(navigation.selectedTab == .diary)
        DashboardNavigation.open(.trash, navigation: navigation)
        #expect(navigation.selectedTab == .trash)
    }

    @Test func dashboardCopyResolvesInEnglishAndChinese() {
        for identifier in ["en", "zh-Hans"] {
            let locale = Locale(identifier: identifier)
            for key in [
                "dashboard.title", "dashboard.today.title", "dashboard.pending.overdue",
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
}
