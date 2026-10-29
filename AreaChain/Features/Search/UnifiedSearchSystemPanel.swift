import SwiftUI

/// 导航面板里的系统动作预览：说明回车后会做什么；统计直接列出与总览页同一投影的数字（只读）。
struct UnifiedSearchSystemBlock: View {
    @Bindable var controller: UnifiedSearchController
    let action: CommandSystemAction
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(LocalizedStringKey(Self.previewKey(action))).font(DaybookType.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("unified.system.preview")
            if case .stats(let kind, let day) = action { stats(kind, day: day) }
            if action == .quit || action == .workspaceClose, controller.hasUnsavedCommandWork { unsavedWork }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.system")
    }

    /// 说明挡住关闭（或退出会丢掉）的是哪份草稿、几项待执行，并就地给出放弃草稿与回到列表的入口。
    private var unsavedWork: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(action == .quit ? "unified.system.quit.unsaved" : "unified.system.workspace.closeBlocked")
                .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("unified.system.warning")
            if let draft = controller.operations?.active,
               let command = CommandCatalog.standard.command(id: draft.commandID) {
                Text(verbatim: L10n.format("unified.system.unsaved.draft", locale: locale, command.name(locale: locale)))
                    .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityIdentifier("unified.system.unsaved.draft")
            }
            if let count = controller.plan?.items.count, count > 0 {
                Text(verbatim: L10n.format("unified.plan.count", locale: locale, count))
                    .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityIdentifier("unified.system.unsaved.plan")
            }
            HStack(spacing: DaybookSpacing.sm) {
                // 编辑待执行项时放弃入口不作用于活动草稿，不显示，避免点了无反应。
                if controller.operations?.active != nil, controller.buffer.planItem == nil {
                    Button("unified.system.unsaved.discardDraft") {
                        controller.discardActiveOperation(source: controller.buffer)
                    }
                    .accessibilityIdentifier("unified.system.unsaved.discardDraft")
                }
                Button("unified.system.unsaved.review") { _ = controller.navigationInput(controller.queryInputText) }
                    .accessibilityIdentifier("unified.system.unsaved.review")
            }
            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
        }
    }

    @ViewBuilder private func stats(_ kind: CommandStatsKind, day: String?) -> some View {
        if let snapshot = try? controller.pageCommands?.statsSnapshot(day: day) {
            if kind == .activity {
                if snapshot.activities.isEmpty {
                    Text("unified.stats.activity.empty").font(DaybookType.caption)
                }
                ForEach(snapshot.activities) { activity in
                    HStack(spacing: DaybookSpacing.xs) {
                        Text(verbatim: activityLine(activity)).font(DaybookType.caption).lineLimit(1)
                        Spacer(minLength: 0)
                        Button("unified.stats.open") { controller.openStatsActivity(activity, source: controller.buffer) }
                            .buttonStyle(DaybookButtonStyle(.subtle)).disabled(activity.route == nil)
                            .accessibilityIdentifier("unified.stats.activity." + activity.id)
                    }
                }
            } else {
                ForEach(Array(Self.lines(kind, snapshot: snapshot, locale: locale).enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line).font(DaybookType.caption).accessibilityIdentifier("unified.stats.line")
                }
            }
        } else {
            Text("unified.page.unassembled").font(DaybookType.caption)
        }
    }

    private func activityLine(_ activity: DashboardActivity) -> String {
        [L10n.string(String.LocalizationValue(activity.kind.titleKey), locale: locale), activity.displayTitle(locale: locale),
         DayKey.shortStamp(activity.dayKey, locale: locale)].joined(separator: " · ")
    }

    /// 统计行：每个数字都直接取自 DashboardSnapshot 的同名字段。
    static func lines(_ kind: CommandStatsKind, snapshot: DashboardSnapshot, locale: Locale) -> [String] {
        let summary = snapshot.summary
        switch kind {
        case .today:
            let today = summary.todayStat
            return [L10n.format("unified.stats.today", locale: locale, today.completedCount, today.scheduledCount,
                                today.skippedCount, today.openCount)]
        case .pending: return [L10n.format("unified.stats.pending", locale: locale, summary.overdueCount, summary.upcomingCount)]
        case .streaks:
            return [L10n.format("unified.stats.streaks", locale: locale, summary.strongestCurrentStreak, summary.strongestBestStreak)]
        case .routines: return [L10n.format("unified.stats.routines", locale: locale, summary.activeRoutineCount)]
        case .diaries: return [L10n.format("unified.stats.diaries", locale: locale, summary.todayDiaryCount)]
        case .trend:
            return snapshot.trend.map {
                L10n.format("unified.stats.trendDay", locale: locale, DayKey.shortStamp($0.dayKey, locale: locale),
                            $0.completedCount, $0.scheduledCount)
            }
        case .heatmap:
            let days = snapshot.heatmap.filter { !$0.isPaddingCell }
            return [L10n.format("unified.stats.heatmap", locale: locale, days.filter { $0.completedCount > 0 }.count,
                                days.reduce(0) { $0 + $1.completedCount })]
        case .activity: return []
        }
    }

    static func previewKey(_ action: CommandSystemAction) -> String {
        switch action {
        case .workspaceOpen: "unified.system.workspace.open.preview"
        case .workspaceReveal: "unified.system.workspace.reveal.preview"
        case .workspaceClose: "unified.system.workspace.close.preview"
        case .overlayToggle: "unified.system.overlay.toggle.preview"
        case .overlayMode: "unified.system.overlay.mode.preview"
        case .routineAddPanel: "unified.system.routine.add.preview"
        case .routineManagePanel: "unified.system.routine.manage.preview"
        case .diaryOpen: "unified.system.diary.open.preview"
        case .diaryDraft: "unified.system.diary.draft.preview"
        case .diaryPinned: "unified.system.diary.pinned.preview"
        case .diaryClose: "unified.system.diary.close.preview"
        case .diarySave: "unified.system.diary.save.preview"
        case .diaryReload: "unified.system.diary.reload.preview"
        case .diaryDiscard: "unified.system.diary.discard.preview"
        case .diaryCopy(let section): "unified.system.diary.copy." + section.rawValue + ".preview"
        case .stats: "unified.stats.preview"
        case .statsOpenDay: "unified.stats.openDay.preview"
        case .statsOpenActivity: "unified.stats.chooseActivity"
        case .quit: "unified.system.quit.preview"
        case .privacyLock: "unified.privacy.lock.preview"
        }
    }
}
