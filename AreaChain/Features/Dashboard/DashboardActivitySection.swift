import SwiftUI

/// 总览页第 3 排中舱：规划安排（甘特排期/未来预告）+ 内容沉淀（灵感手记摘录 + 剪贴板/附件资产胶囊）
struct DashboardWorkspaceHubSection: View {
    @Environment(\.locale) private var locale
    var todayKey: String
    var todos: [TodoItem]
    var routines: [DailyRoutine]
    var diaries: [DiaryEntry]
    var attachments: [AttachmentItem]
    var navigation: WorkspaceNavigation
    var bonusRows: Int = 0
    var openDiary: (UUID) -> Void = { _ in }

    private var isEnglish: Bool { locale.language.languageCode?.identifier == "en" }
    private var liveTodos: [TodoItem] { todos.filter { $0.deletedAt == nil } }
    private var liveRoutines: [DailyRoutine] { routines.filter { $0.deletedAt == nil && $0.isEnabled } }
    private var liveDiaries: [DiaryEntry] {
        diaries.filter { $0.deletedAt == nil }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }
    private var liveAttachments: [AttachmentItem] { attachments.filter { $0.deletedAt == nil && $0.privacyVaultID == nil } }
    private var monthScheduledTodos: [TodoItem] { liveTodos.filter { $0.dayKey.hasPrefix(String(todayKey.prefix(7))) } }
    private var upcomingTodos: [TodoItem] { liveTodos.filter { !$0.isDone && $0.dayKey > todayKey }.sorted { $0.dayKey < $1.dayKey } }

    var body: some View {
        DashboardSidebarPanel(fillsHeight: true) {
            planningMatrixSection
            diaryPrecipitationSection
            Spacer(minLength: 0)
            contentAssetsFooter
        }
    }

    // MARK: - 上半部：规划与排期（1×2 纯白微浮块，固定 62pt 高度，与左舱四象限第一排严格水平齐平）

