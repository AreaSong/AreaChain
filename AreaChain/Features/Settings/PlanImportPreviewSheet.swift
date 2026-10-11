import SwiftUI

/// 导入文件（.md / .json）后的结构化识别预览弹窗模型。
struct PlanImportSession: Identifiable {
    let id = UUID()
    let filename: String
    let snapshot: ExportSnapshot
    let preview: ImportPreview
    let tagNamesByID: [UUID: String]
    let newTagNames: [String]
    let reusedTagNames: [String]
    var privateDiaryIDs: Set<UUID> = []

    var firstTargetDayKey: String? {
        snapshot.todos.first?.dayKey ?? snapshot.diaries.first?.dayKey
    }
}

/// 展示从 Markdown 或 JSON 文件中识别出的任务、子任务、重复事项、手记与标签详情。
struct PlanImportPreviewSheet: View {
    let session: PlanImportSession
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @Environment(\.locale) private var locale
    @State private var markers: Set<String> = []

    private var snapshot: ExportSnapshot { session.snapshot }

    private var totalSubtaskCount: Int {
        snapshot.todos.reduce(0) { $0 + $1.subtasks.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            headerSection
            summaryCardsRow
            if !session.newTagNames.isEmpty || !session.reusedTagNames.isEmpty {
                tagsSummaryBanner
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: DaybookSpacing.lg) {
                    if !snapshot.todos.isEmpty { todosSection }
                    if !snapshot.routines.isEmpty { routinesSection }
                    if !snapshot.diaries.isEmpty { diariesSection }
                }
                .padding(.vertical, DaybookSpacing.xs)
            }
            .daybookScroll()
            Divider()
            footerBar
        }
        .padding(DaybookSpacing.xl)
        .frame(width: 640, height: 560)
        .background(DaybookPalette.fill.page)
        .systemPageMarkers($markers)
        .accessibilityIdentifier("planImport.preview.sheet")
        .accessibilityValue(markers.sorted().joined(separator: " "))
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(DaybookType.title)
                .foregroundStyle(DaybookPalette.accent.base)
            VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
                Text("planImport.preview.title")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .systemPageMarker("planImport.preview.sheet")
                Text(session.filename)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            Spacer()
        }
    }

    private var summaryCardsRow: some View {
        HStack(spacing: DaybookSpacing.sm) {
            statBadge(
                title: "planImport.preview.stat.todos",
                value: "\(snapshot.todos.count)",
                detail: totalSubtaskCount > 0
                    ? L10n.format("planImport.preview.stat.subtasks", locale: locale, totalSubtaskCount)
                    : nil,
                icon: "checkmark.circle"
            )
            statBadge(
                title: "planImport.preview.stat.routines",
                value: "\(snapshot.routines.count)",
                detail: nil,
                icon: "repeat"
            )
            statBadge(
                title: "planImport.preview.stat.diaries",
                value: "\(snapshot.diaries.count)",
                detail: nil,
                icon: "book.closed"
            )
            statBadge(
                title: "planImport.preview.stat.tags",
                value: "\(session.newTagNames.count + session.reusedTagNames.count)",
                detail: session.newTagNames.isEmpty
                    ? nil
                    : L10n.format("planImport.preview.stat.newTags", locale: locale, session.newTagNames.count),
                icon: "tag"
            )
        }
    }

    private func statBadge(
        title: LocalizedStringKey,
        value: String,
        detail: String?,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
            HStack(spacing: DaybookSpacing.xs) {
                Image(systemName: icon)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Text(title)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.xs) {
                Text(value)
                    .font(DaybookType.entity)
                    .foregroundStyle(DaybookPalette.text.primary)
                if let detail {
                    Text(detail)
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookPalette.accent.base)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DaybookSpacing.sm)
        .background(DaybookPalette.fill.surface, in: RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous).stroke(DaybookPalette.border.subtle, lineWidth: 1))
    }

    private var tagsSummaryBanner: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            if !session.newTagNames.isEmpty {
                HStack(spacing: DaybookSpacing.xs) {
                    Text("planImport.preview.tags.new")
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookPalette.accent.base)
                    Text(session.newTagNames.map { "#\($0)" }.joined(separator: "  "))
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(2)
                }
            }
            if !session.reusedTagNames.isEmpty {
                HStack(spacing: DaybookSpacing.xs) {
                    Text("planImport.preview.tags.reused")
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text(session.reusedTagNames.map { "#\($0)" }.joined(separator: "  "))
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, DaybookSpacing.sm)
        .padding(.vertical, DaybookSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DaybookPalette.fill.subtle, in: RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
    }

    // MARK: - 单次任务列表

    private var todosSection: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            sectionHeader("planImport.preview.section.todos", count: snapshot.todos.count, icon: "checklist")
            ForEach(snapshot.todos, id: \.id) { todo in
                todoCard(todo)
            }
        }
    }

    private func todoCard(_ todo: ExportedTodo) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.xs) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(DaybookType.body)
                    .foregroundStyle(todo.isDone ? DaybookPalette.status.success : DaybookPalette.text.secondary)
                Text(todo.title)
                    .font(DaybookType.body.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                Spacer()
                pillBadge(todo.dayKey, tint: DaybookPalette.accent.base, fill: DaybookPalette.accent.fill)
                if let prio = priorityLabel(important: todo.isImportant, urgent: todo.isUrgent) {
                    pillBadge(prio, tint: DaybookPalette.status.danger, fill: DaybookPalette.fill.hover)
                }
                if let time = formatMinutes(todo.remindMinutes) {
                    pillBadge("⏰ \(time)", tint: DaybookPalette.text.secondary, fill: DaybookPalette.fill.hover)
                }
            }
            let tags = resolveTagNames(todo.tagIDs)
            if !tags.isEmpty {
                tagLine(tags)
            }
            if !todo.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
                    ForEach(todo.subtasks, id: \.id) { sub in
                        subtaskRow(sub)
                    }
                }
                .padding(.leading, DaybookSpacing.lg)
            }
            if !todo.notes.isEmpty {
                Text(todo.notes)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(3)
                    .padding(.leading, DaybookSpacing.lg)
            }
        }
        .padding(DaybookSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DaybookPalette.fill.surface, in: RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous).stroke(DaybookPalette.border.subtle, lineWidth: 1))
    }

    private func subtaskRow(_ sub: ExportedSubtask) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.xs) {
            Image(systemName: sub.isDone ? "checkmark.square.fill" : "square")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.tertiary)
            Text(sub.title)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.primary)
            let subTags = resolveTagNames(sub.tagIDs)
            if !subTags.isEmpty {
                Text(subTags.map { "#\($0)" }.joined(separator: " "))
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.Syntax.tag)
            }
        }
    }

    // MARK: - 重复事项列表

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            sectionHeader("planImport.preview.section.routines", count: snapshot.routines.count, icon: "repeat")
            ForEach(snapshot.routines, id: \.id) { routine in
                routineCard(routine)
            }
        }
    }

    private func routineCard(_ routine: ExportedRoutine) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.xs) {
                Image(systemName: "repeat.circle")
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.accent.base)
                Text(routine.title)
                    .font(DaybookType.body.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                Spacer()
                pillBadge(
                    weekdayDescription(routine.weekdayMask),
                    tint: DaybookPalette.accent.base,
                    fill: DaybookPalette.accent.fill
                )
                if let prio = priorityLabel(important: routine.isImportant, urgent: routine.isUrgent) {
                    pillBadge(prio, tint: DaybookPalette.status.danger, fill: DaybookPalette.fill.hover)
                }
                if let time = formatMinutes(routine.remindMinutes) {
                    pillBadge("⏰ \(time)", tint: DaybookPalette.text.secondary, fill: DaybookPalette.fill.hover)
                }
            }
            let tags = resolveTagNames(routine.tagIDs)
            if !tags.isEmpty { tagLine(tags) }
            if !routine.notes.isEmpty {
                Text(routine.notes)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(3)
                    .padding(.leading, DaybookSpacing.lg)
            }
        }
        .padding(DaybookSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DaybookPalette.fill.surface, in: RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous).stroke(DaybookPalette.border.subtle, lineWidth: 1))
    }

    // MARK: - 灵感手记列表

    private var diariesSection: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            sectionHeader("planImport.preview.section.diaries", count: snapshot.diaries.count, icon: "book.closed")
            ForEach(snapshot.diaries, id: \.id) { diary in
                diaryCard(diary)
            }
        }
    }

    private func diaryCard(_ diary: ExportedDiary) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            HStack(spacing: DaybookSpacing.xs) {
                pillBadge(diary.dayKey, tint: DaybookPalette.accent.base, fill: DaybookPalette.accent.fill)
                if session.privateDiaryIDs.contains(diary.id) {
                    pillBadge(
                        "🔒 " + L10n.string("diary.private.title", locale: locale),
                        tint: DaybookPalette.accent.base,
                        fill: DaybookPalette.accent.fill
                    )
                }
                if diary.isPinned {
                    pillBadge("📌", tint: DaybookPalette.status.pending, fill: DaybookPalette.fill.hover)
                }
                let tags = resolveTagNames(diary.tagIDs)
                if !tags.isEmpty { tagLine(tags) }
                Spacer()
            }
            Text(diary.text)
                .font(DaybookType.body)
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(3)
        }
        .padding(DaybookSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DaybookPalette.fill.surface, in: RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous).stroke(DaybookPalette.border.subtle, lineWidth: 1))
    }

    // MARK: - 底部与通用辅助

    private var footerBar: some View {
        HStack {
            Text(session.preview.summary(locale: locale))
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(2)
            Spacer()
            Button("alert.cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(DaybookButtonStyle(.quiet))
                .accessibilityIdentifier("planImport.preview.cancel")
                .systemPageMarker("planImport.preview.cancel")
            Button("planImport.preview.confirm", action: onConfirm)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(DaybookButtonStyle(.prominent))
                .accessibilityIdentifier("planImport.preview.confirm")
                .systemPageMarker("planImport.preview.confirm")
        }
    }

    private func sectionHeader(_ key: LocalizedStringKey, count: Int, icon: String) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            Image(systemName: icon)
                .font(DaybookType.section)
                .foregroundStyle(DaybookPalette.accent.base)
            Text(key)
                .font(DaybookType.section)
                .foregroundStyle(DaybookPalette.text.primary)
            Text("(\(count))")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
        }
    }

    private func pillBadge(_ text: String, tint: Color, fill: Color) -> some View {
        Text(text)
            .font(DaybookType.badge)
            .foregroundStyle(tint)
            .padding(.horizontal, DaybookSpacing.xs)
            .padding(.vertical, DaybookSpacing.xxs)
            .background(fill, in: RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous))
    }

    private func tagLine(_ names: [String]) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            ForEach(names, id: \.self) { name in
                pillBadge("#\(name)", tint: DaybookPalette.Syntax.tag, fill: DaybookPalette.Syntax.tagSubtleFill)
            }
        }
    }

    private func resolveTagNames(_ rawIDs: String) -> [String] {
        TagIDList.parse(rawIDs).compactMap { session.tagNamesByID[$0] }
    }

    private func priorityLabel(important: Bool, urgent: Bool) -> String? {
        switch (important, urgent) {
        case (true, true): return "P1"
        case (true, false): return "P2"
        case (false, true): return "P3"
        case (false, false): return nil
        }
    }

    private func formatMinutes(_ minutes: Int?) -> String? {
        guard let minutes else { return nil }
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func weekdayDescription(_ mask: Int) -> String {
        let resolved = WeekdayMask.sanitized(mask)
        if resolved == WeekdayMask.all { return L10n.string("planImport.weekday.daily", locale: locale) }
        if resolved == WeekdayMask.workdays { return L10n.string("planImport.weekday.workdays", locale: locale) }
        let order = [2, 3, 4, 5, 6, 7, 1]
        let hits = order
            .filter { WeekdayMask.contains(resolved, weekday: $0) }
            .map { WeekdayMask.accessibilityName($0, locale: locale, calendar: .current) }
        let separator = locale.language.languageCode?.identifier == "en" ? ", " : "、"
        return hits.joined(separator: separator)
    }
}
