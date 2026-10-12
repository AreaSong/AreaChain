import AppKit
import SwiftUI

struct AttachmentBrowserFilterBar: View {
    @Binding var filter: AttachmentFilterKind
    @Binding var sort: AttachmentSortOrder
    var counts: [AttachmentFilterKind: Int]
    var totalDisplayed: Int
    var selectedCount: Int
    var onToggleSelectAll: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DaybookSpacing.xs) {
                filterButtons
                Spacer(minLength: DaybookSpacing.xs)
                trailingControls
            }
            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                HStack(spacing: DaybookSpacing.xs) { filterButtons }
                HStack(spacing: DaybookSpacing.xs) { trailingControls }
            }
        }
    }

    @ViewBuilder
    private var filterButtons: some View {
        ForEach(AttachmentFilterKind.allCases) { item in
            let count = counts[item] ?? 0
            Button {
                filter = item
            } label: {
                HStack(spacing: 4) {
                    Text(filterTitle(item))
                    Text("\(count)")
                        .font(DaybookType.micro)
                        .foregroundStyle(filter == item ? DaybookPalette.text.onAccent : DaybookPalette.text.tertiary)
                }
            }
            .buttonStyle(DaybookButtonStyle(filter == item ? .prominent : .quiet, size: .compact))
            .accessibilityIdentifier("attachments.filter." + item.rawValue)
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        if totalDisplayed > 0 {
            let allSelected = selectedCount == totalDisplayed && totalDisplayed > 0
            Button(allSelected ? "attachments.deselectAll" : "attachments.selectAll") {
                onToggleSelectAll()
            }
            .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
            .accessibilityIdentifier("attachments.selectAll")
        }

        Menu {
            ForEach(AttachmentSortOrder.allCases) { order in
                Button {
                    sort = order
                } label: {
                    HStack {
                        Text(sortTitle(order))
                        if sort == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(sortTitle(sort))
            }
            .daybookMenuLabel(size: .compact, fitsLabel: true)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityIdentifier("attachments.sort.menu")
    }

    private func filterTitle(_ kind: AttachmentFilterKind) -> LocalizedStringKey {
        switch kind {
        case .all: "attachments.filter.all"
        case .todo: "attachments.owner.todo"
        case .routine: "attachments.owner.routine"
        case .diary: "attachments.owner.diary"
        case .unlinked: "attachments.filter.unlinked"
        }
    }

    private func sortTitle(_ order: AttachmentSortOrder) -> LocalizedStringKey {
        switch order {
        case .newest: "attachments.sort.newest"
        case .oldest: "attachments.sort.oldest"
        case .name: "attachments.sort.name"
        case .referenceCount: "attachments.sort.references"
        }
    }
}

struct AttachmentSelectionToolbar: View {
    var selectedCount: Int
    var onSelectAll: () -> Void
    var onClearSelection: () -> Void
    var onDeleteSelected: () -> Void

    var body: some View {
        HStack(spacing: DaybookSpacing.sm) {
            Text("attachments.selection.count \(selectedCount)")
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(DaybookPalette.text.primary)
            Spacer()
            Button("attachments.selectAll", action: onSelectAll)
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            Button("attachments.selection.clear", action: onClearSelection)
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            Button("attachments.batch.delete", role: .destructive, action: onDeleteSelected)
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                .accessibilityIdentifier("attachments.batch.delete")
        }
        .padding(.horizontal, DaybookSpacing.sm)
        .padding(.vertical, DaybookSpacing.xs)
        .daybookSurface(.banner)
    }
}

struct AttachmentLibraryCardView: View {
    let item: AttachmentLibraryItem
    let image: NSImage?
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renameDraft: String
    var onToggleSelect: () -> Void
    var onPreview: () -> Void
    var onBeginRename: () -> Void
    var onCommitRename: () -> Void
    var onCancelRename: () -> Void
    var onCopyToken: () -> Void
    var onNavigateReference: (AttachmentReferenceItem) -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            headerRow
            DaybookDivider()
            referencesSection
        }
        .padding(DaybookSpacing.sm)
        .daybookSurface(.card, isSelected: isSelected)
        .contextMenu {
            Button("attachments.rename", action: onBeginRename)
            Button("attachments.copyToken", action: onCopyToken)
            Divider()
            Button("attachments.delete", role: .destructive, action: onDelete)
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: DaybookSpacing.sm) {
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
            }
            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            .accessibilityLabel(item.filename)
            .accessibilityIdentifier("attachments.select." + item.storageID.uuidString)

            Button(action: onPreview) {
                thumbnailView
            }
            .buttonStyle(DaybookButtonStyle(.quiet))
            .accessibilityLabel(item.filename)
            .accessibilityIdentifier("attachments.preview." + item.primaryReference.id.uuidString)
            .help(item.filename)

            VStack(alignment: .leading, spacing: 4) {
                titleRow
                metaRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                DaybookIconButton(systemName: "at", label: "attachments.copyToken", size: .compact, action: onCopyToken)
                DaybookIconButton(systemName: "pencil", label: "attachments.rename", size: .compact, action: onBeginRename)
                DaybookIconButton(systemName: "trash", label: "attachments.delete", size: .compact, action: onDelete)
            }
        }
    }

    @ViewBuilder
    private var titleRow: some View {
        if isRenaming {
            HStack(spacing: DaybookSpacing.xs) {
                DaybookInputShell(kind: .composer, focused: true) {
                    Image(systemName: "pencil")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                } field: {
                    DaybookTextField(
                        text: $renameDraft,
                        placeholder: item.filename,
                        fontSize: DaybookType.bodySize,
                        focus: .constant(true),
                        onSubmit: onCommitRename,
                        allowsShiftNewline: false,
                        onEscape: onCancelRename
                    )
                    .accessibilityIdentifier("attachments.rename.input." + item.storageID.uuidString)
                } trailing: {
                    Button("common.save", action: onCommitRename)
                        .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                    DaybookIconButton(systemName: "xmark", label: "alert.cancel", size: .compact, action: onCancelRename)
                }
            }
        } else {
            HStack(spacing: DaybookSpacing.xs) {
                Text(item.filename)
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                    .onTapGesture(count: 2, perform: onBeginRename)
                Text(AttachmentSyntax.spelling(for: item.filename))
                    .font(DaybookType.kbd)
                    .foregroundStyle(DaybookPalette.accent.base)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                            .fill(DaybookPalette.accent.fill)
                    )
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: DaybookSpacing.xs) {
            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
            Text("·")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
            if item.isUnlinked {
                Text("attachments.filter.unlinked")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.secondary)
            } else {
                Text("attachments.reference.count \(item.referenceCount)")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "photo")
                        .font(DaybookType.title)
                        .foregroundStyle(DaybookPalette.text.secondary)
                )
        }
    }

    @ViewBuilder
    private var referencesSection: some View {
        if item.references.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "link.badge.plus")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
                Text("attachments.unlinked.guide \(AttachmentSyntax.spelling(for: item.filename))")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.references) { ref in
                    referenceRow(ref)
                }
            }
        }
    }

    private func referenceRow(_ ref: AttachmentReferenceItem) -> some View {
        Button {
            onNavigateReference(ref)
        } label: {
            HStack(spacing: DaybookSpacing.xs) {
                Image(systemName: kindIcon(ref.kind))
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.accent.base)
                    .frame(width: 14)

                Text(kindLabel(ref.kind))
                    .font(DaybookType.micro.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                            .fill(DaybookPalette.fill.subtle)
                    )

                Text(ref.title)
                    .font(DaybookType.caption.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)

                if !ref.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(ref.tags) { tag in
                            DaybookChip(
                                tint: DaybookPalette.tagMark(name: tag.name, token: tag.colorToken.rawValue),
                                isSelected: true
                            ) {
                                Text("#\(tag.name)")
                            }
                        }
                    }
                }

                Spacer(minLength: 4)

                if let dayKey = ref.dayKey {
                    Text(dayKey)
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.text.tertiary)
                }

                Image(systemName: "chevron.right")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
        .accessibilityIdentifier("attachments.ref." + ref.id)
    }

    private func kindIcon(_ kind: AttachmentOwner) -> String {
        switch kind {
        case .todo: "checkmark.circle"
        case .routine: "repeat"
        case .diary: "note.text"
        }
    }

    private func kindLabel(_ kind: AttachmentOwner) -> LocalizedStringKey {
        switch kind {
        case .todo: "attachments.owner.todo"
        case .routine: "attachments.owner.routine"
        case .diary: "attachments.owner.diary"
        }
    }
}
