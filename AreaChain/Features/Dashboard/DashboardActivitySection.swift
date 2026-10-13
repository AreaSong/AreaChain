import SwiftUI

/// 总览页第 3 排右宽栏：灵感沉淀与资产指标中心（灵感便签卡 + 活动态势指标 + 内容资产入口）
struct DashboardActivitySection: View {
    @Environment(\.locale) private var locale
    var activities: [DashboardActivity]
    var diaries: [DiaryEntry] = []
    var attachments: [AttachmentItem] = []
    var navigation: WorkspaceNavigation
    var openDiary: (UUID) -> Void = { _ in }

    @State private var isInspectNote = false
    @State private var isInspectClips = false
    @State private var isInspectFiles = false

    private var isEnglish: Bool {
        locale.language.languageCode?.identifier == "en"
    }

    private var liveDiaries: [DiaryEntry] {
        diaries.filter { $0.deletedAt == nil }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    private var liveAttachments: [AttachmentItem] {
        attachments.filter { $0.deletedAt == nil && $0.privacyVaultID == nil }
    }

    var body: some View {
        DashboardSidebarPanel(fillsHeight: true) {
            noteInspirationCard
            activitiesMetricsSection
            Spacer(minLength: 0)
            contentAssetsFooter
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard.activity")
    }

    // MARK: - 顶部：今日灵感便签卡（置顶手记 / 今日想法摘要卡片，点击直接唤起独立手记写作窗口）

    private var noteInspirationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            DashboardSidebarSectionHeader(
                verbatim: isEnglish ? "Inspiration & Notes" : "灵感便签与手记",
                badgeText: "\(liveDiaries.count)"
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("dashboard.activity")
            if let entry = liveDiaries.first {
                noteExcerptCard(entry)
            } else {
                emptyNotePromptCard
            }
        }
    }

    private func noteExcerptCard(_ entry: DiaryEntry) -> some View {
        let parsed = parseDiaryDisplay(entry)
        return DashboardSurfaceTile(
            isSelected: entry.isPinned,
            fixedHeight: 44,
            navigateAction: { openDiary(entry.id) },
            navigateTooltip: isEnglish ? "Open in Diary Window" : "在独立窗口中打开手记"
        ) {
            isInspectNote.toggle()
        } content: {
            VStack(alignment: .leading, spacing: 3) {
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
                        .lineLimit(1)
                }
            }
        }
        .dashboardCommandPopover(isPresented: $isInspectNote, arrowEdge: .trailing) {
            DashboardHUDCard(
                icon: entry.hasProtectedContent ? "lock.fill" : "note.text",
                title: parsed.title,
                subtitle: DayKey.displayName(entry.dayKey, locale: locale),
                items: parsed.excerpt.isEmpty ? [] : [
                    .init(symbol: "text.quote", symbolColor: DaybookPalette.accent.base, title: parsed.excerpt, trailing: nil)
                ],
                emptyText: entry.hasProtectedContent
                    ? (isEnglish ? "Encrypted private note" : "私密手记已加密")
                    : (isEnglish ? "Click to open note window" : "点击打开独立手记窗口"),
                actionTitle: isEnglish ? "Open Diary Window" : "在独立窗口中打开",
                onAction: {
                    isInspectNote = false
                    openDiary(entry.id)
                }
            )
        }
    }

