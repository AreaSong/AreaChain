import AppKit
import SwiftUI

// MARK: - 1. 图标网格视图 (Grid View)

struct AttachmentGridView: View {
    let ctx: AttachmentViewContext
    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 230), spacing: DaybookSpacing.sm)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DaybookSpacing.sm) {
                ForEach(ctx.items) { item in
                    AttachmentGridCellView(item: item, ctx: ctx)
                }
            }
        }
        .daybookScroll()
    }
}

private struct AttachmentGridCellView: View {
    let item: AttachmentLibraryItem
    let ctx: AttachmentViewContext

    private var isSelected: Bool { ctx.selection.contains(item.storageID) }
    private var isRenaming: Bool { ctx.renamingStorageID == item.storageID }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            topActionRow
            previewButton
            titleBlock
            footerTagsRow
        }
        .padding(DaybookSpacing.sm)
        .daybookSurface(.card, isSelected: isSelected)
        .contextMenu {
            Button("attachments.view") { ctx.onPreview(item.primaryReference) }
            Button("attachments.rename") { ctx.onBeginRename(item) }
            Button("attachments.copyToken") { ctx.onCopyToken(item) }
            Divider()
            Button("attachments.delete", role: .destructive) { ctx.onDelete(item) }
        }
    }

    private var topActionRow: some View {
        HStack(spacing: 4) {
            Button {
                ctx.onToggleSelect(item.storageID)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
            }
            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            .accessibilityIdentifier("attachments.select." + item.storageID.uuidString)

            Spacer()

            DaybookIconButton(systemName: "eye", label: "attachments.view", size: .compact) {
                ctx.onPreview(item.primaryReference)
            }
            .accessibilityIdentifier("attachments.view." + item.primaryReference.id.uuidString)
            DaybookIconButton(systemName: "at", label: "attachments.copyToken", size: .compact) {
                ctx.onCopyToken(item)
            }
            DaybookIconButton(systemName: "pencil", label: "attachments.rename", size: .compact) {
                ctx.onBeginRename(item)
            }
            DaybookIconButton(systemName: "trash", label: "attachments.delete", size: .compact) {
                ctx.onDelete(item)
            }
        }
    }

    private var previewButton: some View {
        Button {
            ctx.onPreview(item.primaryReference)
        } label: {
            AttachmentPreviewBox(image: ctx.loadImage(item.primaryReference), height: 112, fill: true)
        }
        .buttonStyle(DaybookButtonStyle(.quiet))
        .accessibilityLabel(item.filename)
        .accessibilityIdentifier("attachments.preview." + item.primaryReference.id.uuidString)
    }

    @ViewBuilder
    private var titleBlock: some View {
        if isRenaming {
            HStack(spacing: 4) {
                DaybookTextField(
                    text: ctx.$renameDraft,
                    placeholder: item.filename,
                    fontSize: DaybookType.captionSize,
                    focus: .constant(true),
                    onSubmit: { ctx.onCommitRename(item) },
                    allowsShiftNewline: false,
                    onEscape: ctx.onCancelRename
                )
                Button("common.save") { ctx.onCommitRename(item) }
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .font(DaybookType.caption.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                    .onTapGesture(count: 2) { ctx.onBeginRename(item) }
                Text(AttachmentSyntax.spelling(for: item.filename))
                    .font(DaybookType.kbd)
                    .foregroundStyle(DaybookPalette.accent.base)
                    .lineLimit(1)
            }
        }
    }

    private var footerTagsRow: some View {
        let uniqueTags = Array(item.references.flatMap(\.tags).prefix(2))
        return HStack(spacing: 4) {
            if item.isUnlinked {
                Text("attachments.filter.unlinked")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.tertiary)
            } else {
                Text("attachments.reference.count \(item.referenceCount)")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            Spacer(minLength: 2)
            ForEach(uniqueTags) { tag in
                DaybookChip(
                    tint: DaybookPalette.tagMark(name: tag.name, token: tag.colorToken.rawValue),
                    isSelected: true
                ) {
                    Text("#\(tag.name)")
                }
            }
        }
    }
}

// MARK: - 3. 三栏分栏视图 (Columns View)

struct AttachmentColumnsView: View {
    let ctx: AttachmentViewContext
    @Binding var focusedStorageID: UUID?

    private var activeItem: AttachmentLibraryItem? {
        if let focusedStorageID, let match = ctx.items.first(where: { $0.storageID == focusedStorageID }) {
            return match
        }
        return ctx.items.first
    }

