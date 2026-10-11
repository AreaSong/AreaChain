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
            ScrollView {
                VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                    // 第 1 层（通栏浅灰托盘）：4 张纯白微浮大数字 KPI 卡 + 今日习惯与手记速览胶囊条
                    DashboardSummarySection(
                        summary: snapshot.summary,
                        navigation: navigation,
                        todayKey: today,
                        todos: todos,
                        routines: routines,
                        checks: checks,
                        diaries: diaries
                    )

                    // 第 2 层（通栏浅灰托盘）：全景年度热力图（带月份与星期坐标轴）+ 近 7 日双层动态趋势柱
                    DashboardSidebarPanel {
                        HStack(alignment: .top, spacing: DaybookSpacing.lg) {
                            DashboardHeatmapSection(
                                cells: snapshot.heatmap,
                                hasCompletions: DashboardHeatmapLayout.hasCompletions(snapshot.heatmap),
                                locale: locale,
                                navigation: navigation
                            )
                            DashboardTrendSection(
                                days: snapshot.trend,
                                locale: locale,
                                navigation: navigation
                            )
                        }
                    }

                    // 第 3 层（底部三舱等高自适应托盘）：左「四象限与今日焦点」 · 中「规划安排与手记/附件沉淀」 · 右「最近活动」
                    HStack(alignment: .top, spacing: DaybookSpacing.md) {
                        DashboardDistributionSection(
                            todayKey: today,
                            todos: todos,
                            routines: routines,
                            checks: checks,
                            tags: tags,
                            navigation: navigation,
                            bonusRows: 0
                        )

                        DashboardWorkspaceHubSection(
                            todayKey: today,
                            todos: todos,
                            routines: routines,
                            diaries: diaries,
                            attachments: attachments,
                            navigation: navigation,
                            bonusRows: 0,
                            openDiary: openDiary
                        )

                        DashboardActivitySection(
                            activities: snapshot.activities,
                            locale: locale,
                            navigation: navigation,
                            openDiary: openDiary
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .daybookScroll(featherEdges: false)
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
        let active = commandMonitor.isCommandPressed
        return HStack(spacing: 5) {
            Image(systemName: "command")
                .font(DaybookType.caption)
                .foregroundStyle(active ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
            Text(verbatim: active
                ? (isEnglish ? "HUD Active" : "透视已激活")
                : (isEnglish ? "Hold ⌘ to inspect" : "按住 ⌘ 悬停透视"))
                .font(DaybookType.caption)
                .foregroundStyle(active ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 顶栏侧边栏同款胶囊徽章
                .fill(active ? DaybookPalette.fill.selection : DaybookPalette.fill.hover)
        )
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