    private var emptyNotePromptCard: some View {
        DashboardSurfaceTile(isSelected: false, fixedHeight: 44) {
            navigation.revealTab(.diary)
        } content: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.accent.base)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: isEnglish ? "Jot down your thoughts" : "记录今日第一条灵感")
                        .font(DaybookType.body.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(1)
                    Text(verbatim: isEnglish ? "Click to open diary writing window" : "点击开启独立手记随手记")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
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

    // MARK: - 中部：近期活动宏观态势指标（完成/跳过/新建指标 + 最新动态微指示）

    private var activitiesMetricsSection: some View {
        let completed = activities.filter { $0.kind == .completed }.count
        let skipped = activities.filter { $0.kind == .skipped }.count
        let created = activities.filter { $0.kind == .created }.count

        return VStack(alignment: .leading, spacing: 6) {
            DashboardSidebarSectionHeader(
                verbatim: isEnglish ? "Activity Overview" : "近期活动态势",
                badgeText: "\(activities.count)"
            )
            .padding(.top, 2)

            if activities.isEmpty {
                Text("dashboard.activity.empty")
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("dashboard.activity.empty")
            } else {
                HStack(spacing: 8) {
                    activityStatTile(
                        icon: "checkmark.circle.fill",
                        color: DaybookPalette.status.success,
                        label: isEnglish ? "Completed" : "已完成",
                        count: completed
                    )
                    activityStatTile(
                        icon: "forward.end.fill",
                        color: DaybookPalette.text.tertiary,
                        label: isEnglish ? "Skipped" : "已跳过",
                        count: skipped
                    )
                    activityStatTile(
                        icon: "plus.circle.fill",
                        color: DaybookPalette.accent.base,
                        label: isEnglish ? "Created" : "新创建",
                        count: created
                    )
                }

                if let latest = activities.last {
                    latestActivityIndicatorRow(latest)
                }
            }
        }
    }

    private func activityStatTile(icon: String, color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(DaybookType.micro)
                .foregroundStyle(color)
            Text(verbatim: label)
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(verbatim: "\(count)")
                .font(DaybookType.badge.monospacedDigit())
                .foregroundStyle(DaybookPalette.text.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous) // control: 活动分类统计磁贴
                .fill(DaybookPalette.fill.surface)
        )
    }

    private func latestActivityIndicatorRow(_ activity: DashboardActivity) -> some View {
        let kindLabel = L10n.string(String.LocalizationValue(kindStringKey(activity.kind)), locale: locale)
        return DashboardSidebarRow(
            titleText: subject(activity),
            systemImage: kindIcon(activity.kind),
            secondaryText: kindLabel,
            badgeText: DayKey.shortStamp(activity.dayKey, locale: locale)
        ) {
            open(activity.route)
        }
        .disabled(activity.route == nil)
        .accessibilityIdentifier("dashboard.activity.\(activity.id)")
        .accessibilityLabel(Text(accessibilityText(activity)))
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

    // MARK: - 底部：内容资产与快捷入口栏（剪贴板 · 附件 · 全部事项 · 废纸篓）

    private var contentAssetsFooter: some View {
        let clipItems = ClipboardHistorySession.shared.items
        return HStack(spacing: 6) {
            assetPill(
                icon: "doc.on.clipboard",
                label: isEnglish ? "Clips" : "剪贴板",
                count: clipItems.count,
                isSelected: isInspectClips,
                navigateAction: {
                    navigation.revealTab(.allItems)
                }
            ) {
                isInspectClips.toggle()
            }
            .dashboardCommandPopover(isPresented: $isInspectClips, arrowEdge: .bottom) {
                clipboardHUD(items: clipItems)
            }

            assetPill(
                icon: "paperclip",
                label: isEnglish ? "Files" : "附件",
                count: liveAttachments.count,
                isSelected: isInspectFiles,
                navigateAction: {
                    navigation.revealTab(.allItems)
                }
            ) {
                isInspectFiles.toggle()
            }
            .dashboardCommandPopover(isPresented: $isInspectFiles, arrowEdge: .bottom) {
                attachmentsHUD
            }

            footerShortcutPill(icon: "list.bullet", title: isEnglish ? "All" : "全部事项") {
                navigation.revealTab(.allItems)
            }

            footerShortcutPill(icon: "trash", title: isEnglish ? "Trash" : "废纸篓") {
                navigation.revealTab(.trash)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func assetPill(
        icon: String,
        label: String,
        count: Int,
        isSelected: Bool = false,
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
                Text(verbatim: label)
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                Text(verbatim: "\(count)")
                    .font(DaybookType.badge.monospacedDigit())
                    .contentTransition(.numericText())
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 内容资产纯白微浮胶囊
                    .fill(isSelected ? DaybookPalette.fill.selection : DaybookPalette.fill.surface)
            )
        }
        .buttonStyle(.plain) // control: 内容资产胶囊按钮
        .onHover { hovering in
            if hovering {
                DashboardCommandKeyMonitor.shared.sync()
            }
        }
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
                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 快捷入口胶囊按钮底板
                    .fill(DaybookPalette.fill.surface)
            )
        }
        .buttonStyle(.plain) // control: 快捷入口胶囊按钮
    }

    private func clipboardHUD(items: [ClipboardHistoryRecord]) -> some View {
        DashboardHUDCard(
            icon: "doc.on.clipboard",
            title: isEnglish ? "Clipboard History" : "剪贴板捕获历史",
            subtitle: isEnglish ? "\(items.count) captured items" : "已捕获 \(items.count) 条记录",
            items: items.prefix(6).map {
                .init(
                    symbol: $0.isPinned ? "pin.fill" : "doc.on.clipboard",
                    symbolColor: $0.isPinned ? DaybookPalette.accent.base : DaybookPalette.text.secondary,
                    title: $0.plainText.isEmpty ? (isEnglish ? "[Media / File]" : "[图片或文件]") : $0.plainText,
                    trailing: nil
                )
            },
            emptyText: isEnglish ? "Clipboard history is empty" : "剪贴板历史当前为空",
            actionTitle: isEnglish ? "Open Clipboard View" : "前往剪贴板工作区",
            onAction: {
                isInspectClips = false
                navigation.revealTab(.clipboard)
            }
        )
    }

    private var attachmentsHUD: some View {
        DashboardHUDCard(
            icon: "paperclip",
            title: isEnglish ? "Attachments Library" : "工作台附件库",
            subtitle: isEnglish ? "\(liveAttachments.count) files" : "共 \(liveAttachments.count) 个附件",
            items: liveAttachments.prefix(6).map {
                .init(symbol: "doc", symbolColor: DaybookPalette.text.secondary, title: $0.filename, trailing: nil)
            },
            emptyText: isEnglish ? "No attachments yet" : "当前暂无附件文件",
            actionTitle: isEnglish ? "Open Attachments Library" : "前往附件库工作区",
            onAction: {
                isInspectFiles = false
                navigation.revealTab(.attachments)
            }
        )
    }
}
