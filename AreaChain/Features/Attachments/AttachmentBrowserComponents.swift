import AppKit
import SwiftUI

struct AttachmentBrowserFilterBar: View {
    @Environment(\.locale) private var locale

    @Binding var filter: AttachmentFilterKind
    @Binding var sort: AttachmentSortOrder
    @Binding var boardFilter: BoardFilter
    var tags: [CatalogChoice]
    var tagCounts: [UUID: Int] = [:]
    var untaggedCount: Int?
    var counts: [AttachmentFilterKind: Int]
    var totalDisplayed: Int
    var selectedCount: Int
    var onToggleSelectAll: () -> Void

    @State private var activeDropdown: ActiveDropdown?

    private enum ActiveDropdown: Hashable {
        case type, sort
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DaybookSpacing.xs) {
                leadingCapsules
                Spacer(minLength: DaybookSpacing.xs)
                trailingFilterBar
            }
            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                leadingCapsules
                trailingFilterBar
            }
        }
    }

    private var leadingCapsules: some View {
        HStack(spacing: 6) {
            typeDropdown
            sortDropdown
            selectAllChip
        }
        .font(DaybookType.caption)
    }

    private var trailingFilterBar: some View {
        BoardFilterBar(
            filter: boardFilter,
            tags: tags,
            bundleIDs: [],
            tagCounts: tagCounts,
            untaggedCount: untaggedCount,
            showsPriority: true,
            showsReminder: true,
            showsDate: true,
            onChange: { boardFilter = $0 }
        )
    }

    private var typeDropdown: some View {
        let isExpanded = Binding(
            get: { activeDropdown == .type },
            set: { activeDropdown = $0 ? .type : nil }
        )
        let active = filter != .all
        let title = active
            ? L10n.string(filterKey(filter), locale: locale)
            : L10n.string("attachments.scope.type", locale: locale)
        let allOption = FilterDropdownOption(
            id: "all",
            title: L10n.string("attachments.filter.all", locale: locale),
            icon: "paperclip",
            count: counts[.all],
            isSelected: filter == .all,
            action: { filter = .all }
        )
        let items: [FilterDropdownOption] = [.todo, .routine, .diary, .unlinked].map { kind in
            FilterDropdownOption(
                id: kind.rawValue,
                title: L10n.string(filterKey(kind), locale: locale),
                icon: filterIcon(kind),
                count: counts[kind],
                isSelected: filter == kind,
                action: { filter = kind }
            )
        }
        return BoardFilterDropdownButton(
            icon: "paperclip",
            title: title,
            active: active,
            isExpanded: isExpanded,
            reset: { filter = .all },
            allOption: allOption,
            items: items
        )
        .accessibilityIdentifier("attachments.filter.type")
    }

    private var sortDropdown: some View {
        let isExpanded = Binding(
            get: { activeDropdown == .sort },
            set: { activeDropdown = $0 ? .sort : nil }
        )
        let active = sort != .newest
        let items = AttachmentSortOrder.allCases.map { order in
            FilterDropdownOption(
                id: order.rawValue,
                title: L10n.string(sortKey(order), locale: locale),
                icon: sortIcon(order),
                isSelected: sort == order,
                action: { sort = order }
            )
        }
        return BoardFilterDropdownButton(
            icon: "arrow.up.arrow.down",
            title: L10n.string(sortKey(sort), locale: locale),
            active: active,
            isExpanded: isExpanded,
            reset: { sort = .newest },
            allOption: nil,
            items: items
        )
        .accessibilityIdentifier("attachments.sort.menu")
    }

    @ViewBuilder
    private var selectAllChip: some View {
        if totalDisplayed > 0 {
            let allSelected = selectedCount == totalDisplayed && totalDisplayed > 0
            DaybookChip(
                tint: DaybookPalette.accent.base,
                isSelected: allSelected,
                action: onToggleSelectAll
            ) {
                HStack(spacing: 4) {
                    Image(systemName: allSelected ? "checkmark.circle.fill" : "checkmark.circle")
                    Text(allSelected ? "attachments.deselectAll" : "attachments.selectAll")
                        .lineLimit(1)
                }
            }
            .accessibilityIdentifier("attachments.selectAll")
        }
    }

    private func filterKey(_ kind: AttachmentFilterKind) -> String.LocalizationValue {
        switch kind {
        case .all: "attachments.filter.all"
        case .todo: "attachments.owner.todo"
        case .routine: "attachments.owner.routine"
        case .diary: "attachments.owner.diary"
        case .unlinked: "attachments.filter.unlinked"
        }
    }

    private func filterIcon(_ kind: AttachmentFilterKind) -> String {
        switch kind {
        case .all: "paperclip"
        case .todo: "checkmark.circle"
        case .routine: "repeat"
        case .diary: "note.text"
        case .unlinked: "tray"
        }
    }

    private func sortKey(_ order: AttachmentSortOrder) -> String.LocalizationValue {
        switch order {
        case .newest: "attachments.sort.newest"
        case .oldest: "attachments.sort.oldest"
        case .name: "attachments.sort.name"
        case .referenceCount: "attachments.sort.references"
        }
    }

    private func sortIcon(_ order: AttachmentSortOrder) -> String {
        switch order {
        case .newest: "clock.badge.checkmark"
        case .oldest: "clock"
        case .name: "textformat.abc"
        case .referenceCount: "link"
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
    @Environment(\.locale) private var locale

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
            Button("attachments.view", action: onPreview)
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
                DaybookIconButton(systemName: "eye", label: "attachments.view", size: .compact, action: onPreview)
                    .accessibilityIdentifier("attachments.view." + item.primaryReference.id.uuidString)
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

                referenceBadges(ref)

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

    @ViewBuilder
    private func referenceBadges(_ ref: AttachmentReferenceItem) -> some View {
        if ref.kind == .todo || ref.kind == .routine {
            let slot = QuadrantSlot.of(important: ref.isImportant, urgent: ref.isUrgent)
            QuadrantBadge(slot: slot, isHighlighted: true)
        }

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

        if let remindMinutes = ref.remindMinutes {
            DaybookChip(tint: DaybookPalette.accent.base, isSelected: false) {
                HStack(spacing: 2.5) {
                    Image(systemName: "clock")
                    Text(RemindMinutes.label(remindMinutes, locale: locale))
                }
            }
        }
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