    var body: some View {
        HStack(spacing: 0) {
            attachmentsColumn.frame(width: 200)
            DaybookDivider()
            referencesColumn.frame(width: 240)
            DaybookDivider()
            inspectorColumn.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 360)
        .daybookSurface(.card)
    }

    private var attachmentsColumn: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(ctx.items) { item in
                    columnAttachmentRow(item)
                }
            }
            .padding(DaybookSpacing.xs)
        }
        .daybookScroll()
    }

    private func columnAttachmentRow(_ item: AttachmentLibraryItem) -> some View {
        let isFocused = activeItem?.storageID == item.storageID
        let isChecked = ctx.selection.contains(item.storageID)
        return HStack(spacing: 6) {
            Button {
                ctx.onToggleSelect(item.storageID)
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(DaybookType.caption)
                    .foregroundStyle(isChecked ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
            }
            .buttonStyle(.plain) // control: 分栏列表多选勾选框

            Button {
                focusedStorageID = item.storageID
            } label: {
                HStack(spacing: 6) {
                    AttachmentPreviewBox(image: ctx.loadImage(item.primaryReference), height: 24, fill: true)
                        .frame(width: 24)
                    Text(item.filename)
                        .font(DaybookType.caption.weight(isFocused ? .semibold : .regular))
                        .foregroundStyle(isFocused ? DaybookPalette.accent.base : DaybookPalette.text.primary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    DaybookCount(count: item.referenceCount, emphasis: isFocused)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                        .fill(isFocused ? DaybookPalette.accent.fill : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain) // control: 分栏列表选中切换行
        }
    }

    @ViewBuilder
    private var referencesColumn: some View {
        if let item = activeItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("attachments.reference.count \(item.referenceCount)")
                        .font(DaybookType.badge.weight(.semibold))
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .padding(.horizontal, 4)
                    if item.references.isEmpty {
                        Text("attachments.unlinked.guide \(AttachmentSyntax.spelling(for: item.filename))")
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookPalette.text.secondary)
                            .padding(4)
                    } else {
                        ForEach(item.references) { ref in
                            AttachmentCompactReferenceRow(ref: ref) {
                                ctx.onNavigateReference(ref)
                            }
                        }
                    }
                }
                .padding(DaybookSpacing.xs)
            }
            .daybookScroll()
        }
    }

    @ViewBuilder
    private var inspectorColumn: some View {
        if let item = activeItem {
            VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                Button {
                    ctx.onPreview(item.primaryReference)
                } label: {
                    AttachmentPreviewBox(image: ctx.loadImage(item.primaryReference), height: 180, fill: false)
                }
                .buttonStyle(DaybookButtonStyle(.quiet))
                .accessibilityIdentifier("attachments.preview." + item.primaryReference.id.uuidString)

                Text(item.filename)
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                Text(AttachmentSyntax.spelling(for: item.filename))
                    .font(DaybookType.kbd)
                    .foregroundStyle(DaybookPalette.accent.base)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Button("attachments.view") { ctx.onPreview(item.primaryReference) }
                            .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
                            .fixedSize()
                        if let image = ctx.loadImage(item.primaryReference) {
                            Button("attachments.copyImage") { ctx.onCopyImage(image) }
                                .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
                                .fixedSize()
                        }
                    }
                    HStack(spacing: 6) {
                        Button("attachments.copyToken") { ctx.onCopyToken(item) }
                            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                            .fixedSize()
                        Button("attachments.delete", role: .destructive) { ctx.onDelete(item) }
                            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                            .fixedSize()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(DaybookSpacing.sm)
        }
    }
}

// MARK: - 4. 画廊预览视图 (Gallery View)

struct AttachmentGalleryView: View {
    let ctx: AttachmentViewContext
    @Binding var focusedStorageID: UUID?

