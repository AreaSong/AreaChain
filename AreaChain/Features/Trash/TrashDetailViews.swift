import AppKit
import SwiftUI

// MARK: - 1. 列表视图增强卡片 (List Card View)

struct TrashListCardView: View {
    let item: TrashRow
    let isSelected: Bool
    var loadThumbnail: (AttachmentRef) -> NSImage?
    var onSelect: () -> Void
    var onRestore: () -> Void
    var onPurge: () -> Void

    @Environment(\.locale) private var locale
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: DaybookSpacing.sm) {
            leadingVisual
            VStack(alignment: .leading, spacing: 4) {
                titleRow
                subtitleRow
            }
            Spacer(minLength: DaybookSpacing.md)
            trailingActions
        }
        .daybookSurface(.card, isHovered: isHovered, isSelected: isSelected) { config in
            config.radius = DaybookRadius.small
            config.padding = EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 12)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trash.row." + item.id.uuidString)
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if case .attachment(let att) = item.detail {
            if att.isPrivate {
                attachmentIconBox(systemName: "lock.fill")
            } else if let thumb = loadThumbnail(att.reference) {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 38)
                    .background(DaybookPalette.fill.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                            .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.6)
                    )
            } else {
                attachmentIconBox(systemName: "photo")
            }
        }
    }

    private func attachmentIconBox(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(DaybookType.subtitle)
            .foregroundStyle(DaybookPalette.text.secondary)
            .frame(width: 44, height: 36)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                    .fill(DaybookPalette.fill.subtle)
            )
    }

    private var titleRow: some View {
        HStack(spacing: DaybookSpacing.xs) {
            if item.isResident {
                Image(systemName: "repeat")
                    .font(DaybookType.badge.weight(.bold))
                    .foregroundStyle(DaybookPalette.accent.base)
            }
            Text(item.kindLabel)
                .font(DaybookType.badge.weight(.medium))
                .foregroundStyle(DaybookPalette.text.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                        .fill(DaybookPalette.fill.hover)
                )
            if case .tag(let tag) = item.detail {
                DaybookStatusDot(
                    color: DaybookPalette.tagMark(name: item.displayTitle, token: tag.colorToken),
                    size: 8
                )
            }
            Text(item.displayTitle)
                .font(DaybookType.body)
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(2)
                .truncationMode(AppPreferences.shared.contentTruncation.textTruncation)
        }
    }

    @ViewBuilder
    private var subtitleRow: some View {
        switch item.detail {
        case .todo(let todo):
            todoSubtitle(todo)
        case .routine(let routine):
            routineSubtitle(routine)
        case .diary(let diary):
            diarySubtitle(diary)
        case .attachment(let att):
            attachmentSubtitle(att)
        case .tag(let tag):
            tagSubtitle(tag)
        case nil:
            EmptyView()
        }
    }

    private func todoSubtitle(_ todo: TrashTodoDetail) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            QuadrantBadge(slot: todo.quadrantSlot, isHighlighted: true)
            Text(DayKey.displayName(todo.dayKey, locale: locale))
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            if !todo.subtasks.isEmpty {
                Label("\(todo.completedSubtaskCount)/\(todo.subtasks.count)", systemImage: "checklist")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            if todo.attachmentCount > 0 {
                Label("\(todo.attachmentCount)", systemImage: "paperclip")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            if !todo.notes.isEmpty {
                Text(verbatim: todo.notes.replacingOccurrences(of: "\n", with: " "))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
                    .lineLimit(1)
            }
            tagChips(todo.tags)
        }
    }

    private func routineSubtitle(_ routine: TrashRoutineDetail) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            QuadrantBadge(slot: routine.quadrantSlot, isHighlighted: true)
            Text(WeekdayMask.selectedLabels(routine.weekdayMask, locale: locale))
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(1)
            if routine.attachmentCount > 0 {
                Label("\(routine.attachmentCount)", systemImage: "paperclip")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            if !routine.notes.isEmpty {
                Text(verbatim: routine.notes.replacingOccurrences(of: "\n", with: " "))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
                    .lineLimit(1)
            }
            tagChips(routine.tags)
        }
    }

    private func diarySubtitle(_ diary: TrashDiaryDetail) -> some View {
        let isPrivate = diary.isPrivateProvider()
        return HStack(spacing: DaybookSpacing.xs) {
            Text(DayKey.displayName(diary.dayKey, locale: locale))
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            if isPrivate {
                Image(systemName: "lock.fill")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.tertiary)
            } else {
                if diary.attachmentCount > 0 {
                    Label("\(diary.attachmentCount)", systemImage: "paperclip")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
                tagChips(diary.tagsProvider())
            }
        }
    }

    private func attachmentSubtitle(_ att: TrashAttachmentDetail) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            if let ownerTitle = att.ownerTitle, !ownerTitle.isEmpty {
                Label(ownerTitle, systemImage: TrashFormatting.ownerIcon(att.ownerKind))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(1)
            }
            if att.ownerDeleted {
                Text("trash.restore.blocked")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.pending)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func tagSubtitle(_ tag: TrashTagDetail) -> some View {
        if tag.isDiaryPreset || tag.isPrivateDiary {
            HStack(spacing: DaybookSpacing.xs) {
                if tag.isPrivateDiary {
                    Label("privacy.settings.title", systemImage: "lock.fill")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
                if tag.isDiaryPreset {
                    Text("trash.detail.presetTag")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.tertiary)
                }
            }
        }
    }

    private func tagChips(_ tags: [TrashTagSummary]) -> some View {
        ForEach(tags.prefix(2)) { tag in
            DaybookChip(
                tint: DaybookPalette.tagMark(name: tag.name, token: tag.colorToken),
                isSelected: true
            ) {
                Text("#\(tag.name)")
            }
        }
    }

    private var trailingActions: some View {
        HStack(spacing: DaybookSpacing.sm) {
            Text(ClockLabel.created(item.deletedAt, locale: locale))
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            HStack(spacing: 6) {
                Button("trash.restore", action: onRestore)
                    .buttonStyle(DaybookButtonStyle(.prominent))
                    .disabled(!item.canRestore)
                    .help(item.canRestore ? "trash.restore" : "trash.restore.blocked")
                Button("trash.purge", role: .destructive, action: onPurge)
                    .buttonStyle(DaybookButtonStyle(.destructive))
                    .disabled(!item.canPurge)
            }
            .font(DaybookType.caption)
        }
    }
}

