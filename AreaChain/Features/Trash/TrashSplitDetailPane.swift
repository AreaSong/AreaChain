import AppKit
import SwiftUI

@MainActor
enum TrashFormatting {
    static func ownerIcon(_ kind: AttachmentOwner?) -> String {
        switch kind {
        case .todo: "checkmark.circle"
        case .routine: "repeat"
        case .diary: "note.text"
        case nil: "doc"
        }
    }

    static func footerSummary(for item: TrashRow, locale: Locale) -> String {
        switch item.detail {
        case .todo(let todo):
            var parts = [DayKey.displayName(todo.dayKey, locale: locale)]
            if !todo.subtasks.isEmpty {
                parts.append("\(todo.completedSubtaskCount)/\(todo.subtasks.count)")
            }
            if todo.attachmentCount > 0 {
                parts.append("📎 \(todo.attachmentCount)")
            }
            return parts.joined(separator: " · ")
        case .routine(let routine):
            return WeekdayMask.selectedLabels(routine.weekdayMask, locale: locale)
        case .diary(let diary):
            return DayKey.displayName(diary.dayKey, locale: locale)
        case .attachment(let att):
            if let ownerTitle = att.ownerTitle, !ownerTitle.isEmpty {
                return ownerTitle
            }
            return L10n.string("trash.kind.attachment", locale: locale)
        case .tag:
            return "#\(item.displayTitle)"
        case nil:
            return ""
        }
    }

    static func detailedTimestamp(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TrashSplitDetailPane: View {
    let item: TrashRow?
    var loadThumbnail: (AttachmentRef) -> NSImage?
    var loadFullImage: (AttachmentRef) -> NSImage?
    var onRestore: (TrashRow) -> Void
    var onPurge: (TrashRow) -> Void

    @Environment(\.locale) private var locale
    @State private var zoomActualSize = false

    var body: some View {
        Group {
            if let item {
                detailContent(for: item)
            } else {
                DaybookEmptyState(title: "trash.empty", systemImage: "trash")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .daybookSurface(.card) { config in
            config.padding = EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 14)
        }
        .onChange(of: item?.id) { _, _ in
            zoomActualSize = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trash.split.detail")
    }

    private func detailContent(for item: TrashRow) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            detailHeader(for: item)
            DaybookDivider()
            detailStage(for: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            DaybookDivider()
            detailFooter(for: item)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailHeader(for item: TrashRow) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            Image(systemName: item.section.iconName)
                .font(DaybookType.subtitle.weight(.semibold))
                .foregroundStyle(DaybookPalette.accent.base)
            Text(item.kindLabel)
                .font(DaybookType.badge.weight(.medium))
                .foregroundStyle(DaybookPalette.text.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                        .fill(DaybookPalette.fill.hover)
                )
            Text(item.displayTitle)
                .font(DaybookType.subtitle.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(1)
            Spacer(minLength: DaybookSpacing.xs)
            if case .attachment(let att) = item.detail, !att.isPrivate,
               loadFullImage(att.reference) != nil || loadThumbnail(att.reference) != nil {
                Button(zoomActualSize ? "clipboard.zoom.actual" : "clipboard.zoom.fit") {
                    zoomActualSize.toggle()
                }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
            Button("trash.restore") { onRestore(item) }
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                .disabled(!item.canRestore)
                .help(item.canRestore ? "trash.restore" : "trash.restore.blocked")
            Button("trash.purge", role: .destructive) { onPurge(item) }
                .buttonStyle(DaybookButtonStyle(.destructive, size: .compact))
                .disabled(!item.canPurge)
        }
    }

    @ViewBuilder
    private func detailStage(for item: TrashRow) -> some View {
        switch item.detail {
        case .attachment(let att):
            attachmentDetailStage(item: item, att: att)
        case .todo(let todo):
            todoDetailStage(item: item, todo: todo)
        case .routine(let routine):
            routineDetailStage(item: item, routine: routine)
        case .diary(let diary):
            diaryDetailStage(diary: diary)
        case .tag(let tag):
            tagDetailStage(item: item, tag: tag)
        case nil:
            plainStage(text: item.displayTitle)
        }
    }

    private func attachmentDetailStage(item: TrashRow, att: TrashAttachmentDetail) -> some View {
        let displayImage = att.isPrivate ? nil : (loadFullImage(att.reference) ?? loadThumbnail(att.reference))
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookPalette.fill.subtle)
                if let displayImage {
                    if zoomActualSize {
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: displayImage)
                                .padding(DaybookSpacing.sm)
                        }
                        .daybookScroll()
                    } else {
                        Image(nsImage: displayImage)
                            .resizable()
                            .scaledToFit()
                            .padding(DaybookSpacing.sm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: DaybookSpacing.xs) {
                        Image(systemName: att.isPrivate ? "lock.fill" : "photo")
                            .font(DaybookType.title)
                            .foregroundStyle(DaybookPalette.text.secondary)
                        Text(item.displayTitle)
                            .font(DaybookType.body)
                            .foregroundStyle(DaybookPalette.text.secondary)
                    }
                    .padding(DaybookSpacing.md)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.8)
            )
            attachmentOwnerBanner(att)
        }
    }

    @ViewBuilder
    private func attachmentOwnerBanner(_ att: TrashAttachmentDetail) -> some View {
        if att.ownerTitle != nil || att.ownerDeleted {
            HStack(spacing: DaybookSpacing.sm) {
                if let ownerTitle = att.ownerTitle, !ownerTitle.isEmpty {
                    Label(ownerTitle, systemImage: TrashFormatting.ownerIcon(att.ownerKind))
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if att.ownerDeleted {
                    Label("trash.restore.blocked", systemImage: "exclamationmark.triangle")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.status.pending)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, DaybookSpacing.sm)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookPalette.fill.subtle)
            )
        }
    }

