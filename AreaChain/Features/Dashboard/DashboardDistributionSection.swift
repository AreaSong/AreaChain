import SwiftUI

/// 总览页第 3 排左宽栏：任务与规划指标中心（四象限宏观态势 + 排期概况 + 标签分布）
struct DashboardDistributionSection: View {
    @Environment(\.locale) private var locale
    var todayKey: String
    var todos: [TodoItem]
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var tags: [TagItem]
    var navigation: WorkspaceNavigation
    var bonusRows: Int = 0

    private enum QuadrantKey: String, Hashable {
        case q1, q2, q3, q4
    }

    @State private var inspectingQuadrant: QuadrantKey? = nil
    @State private var isInspectUpcoming = false
    @State private var isInspectHabits = false
    @State private var inspectingTagID: UUID? = nil

    private var liveTodos: [TodoItem] {
        todos.filter { $0.deletedAt == nil }
    }

    private var liveRoutines: [DailyRoutine] {
        routines.filter { $0.deletedAt == nil && $0.isEnabled }
    }

    private var upcomingTodos: [TodoItem] {
        liveTodos.filter { !$0.isDone && $0.dayKey > todayKey }
    }

    private var isEnglish: Bool {
        locale.language.languageCode?.identifier == "en"
    }

    var body: some View {
        DashboardSidebarPanel(fillsHeight: true) {
            quadrantsMatrixSection
            planningOverviewStrip
            Spacer(minLength: 0)
            tagsSection
        }
    }

    // MARK: - 核心：2×2 纯白微浮四象限指标矩阵（固定 62pt 高度，宏观态势一眼看全）

    private var quadrantsMatrixSection: some View {
        let open = liveTodos.filter { !$0.isDone }
        let q1 = open.filter { $0.isImportant && $0.isUrgent }
        let q2 = open.filter { $0.isImportant && !$0.isUrgent }
        let q3 = open.filter { !$0.isImportant && $0.isUrgent }
        let q4 = open.filter { !$0.isImportant && !$0.isUrgent }

        return VStack(alignment: .leading, spacing: 6) {
            DashboardSidebarSectionHeader(
                verbatim: isEnglish ? "Quadrant Matrix" : "四象限矩阵",
                badgeText: isEnglish ? "\(open.count) open" : "待办 \(open.count)"
            )
            HStack(spacing: 6) {
                quadrantTile(
                    key: .q1,
                    title: isEnglish ? "Urgent & Important" : "重要且紧急",
                    icon: "exclamationmark.circle",
                    items: q1,
                    isHighlighted: !q1.isEmpty
                )
                quadrantTile(
                    key: .q2,
                    title: isEnglish ? "Important, Not Urgent" : "重要不紧急",
                    icon: "flag",
                    items: q2,
                    isHighlighted: false
                )
            }
            HStack(spacing: 6) {
                quadrantTile(
                    key: .q3,
                    title: isEnglish ? "Urgent, Not Important" : "紧急不重要",
                    icon: "bolt",
                    items: q3,
                    isHighlighted: false
                )
                quadrantTile(
                    key: .q4,
                    title: isEnglish ? "Routine & Normal" : "日常事项",
                    icon: "tray",
                    items: q4,
                    isHighlighted: false
                )
            }
        }
    }