// MARK: - 2. 网格视图卡片 (Grid Card View)

struct TrashGridCardView: View {
    let item: TrashRow
    let isSelected: Bool
    var loadThumbnail: (AttachmentRef) -> NSImage?
    var onSelect: () -> Void
    var onRestore: () -> Void
    var onPurge: () -> Void

    @Environment(\.locale) private var locale
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            cardHeader
            cardStage
            cardFooter
        }
        .daybookSurface(.card, isHovered: isHovered, isSelected: isSelected) { config in
            config.padding = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trash.grid." + item.id.uuidString)
    }

    private var cardHeader: some View {
        HStack(spacing: DaybookSpacing.xs) {
            if item.isResident {
                Image(systemName: "repeat")
                    .font(DaybookType.badge.weight(.bold))
                    .foregroundStyle(DaybookPalette.accent.base)
            }
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
                .font(DaybookType.caption.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(ClockLabel.created(item.deletedAt, locale: locale))
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var cardStage: some View {
        if case .attachment(let att) = item.detail, !att.isPrivate, let thumb = loadThumbnail(att.reference) {
            ZStack {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookPalette.fill.subtle)
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFit()
                    .padding(DaybookSpacing.xxs)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        } else {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookPalette.fill.subtle)
                stageSummaryContent
                    .padding(DaybookSpacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 116)
        }
    }

    @ViewBuilder
    private var stageSummaryContent: some View {
        switch item.detail {
        case .todo(let todo):
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(DaybookType.caption.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(2)
                if !todo.notes.isEmpty {
                    Text(verbatim: todo.notes)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(2)
                }
                ForEach(todo.subtasks.prefix(2)) { sub in
                    HStack(spacing: 4) {
                        Image(systemName: sub.isDone ? "checkmark.circle.fill" : "circle")
                            .font(DaybookType.micro)
                            .foregroundStyle(sub.isDone ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
                        Text(sub.title)
                            .font(DaybookType.micro)
                            .foregroundStyle(DaybookPalette.text.secondary)
                            .lineLimit(1)
                    }
                }
            }
        case .routine(let routine):
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(DaybookType.caption.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(2)
                Text(WeekdayMask.selectedLabels(routine.weekdayMask, locale: locale))
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.accent.base)
                    .lineLimit(1)
                if !routine.notes.isEmpty {
                    Text(verbatim: routine.notes)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(2)
                }
            }
        case .diary(let diary):
            VStack(alignment: .leading, spacing: 4) {
                Text(DayKey.displayName(diary.dayKey, locale: locale))
                    .font(DaybookType.micro.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.tertiary)
                Text(diary.fullTextProvider())
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(4)
            }
        case .attachment(let att):
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: att.isPrivate ? "lock.fill" : "photo")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Text(item.displayTitle)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(2)
            }
        case .tag(let tag):
            VStack(alignment: .leading, spacing: 6) {
                DaybookChip(
                    tint: DaybookPalette.tagMark(name: item.displayTitle, token: tag.colorToken),
                    isSelected: true
                ) {
                    Text("#\(item.displayTitle)")
                }
                if tag.isDiaryPreset {
                    Text("trash.detail.presetTag")
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
            }
        case nil:
            Text(item.displayTitle)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(4)
        }
    }

    private var cardFooter: some View {
        HStack(spacing: DaybookSpacing.xs) {
            Text(verbatim: TrashFormatting.footerSummary(for: item, locale: locale))
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("trash.restore", action: onRestore)
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                .disabled(!item.canRestore)
                .help(item.canRestore ? "trash.restore" : "trash.restore.blocked")
            Button("trash.purge", role: .destructive, action: onPurge)
                .buttonStyle(DaybookButtonStyle(.destructive, size: .compact))
                .disabled(!item.canPurge)
        }
    }
}