    private var planningMatrixSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSidebarSectionHeader(
                verbatim: isEnglish ? "Planning & Schedule" : "规划与近期安排",
                badgeText: isEnglish ? "\(liveRoutines.count) habits" : "常驻 \(liveRoutines.count)"
            )
            HStack(spacing: 8) {
                ganttScheduleTile
                upcomingScheduleTile
            }
            scheduleRowsList
        }
    }

    private var ganttScheduleTile: some View {
        let openMonthCount = monthScheduledTodos.filter { !$0.isDone }.count
        return DashboardSurfaceTile(isSelected: false, fixedHeight: 62) {
            navigation.revealTab(.gantt)
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text(verbatim: isEnglish ? "Month Gantt" : "本月安排")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(verbatim: "\(monthScheduledTodos.count)")
                    .font(DaybookType.title.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
            }
        }
        .dashboardCommandPopover(arrowEdge: .top) {
            DashboardHUDCard(
                icon: "chart.bar.xaxis",
                title: isEnglish ? "Monthly Schedule & Routines" : "本月排期与常驻安排",
                subtitle: isEnglish ? "\(openMonthCount) open · \(liveRoutines.count) habits" : "待完成 \(openMonthCount) 项 · 活跃常驻 \(liveRoutines.count) 项",
                items: monthScheduledTodos.prefix(8).map {
                    .init(symbol: $0.isDone ? "checkmark.circle.fill" : "calendar",
                          symbolColor: $0.isDone ? DaybookPalette.status.success : DaybookPalette.accent.base,
                          title: $0.title, trailing: DayKey.shortStamp($0.dayKey, locale: locale))
                },
                emptyText: isEnglish ? "No scheduled items this month" : "本月暂无排期事项"
            )
        }
    }

    private var upcomingScheduleTile: some View {
        DashboardSurfaceTile(isSelected: !upcomingTodos.isEmpty, fixedHeight: 62) {
            DashboardNavigation.openPending(navigation, lane: .upcoming)
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.clock")
                        .font(DaybookType.caption)
                        .foregroundStyle(!upcomingTodos.isEmpty ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                    Text(verbatim: isEnglish ? "Upcoming" : "未来排期")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(!upcomingTodos.isEmpty ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(verbatim: "\(upcomingTodos.count)")
                    .font(DaybookType.title.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
            }
        }
        .dashboardCommandPopover(arrowEdge: .top) {
            DashboardHUDCard(
                icon: "calendar.badge.clock",
                title: isEnglish ? "Upcoming Scheduled Tasks" : "未来排期预告",
                subtitle: isEnglish ? "\(upcomingTodos.count) future tasks" : "未来待办共 \(upcomingTodos.count) 项",
                items: upcomingTodos.prefix(8).map {
                    .init(symbol: "clock", symbolColor: DaybookPalette.accent.base, title: $0.title, trailing: DayKey.shortStamp($0.dayKey, locale: locale))
                },
                emptyText: isEnglish ? "No upcoming scheduled tasks" : "未来日期暂无排期事项"
            )
        }
    }

    @ViewBuilder
    private var scheduleRowsList: some View {
        let maxScheduleRows = max(2, 2 + bonusRows / 2)
        if !upcomingTodos.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(upcomingTodos.prefix(maxScheduleRows)) { item in
                    DashboardSidebarRow(
                        titleText: item.title,
                        systemImage: "calendar",
                        badgeText: DayKey.shortStamp(item.dayKey, locale: locale)
                    ) {
                        navigation.revealTab(.calendar, inspecting: item.id, dayKey: item.dayKey)
                    }
                }
            }
        } else if !liveRoutines.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(liveRoutines.prefix(maxScheduleRows)) { routine in
                    DashboardSidebarRow(
                        titleText: routine.title,
                        systemImage: "repeat",
                        badgeText: isEnglish ? "Habit" : "常驻"
                    ) {
                        navigation.revealTab(.gantt)
                    }
                }
            }
        }
    }

    // MARK: - 中半部：灵感手记沉淀（纯白微浮手记摘录卡片）

    private var diaryPrecipitationSection: some View {
        let maxDiaries = max(2, 2 + (bonusRows + 1) / 2)
        return VStack(alignment: .leading, spacing: 6) {
            DashboardSidebarSectionHeader(
                verbatim: isEnglish ? "Recent Notes & Jottings" : "灵感手记沉淀",
                badgeText: "\(liveDiaries.count)"
            )
            .padding(.top, 2)

            if liveDiaries.isEmpty {
                DashboardSidebarRow(
                    titleText: isEnglish ? "Write your first note" : "暂无手记，点击记录灵感",
                    systemImage: "note.text",
                    badgeText: "0"
                ) {
                    navigation.revealTab(.diary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(liveDiaries.prefix(maxDiaries)) { entry in
                        diaryExcerptCard(entry)
                    }
                }
            }
        }
    }

    private func diaryExcerptCard(_ entry: DiaryEntry) -> some View {
        let parsed = parseDiaryDisplay(entry)
        return DashboardSurfaceTile(isSelected: entry.isPinned) {
            openDiary(entry.id)
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: entry.hasProtectedContent ? "lock.fill" : (entry.isPinned ? "pin.fill" : "note.text"))
                        .font(DaybookType.caption)
                        .foregroundStyle(entry.isPinned ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                    Text(verbatim: parsed.title)
                        .font(DaybookType.body.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(verbatim: DayKey.shortStamp(entry.dayKey, locale: locale))
                        .font(DaybookType.badge.monospacedDigit())
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
                if !parsed.excerpt.isEmpty {
                    Text(verbatim: parsed.excerpt)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(2)
                }
            }
        }
        .dashboardCommandPopover(arrowEdge: .trailing) {
            DashboardHUDCard(
                icon: entry.hasProtectedContent ? "lock.fill" : "note.text",
                title: parsed.title,
                subtitle: DayKey.displayName(entry.dayKey, locale: locale),
                items: parsed.excerpt.isEmpty ? [] : [.init(symbol: "text.quote", symbolColor: DaybookPalette.accent.base, title: parsed.excerpt, trailing: nil)],
                emptyText: entry.hasProtectedContent ? (isEnglish ? "Encrypted private note" : "私密手记已加密") : (isEnglish ? "Click to open note window" : "点击打开独立手记窗口")
            )
        }
    }

    private func parseDiaryDisplay(_ entry: DiaryEntry) -> (title: String, excerpt: String) {
        if entry.hasProtectedContent {
            return (isEnglish ? "Private Note" : "私密手记", isEnglish ? "Protected by privacy lock" : "受私密锁保护")
        }
        let lines = entry.text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let first = lines.first else { return (isEnglish ? "Untitled Note" : "未命名手记", "") }
        let rest = lines.dropFirst().joined(separator: " ")
        return (String(first.prefix(48)), String(rest.prefix(120)))
    }

    // MARK: - 底部：内容资产胶囊条（剪贴板 · 附件 · 手记，贴齐中舱底边）

    private var contentAssetsFooter: some View {
        let clipItems = ClipboardHistorySession.shared.items
        return HStack(spacing: 6) {
            assetPill(icon: "doc.on.clipboard", label: isEnglish ? "Clips" : "剪贴板", count: clipItems.count) {
                navigation.revealTab(.clipboard)
            }
            .dashboardCommandPopover(arrowEdge: .bottom) {
                DashboardHUDCard(
                    icon: "doc.on.clipboard",
                    title: isEnglish ? "Clipboard History" : "剪贴板捕获历史",
                    subtitle: isEnglish ? "\(clipItems.count) captured items" : "已捕获 \(clipItems.count) 条记录",
                    items: clipItems.prefix(6).map {
                        .init(symbol: $0.isPinned ? "pin.fill" : "doc.on.clipboard",
                              symbolColor: $0.isPinned ? DaybookPalette.accent.base : DaybookPalette.text.secondary,
                              title: $0.preview.isEmpty ? (isEnglish ? "[Media / File]" : "[图片或文件]") : $0.preview, trailing: nil)
                    },
                    emptyText: isEnglish ? "Clipboard history is empty" : "剪贴板历史当前为空"
                )
            }

            assetPill(icon: "paperclip", label: isEnglish ? "Files" : "附件", count: liveAttachments.count) {
                navigation.revealTab(.attachments)
            }
            .dashboardCommandPopover(arrowEdge: .bottom) {
                DashboardHUDCard(
                    icon: "paperclip",
                    title: isEnglish ? "Attachments Library" : "工作台附件库",
                    subtitle: isEnglish ? "\(liveAttachments.count) files" : "共 \(liveAttachments.count) 个附件",
                    items: liveAttachments.prefix(6).map {
                        .init(symbol: "doc", symbolColor: DaybookPalette.text.secondary, title: $0.filename, trailing: nil)
                    },
                    emptyText: isEnglish ? "No attachments yet" : "当前暂无附件文件"
                )
            }

            assetPill(icon: "note.text", label: isEnglish ? "Notes" : "手记", count: liveDiaries.count) {
                navigation.revealTab(.diary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func assetPill(icon: String, label: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Text(verbatim: label)
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                Text(verbatim: "\(count)")
                    .font(DaybookType.badge.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 内容资产纯白微浮胶囊
                    .fill(DaybookPalette.fill.surface)
            )
        }
        .buttonStyle(.plain) // control: 内容资产胶囊按钮
    }
}

struct DashboardActivitySection: View {
    var activities: [DashboardActivity]
    var locale: Locale
    var navigation: WorkspaceNavigation
    var openDiary: (UUID) -> Void = { _ in }

    private var isEnglish: Bool { locale.language.languageCode?.identifier == "en" }

    var body: some View {
        DashboardSidebarPanel(fillsHeight: true) {
            DashboardSidebarSectionHeader("dashboard.activity.title", badgeText: "\(activities.count)")
            if activities.isEmpty {
                Text("dashboard.activity.empty")
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("dashboard.activity.empty")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(activities) { activityRow($0) }
                }
            }
            Spacer(minLength: 0)
            activityFooterBar
        }
        .accessibilityIdentifier("dashboard.activity")
    }

    private var activityFooterBar: some View {
        HStack(spacing: 6) {
            footerShortcutPill(icon: "list.bullet", title: isEnglish ? "All Items" : "全部事项") { navigation.revealTab(.allItems) }
            footerShortcutPill(icon: "calendar", title: isEnglish ? "Calendar" : "日历") { navigation.revealTab(.calendar) }
            footerShortcutPill(icon: "trash", title: isEnglish ? "Trash" : "废纸篓") { navigation.revealTab(.trash) }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func footerShortcutPill(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Text(verbatim: title)
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 动态栏底部快捷入口纯白胶囊
                    .fill(DaybookPalette.fill.surface)
            )
        }
        .buttonStyle(.plain) // control: 动态栏底部快捷入口按钮
    }

    private func activityRow(_ activity: DashboardActivity) -> some View {
        let kindLabel = L10n.string(String.LocalizationValue(kindStringKey(activity.kind)), locale: locale)
        let dateLabel = DayKey.shortStamp(activity.dayKey, locale: locale)
        return DashboardSidebarRow(
            titleText: subject(activity),
            systemImage: kindIcon(activity.kind),
            secondaryText: kindLabel,
            badgeText: dateLabel
        ) {
            open(activity.route)
        }
        .disabled(activity.route == nil)
        .accessibilityIdentifier("dashboard.activity.\(activity.id)")
        .accessibilityLabel(Text(accessibilityText(activity)))
        .dashboardCommandPopover(arrowEdge: .top) {
            DashboardHUDCard(
                icon: kindIcon(activity.kind),
                title: subject(activity),
                subtitle: kindLabel + " · " + DayKey.displayName(activity.dayKey, locale: locale),
                items: [],
                emptyText: isEnglish ? "Click row to jump to item" : "点击该条动态可直接跳转对应事项或手记"
            )
        }
    }

    private func kindIcon(_ kind: DashboardActivityKind) -> String {
        switch kind {
        case .completed: return "checkmark.circle"
        case .skipped: return "forward.end"
        case .created: return "plus.circle"
        case .trashed: return "trash"
        }
    }

    private func open(_ route: DashboardActivityRoute?) {
        if case .openDiary(let id) = route {
            openDiary(id)
            return
        }
        DashboardNavigation.open(route, navigation: navigation)
    }

    private func subject(_ activity: DashboardActivity) -> String {
        if let key = activity.titleKey {
            return L10n.string(String.LocalizationValue(key), locale: locale)
        }
        return activity.title
    }

    private func accessibilityText(_ activity: DashboardActivity) -> String {
        L10n.format(
            "dashboard.activity.row",
            locale: locale,
            L10n.string(String.LocalizationValue(kindStringKey(activity.kind)), locale: locale),
            subject(activity),
            DayKey.displayName(activity.dayKey, locale: locale)
        )
    }

    private func kindStringKey(_ kind: DashboardActivityKind) -> String {
        switch kind {
        case .completed: return "dashboard.activity.kind.completed"
        case .skipped: return "dashboard.activity.kind.skipped"
        case .created: return "dashboard.activity.kind.created"
        case .trashed: return "dashboard.activity.kind.trashed"
        }
    }
}
