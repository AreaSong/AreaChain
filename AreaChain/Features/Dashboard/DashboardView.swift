import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var todos: [TodoItem]
    @Query private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]
    @Query private var diaries: [DiaryEntry]
    @Bindable private var navigation = WorkspaceNavigation.shared
    @State private var dayTick = Date()

    private var todayKey: String {
        _ = dayTick
        return DayClock.shared.todayKey
    }

    private var snapshot: DashboardSnapshot {
        DashboardProjection.project(
            todos: todos.map(\.snapshot),
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            diaries: diaries.map(diarySource),
            todayKey: todayKey
        )
    }

    var body: some View {
        DaybookPage(
            title: "dashboard.title",
            subtitleText: DayKey.displayName(todayKey, locale: locale),
            fullWidth: true
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: DaybookSpacing.lg) {
                    DashboardSummarySection(summary: snapshot.summary, navigation: navigation)
                    DashboardTrendSection(days: snapshot.trend, locale: locale)
                    DashboardHeatmapSection(
                        cells: snapshot.heatmap,
                        hasCompletions: snapshot.heatmap.contains { !$0.isPaddingCell && $0.completedCount > 0 },
                        locale: locale,
                        navigation: navigation
                    )
                    DashboardActivitySection(activities: snapshot.activities, locale: locale, navigation: navigation)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("dashboard.root")
        .animation(DaybookMotion.fade(reduceMotion), value: snapshot.summary.todayStat.completedCount)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }

    /// 手记只提供日期和隐私标记，不把正文送进总览。
    private func diarySource(_ entry: DiaryEntry) -> DiarySnapshot {
        DiarySnapshot(
            id: entry.id,
            text: "",
            dayKey: entry.dayKey,
            createdAt: entry.createdAt,
            deletedAt: entry.deletedAt,
            isPinned: entry.isPinned,
            isPrivate: entry.hasProtectedContent,
            isContentAvailable: !entry.hasProtectedContent
        )
    }
}