    private func quadrantTile(
        key: QuadrantKey,
        title: String,
        icon: String,
        items: [TodoItem],
        isHighlighted: Bool
    ) -> some View {
        let isInspecting = inspectingQuadrant == key
        return DashboardSurfaceTile(
            isSelected: isHighlighted,
            fixedHeight: 44,
            navigateAction: { navigation.revealTab(.quadrant) },
            navigateTooltip: isEnglish ? "Open Quadrant View" : "前往四象限看板"
        ) {
            inspectingQuadrant = isInspecting ? nil : key
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(DaybookType.caption)
                        .foregroundStyle(isHighlighted ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                    Text(verbatim: title)
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(isHighlighted ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(verbatim: "\(items.count)")
                    .font(DaybookType.title.monospacedDigit())
                    .contentTransition(.numericText())
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
            }
        }
        .dashboardCommandPopover(
            isPresented: Binding(
                get: { inspectingQuadrant == key },
                set: { if !$0 { inspectingQuadrant = nil } }
            ),
            arrowEdge: .top
        ) {
            DashboardHUDCard(
                icon: icon,
                title: title,
                subtitle: isEnglish ? "\(items.count) open items" : "当前待办 \(items.count) 项",
                items: items.map {
                    .init(
                        symbol: "circle",
                        symbolColor: DaybookPalette.text.secondary,
                        title: $0.title,
                        trailing: DayKey.shortStamp($0.dayKey, locale: locale)
                    )
                },
                emptyText: isEnglish ? "No open items in this quadrant" : "该象限当前没有未完成事项",
                actionTitle: isEnglish ? "Go to Quadrant View" : "前往四象限看板",
                onAction: {
                    inspectingQuadrant = nil
                    navigation.revealTab(.quadrant)
                }
            )
        }
    }

    // MARK: - 排期规划态势指标条（未来待办 · 启用习惯 · 日历直达）

    private var planningOverviewStrip: some View {
        HStack(spacing: 8) {
            metricShortcutPill(
                icon: "calendar.badge.clock",
                title: isEnglish ? "Upcoming" : "未来排期",
                count: upcomingTodos.count,
                navigateAction: {
                    DashboardNavigation.openPending(navigation, lane: .upcoming)
                }
            ) {
                isInspectUpcoming.toggle()
            }
            .dashboardCommandPopover(isPresented: $isInspectUpcoming, arrowEdge: .top) {
                DashboardHUDCard(
                    icon: "calendar.badge.clock",
                    title: isEnglish ? "Upcoming Tasks" : "未来排期预告",
                    subtitle: isEnglish ? "\(upcomingTodos.count) tasks" : "未来待办共 \(upcomingTodos.count) 项",
                    items: upcomingTodos.prefix(6).map {
                        .init(symbol: "clock", symbolColor: DaybookPalette.accent.base, title: $0.title, trailing: DayKey.shortStamp($0.dayKey, locale: locale))
                    },
                    emptyText: isEnglish ? "No upcoming tasks" : "未来日期暂无待办事项",
                    actionTitle: isEnglish ? "Go to Pending Page" : "前往待处理泳道",
                    onAction: {
                        isInspectUpcoming = false
                        DashboardNavigation.openPending(navigation, lane: .upcoming)
                    }
                )
            }

            metricShortcutPill(
                icon: "repeat",
                title: isEnglish ? "Habits" : "常驻习惯",
                count: liveRoutines.count,
                navigateAction: {
                    navigation.revealRecurringList()
                }
            ) {
                isInspectHabits.toggle()
            }
            .dashboardCommandPopover(isPresented: $isInspectHabits, arrowEdge: .top) {
                DashboardHUDCard(
                    icon: "repeat",
                    title: isEnglish ? "Active Habits" : "常驻习惯列表",
                    subtitle: isEnglish ? "\(liveRoutines.count) active habits" : "共 \(liveRoutines.count) 个常驻习惯",
                    items: liveRoutines.prefix(6).map {
                        .init(symbol: "repeat", symbolColor: DaybookPalette.text.secondary, title: $0.title, trailing: isEnglish ? "Active" : "启用中")
                    },
                    emptyText: isEnglish ? "No active routines" : "暂无启用中的重复习惯",
                    actionTitle: isEnglish ? "Go to Routines" : "前往安排习惯",
                    onAction: {
                        isInspectHabits = false
                        navigation.revealRecurringList()
                    }
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func metricShortcutPill(
        icon: String,
        title: String,
        count: Int,
        navigateAction: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            let isCmd = DashboardCommandKeyMonitor.isCommandDown || DashboardCommandKeyMonitor.shared.isCommandPressed
            if isCmd, let navigateAction {
                navigateAction()
            } else {
                action()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Text(verbatim: title)
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                Text(verbatim: "\(count)")
                    .font(DaybookType.badge.monospacedDigit())
                    .foregroundStyle(DaybookPalette.accent.base)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 规划排期指标胶囊
                    .fill(DaybookPalette.fill.surface)
            )
        }
        .buttonStyle(.plain) // control: 规划指标胶囊按钮
        .onHover { hovering in
            if hovering {
                DashboardCommandKeyMonitor.shared.sync()
            }
        }
    }

    // MARK: - 底部：标签速览胶囊条

    private var tagsSection: some View {
        let liveTags = Catalog.liveTaskTags(tags)
        let counts: [(tag: TagItem, items: [TodoItem])] = liveTags.compactMap { tag in
            let matched = liveTodos.filter { TagIDList.parse($0.tagIDs).contains(tag.id) }
            return matched.isEmpty ? nil : (tag, matched)
        }
        return HStack(spacing: 6) {
            ForEach(counts.prefix(4), id: \.tag.id) { entry in
                tagPill(tag: entry.tag, items: entry.items)
            }
            Button {
                navigation.revealTab(.tags)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text(verbatim: isEnglish ? "Tags \(liveTags.count)" : "标签 \(liveTags.count)")
                        .font(DaybookType.badge.monospacedDigit())
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 标签管理入口纯白微浮胶囊
                        .fill(DaybookPalette.fill.surface)
                )
            }
            .buttonStyle(.plain) // control: 标签管理入口按钮
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func tagPill(tag: TagItem, items: [TodoItem]) -> some View {
        let color = DaybookPalette.tagMark(name: tag.name, token: tag.colorToken)
        let doneCount = items.filter(\.isDone).count
        let isInspecting = inspectingTagID == tag.id
        return Button {
            let isCmd = DashboardCommandKeyMonitor.isCommandDown || DashboardCommandKeyMonitor.shared.isCommandPressed
            if isCmd {
                inspectingTagID = nil
                navigation.selectedTagID = tag.id
            } else {
                inspectingTagID = isInspecting ? nil : tag.id
            }
        } label: {
            HStack(spacing: 5) {
                DaybookStatusDot(color: color, size: 6)
                Text(verbatim: tag.name)
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                Text(verbatim: "\(items.count)")
                    .font(DaybookType.badge.monospacedDigit())
                    .contentTransition(.numericText())
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 标签统计纯白微浮胶囊
                    .fill(isInspecting ? DaybookPalette.fill.selection : DaybookPalette.fill.surface)
            )
        }
        .buttonStyle(.plain) // control: 标签统计胶囊按钮
        .dashboardCommandPopover(
            isPresented: Binding(
                get: { inspectingTagID == tag.id },
                set: { if !$0 { inspectingTagID = nil } }
            ),
            arrowEdge: .bottom
        ) {
            DashboardHUDCard(
                icon: "tag",
                title: tag.name,
                subtitle: isEnglish ? "Completed \(doneCount)/\(items.count)" : "已完成 \(doneCount) / 共 \(items.count) 项",
                accent: color,
                items: items.map {
                    .init(
                        symbol: $0.isDone ? "checkmark.circle.fill" : "circle",
                        symbolColor: $0.isDone ? DaybookPalette.status.success : DaybookPalette.text.tertiary,
                        title: $0.title,
                        trailing: DayKey.shortStamp($0.dayKey, locale: locale)
                    )
                },
                emptyText: "",
                actionTitle: isEnglish ? "Filter Tasks by Tag" : "筛选该标签全部事项",
                onAction: {
                    inspectingTagID = nil
                    navigation.selectedTagID = tag.id
                }
            )
        }
    }
}