    private var activeItem: AttachmentLibraryItem? {
        ctx.items.first { $0.storageID == focusedStorageID } ?? ctx.items.first
    }

    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            if let item = activeItem {
                HStack(alignment: .top, spacing: DaybookSpacing.sm) {
                    heroCanvas(item).frame(maxWidth: .infinity, minHeight: 280).daybookSurface(.card)
                    gallerySidePanel(item).frame(width: 260).daybookSurface(.card)
                }
            }
            filmstripBar.daybookSurface(.card)
        }
    }

    private func heroCanvas(_ item: AttachmentLibraryItem) -> some View {
        VStack(spacing: DaybookSpacing.xs) {
            HStack {
                Text(item.filename)
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                Text(AttachmentSyntax.spelling(for: item.filename))
                    .font(DaybookType.kbd)
                    .foregroundStyle(DaybookPalette.accent.base)
                Spacer()
                DaybookIconButton(systemName: "eye", label: "attachments.view", size: .compact) {
                    ctx.onPreview(item.primaryReference)
                }
                .accessibilityIdentifier("attachments.preview." + item.primaryReference.id.uuidString)
                DaybookIconButton(systemName: "at", label: "attachments.copyToken", size: .compact) { ctx.onCopyToken(item) }
                DaybookIconButton(systemName: "pencil", label: "attachments.rename", size: .compact) { ctx.onBeginRename(item) }
                DaybookIconButton(systemName: "trash", label: "attachments.delete", size: .compact) { ctx.onDelete(item) }
            }
            AttachmentPreviewBox(image: ctx.loadImage(item.primaryReference), height: 240, fill: false)
        }
        .padding(DaybookSpacing.sm)
    }

    private func gallerySidePanel(_ item: AttachmentLibraryItem) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text("attachments.reference.count \(item.referenceCount)")
                .font(DaybookType.caption.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.primary)
            DaybookDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if item.references.isEmpty {
                        Text("attachments.unlinked.guide \(AttachmentSyntax.spelling(for: item.filename))")
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookPalette.text.secondary)
                    } else {
                        ForEach(item.references) { ref in
                            AttachmentCompactReferenceRow(ref: ref) {
                                ctx.onNavigateReference(ref)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 240)
            .daybookScroll()
        }
        .padding(DaybookSpacing.sm)
    }

    private var filmstripBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DaybookSpacing.xs) {
                ForEach(ctx.items) { item in
                    filmstripThumb(item)
                }
            }
            .padding(DaybookSpacing.xs)
        }
    }

    private func filmstripThumb(_ item: AttachmentLibraryItem) -> some View {
        let isFocused = activeItem?.storageID == item.storageID
        return Button {
            focusedStorageID = item.storageID
        } label: {
            AttachmentPreviewBox(image: ctx.loadImage(item.primaryReference), height: 56, fill: true)
                .frame(width: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                        .strokeBorder(
                            isFocused ? DaybookPalette.accent.base : DaybookPalette.border.default,
                            lineWidth: isFocused ? 2.0 : 0.8
                        )
                )
        }
        .buttonStyle(.plain) // control: 画廊底部胶片缩略图切换按钮
        .help(item.filename)
    }
}

// MARK: - 共享预览盒与引用微卡片

private struct AttachmentPreviewBox: View {
    let image: NSImage?
    let height: CGFloat
    let fill: Bool

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fill ? .fill : .fit)
            } else {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookPalette.fill.subtle)
                    .overlay(
                        Image(systemName: "photo")
                            .font(height <= 32 ? DaybookType.micro : DaybookType.subtitle)
                            .foregroundStyle(DaybookPalette.text.secondary)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
    }
}

private struct AttachmentCompactReferenceRow: View {
    @Environment(\.locale) private var locale
    let ref: AttachmentReferenceItem
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: iconName)
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.accent.base)
                    Text(ref.title)
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.right")
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.text.tertiary)
                }
                HStack(spacing: 4) {
                    if ref.kind == .todo || ref.kind == .routine {
                        QuadrantBadge(
                            slot: QuadrantSlot.of(important: ref.isImportant, urgent: ref.isUrgent),
                            isHighlighted: true
                        )
                    }
                    ForEach(ref.tags.prefix(2)) { tag in
                        DaybookChip(
                            tint: DaybookPalette.tagMark(name: tag.name, token: tag.colorToken.rawValue),
                            isSelected: true
                        ) {
                            Text("#\(tag.name)")
                        }
                    }
                    if let remindMinutes = ref.remindMinutes {
                        Text(RemindMinutes.label(remindMinutes, locale: locale))
                            .font(DaybookType.micro)
                            .foregroundStyle(DaybookPalette.text.secondary)
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookPalette.fill.subtle)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 分栏/画廊内引用事项跳转卡片
    }

    private var iconName: String {
        switch ref.kind {
        case .todo: "checkmark.circle"
        case .routine: "repeat"
        case .diary: "note.text"
        }
    }
}
