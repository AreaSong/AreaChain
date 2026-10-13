import AppKit
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var todos: [TodoItem]
    @Query private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]
    @Query private var diaries: [DiaryEntry]
    @Query private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]
    @WorkspaceNavigationContext private var navigation
    @State private var dayTick = Date()
    @State private var commandMonitor = DashboardCommandKeyMonitor.shared

    private var todayKey: String {
        _ = dayTick
        return DayClock.shared.todayKey
    }

    private var isEnglish: Bool {
        locale.language.languageCode?.identifier == "en"
    }

    var body: some View {
        let today = todayKey
        let snapshot = makeSnapshot(todayKey: today)
        DaybookPage(
            title: "dashboard.title",
            subtitleText: DayKey.displayName(today, locale: locale),
            fullWidth: true
        ) {
            headerStatusBadge
        } content: {
            VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                // 第 1 层（通栏浅灰托盘）：核心指标矩阵 + 近 7 日动态趋势柱
                DashboardSummarySection(
                    summary: snapshot.summary,
                    trendDays: snapshot.trend,
                    navigation: navigation,
                    todayKey: today,
                    todos: todos,
                    routines: routines,
                    checks: checks,
                    diaries: diaries
                )

                // 第 2 层（通栏浅灰托盘）：GitHub 风格通栏年度热力图
                DashboardSidebarPanel {
                    DashboardHeatmapSection(
                        cells: snapshot.heatmap,
                        hasCompletions: DashboardHeatmapLayout.hasCompletions(snapshot.heatmap),
                        locale: locale,
                        navigation: navigation
                    )
                }

                // 第 3 层（纯指标双翼态势驾驶舱）：动态撑满视口剩余高度，彻底用完空间
                HStack(alignment: .top, spacing: DaybookSpacing.sm) {
                    DashboardDistributionSection(
                        todayKey: today,
                        todos: todos,
                        routines: routines,
                        checks: checks,
                        tags: tags,
                        navigation: navigation
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    DashboardActivitySection(
                        activities: snapshot.activities,
                        diaries: diaries,
                        attachments: attachments,
                        navigation: navigation,
                        openDiary: openDiary
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .workspaceHeader(status: AnyView(headerStatusBadge))
        .accessibilityIdentifier("dashboard.root")
        .animation(DaybookMotion.fade(reduceMotion), value: snapshot.summary.todayStat.completedCount)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }

    private var headerStatusBadge: some View {
        let active = commandMonitor.isCommandPressed || DashboardCommandKeyMonitor.isCommandDown
        return HStack(spacing: 5) {
            Image(systemName: "command")
                .font(DaybookType.caption)
                .foregroundStyle(active ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
            Text(verbatim: active
                ? (isEnglish ? "⌘ + Click to Jump" : "⌘ + 点击 直达页面")
                : (isEnglish ? "Hold ⌘ to Fast Jump" : "按住 ⌘ 点击直达"))
                .font(DaybookType.caption)
                .foregroundStyle(active ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 顶栏侧边栏同款胶囊徽章
                .fill(active ? DaybookPalette.fill.selection : DaybookPalette.fill.hover)
        )
        .scaleEffect(active ? 1.04 : 1.0)
        .animation(DaybookMotion.snappy(reduceMotion), value: active)
    }

    private func openDiary(_ id: UUID) {
        if let entry = diaries.first(where: { $0.id == id && $0.deletedAt == nil }) {
            _ = DiaryWindows.shared.open(entry: entry, context: modelContext)
        } else {
            navigation.revealTab(.diary)
        }
    }

    private func makeSnapshot(todayKey: String) -> DashboardSnapshot {
        DashboardProjection.project(
            todos: todos.map(\.snapshot),
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            diaries: diaries.map { DashboardProjection.diarySource($0.snapshot, tags: tags) },
            todayKey: todayKey
        )
    }
}