    private func todoDetailStage(item: TrashRow, todo: TrashTodoDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                Text(item.displayTitle)
                    .font(DaybookType.entity)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .textSelection(.enabled)
                todoMetaBadges(todo)
                if !todo.notes.isEmpty {
                    notesBlock(todo.notes)
                }
                if !todo.subtasks.isEmpty {
                    subtasksBlock(todo.subtasks)
                }
            }
            .padding(DaybookSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
        )
        .daybookScroll()
    }

    private func todoMetaBadges(_ todo: TrashTodoDetail) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            QuadrantBadge(slot: todo.quadrantSlot, isHighlighted: true)
            Label(DayKey.displayName(todo.dayKey, locale: locale), systemImage: "calendar")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            if let remind = todo.remindMinutes {
                Label(RemindMinutes.label(remind, locale: locale), systemImage: "bell")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            if let due = todo.dueMinutes {
                Label(RemindMinutes.label(due, locale: locale), systemImage: "clock")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            ForEach(todo.tags) { tag in
                DaybookChip(
                    tint: DaybookPalette.tagMark(name: tag.name, token: tag.colorToken),
                    isSelected: true
                ) {
                    Text("#\(tag.name)")
                }
            }
        }
    }

    private func routineDetailStage(item: TrashRow, routine: TrashRoutineDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                Text(item.displayTitle)
                    .font(DaybookType.entity)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .textSelection(.enabled)
                HStack(spacing: DaybookSpacing.xs) {
                    QuadrantBadge(slot: routine.quadrantSlot, isHighlighted: true)
                    Label(WeekdayMask.selectedLabels(routine.weekdayMask, locale: locale), systemImage: "repeat")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.accent.base)
                    if let remind = routine.remindMinutes {
                        Label(RemindMinutes.label(remind, locale: locale), systemImage: "bell")
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookPalette.text.secondary)
                    }
                    ForEach(routine.tags) { tag in
                        DaybookChip(
                            tint: DaybookPalette.tagMark(name: tag.name, token: tag.colorToken),
                            isSelected: true
                        ) {
                            Text("#\(tag.name)")
                        }
                    }
                }
                if !routine.notes.isEmpty {
                    notesBlock(routine.notes)
                }
            }
            .padding(DaybookSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
        )
        .daybookScroll()
    }

    private func diaryDetailStage(diary: TrashDiaryDetail) -> some View {
        let isPrivate = diary.isPrivateProvider()
        return ScrollView {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                HStack(spacing: DaybookSpacing.xs) {
                    Label(DayKey.displayName(diary.dayKey, locale: locale), systemImage: "calendar")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.secondary)
                    if diary.isPinned {
                        Image(systemName: "pin.fill")
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookPalette.accent.base)
                    }
                    if !isPrivate {
                        ForEach(diary.tagsProvider()) { tag in
                            DaybookChip(
                                tint: DaybookPalette.tagMark(name: tag.name, token: tag.colorToken),
                                isSelected: true
                            ) {
                                Text("#\(tag.name)")
                            }
                        }
                    }
                }
                if isPrivate {
                    HStack(spacing: DaybookSpacing.xs) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(DaybookPalette.text.secondary)
                        Text(diary.fullTextProvider())
                            .font(DaybookType.body)
                            .foregroundStyle(DaybookPalette.text.secondary)
                    }
                } else {
                    Text(verbatim: diary.fullTextProvider())
                        .font(DaybookType.body)
                        .foregroundStyle(DaybookPalette.text.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DaybookSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
        )
        .daybookScroll()
    }

    private func tagDetailStage(item: TrashRow, tag: TrashTagDetail) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            HStack(spacing: DaybookSpacing.xs) {
                DaybookStatusDot(
                    color: DaybookPalette.tagMark(name: item.displayTitle, token: tag.colorToken),
                    size: 10
                )
                Text("#\(item.displayTitle)")
                    .font(DaybookType.entity)
                    .foregroundStyle(DaybookPalette.text.primary)
            }
            if tag.isPrivateDiary {
                Label("privacy.settings.title", systemImage: "lock.fill")
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            if tag.isDiaryPreset {
                Label("trash.detail.presetTag", systemImage: "bookmark")
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(DaybookSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
        )
    }

    private func plainStage(text: String) -> some View {
        ScrollView {
            Text(verbatim: text)
                .font(DaybookType.body)
                .foregroundStyle(DaybookPalette.text.primary)
                .textSelection(.enabled)
                .padding(DaybookSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
        )
        .daybookScroll()
    }

    private func notesBlock(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("trash.detail.notes")
                .font(DaybookType.badge.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.secondary)
            Text(verbatim: notes)
                .font(DaybookType.body)
                .foregroundStyle(DaybookPalette.text.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func subtasksBlock(_ subtasks: [TrashSubtaskSummary]) -> some View {
        let doneCount = subtasks.filter(\.isDone).count
        return VStack(alignment: .leading, spacing: 6) {
            Text("trash.detail.subtasks \(doneCount) \(subtasks.count)")
                .font(DaybookType.badge.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.secondary)
            ForEach(subtasks) { sub in
                HStack(spacing: DaybookSpacing.xs) {
                    Image(systemName: sub.isDone ? "checkmark.circle.fill" : "circle")
                        .font(DaybookType.body)
                        .foregroundStyle(sub.isDone ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
                    Text(sub.title)
                        .font(DaybookType.body)
                        .foregroundStyle(sub.isDone ? DaybookPalette.text.done : DaybookPalette.text.primary)
                }
            }
        }
    }

    private func detailFooter(for item: TrashRow) -> some View {
        let deletedString = TrashFormatting.detailedTimestamp(item.deletedAt, locale: locale)
        return HStack(spacing: DaybookSpacing.sm) {
            Label("trash.detail.deletedAt \(deletedString)", systemImage: "trash")
                .font(DaybookType.caption.monospacedDigit())
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(1)
            if let created = createdTimestamp(for: item) {
                Text(verbatim: "·")
                    .foregroundStyle(DaybookPalette.text.tertiary)
                Text("trash.detail.createdAt \(created)")
                    .font(DaybookType.caption.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !item.canRestore {
                Text("trash.restore.blocked")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.pending)
                    .lineLimit(1)
            }
        }
    }

    private func createdTimestamp(for item: TrashRow) -> String? {
        let date: Date? = switch item.detail {
        case .todo(let d): d.createdAt
        case .routine(let d): d.createdAt
        case .diary(let d): d.createdAt
        case .attachment(let d): d.createdAt
        case .tag, nil: nil
        }
        guard let date else { return nil }
        return TrashFormatting.detailedTimestamp(date, locale: locale)
    }
}
