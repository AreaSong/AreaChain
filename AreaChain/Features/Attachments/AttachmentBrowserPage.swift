import AppKit
import SwiftData
import SwiftUI

struct AttachmentBrowserPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.workspaceHostContext) private var hostContext
    @WorkspaceNavigationContext private var navigation
    @Query(filter: SoftDelete.liveAttachments) private var attachments: [AttachmentItem]
    @Query private var tags: [TagItem]

    @State private var viewMode: AttachmentViewMode = .list
    @State private var filter: AttachmentFilterKind = .all
    @State private var sort: AttachmentSortOrder = .newest
    @State private var boardFilter = BoardFilter()
    @State private var query = ""
    @State private var searchFocused = false
    @State private var selection: Set<UUID> = []
    @State private var focusedStorageID: UUID?
    @State private var renamingStorageID: UUID?
    @State private var renameDraft = ""
    @State private var previewID: UUID?
    @State private var isPreviewPresented = false
    @State private var pendingTapID: UUID?
    @State private var pendingTapWork: DispatchWorkItem?
    @State private var pendingTrash: PendingTrash?
    @State private var poolRevision = 0
    @State private var projectionMemo = AttachmentProjectionMemo()

    private var todayKey: String { DayClock.shared.todayKey }

    var body: some View {
        let allItems = resolvedLibraryItems()
        let displayed = makeDisplayedItems(from: allItems)
        let selected = allItems.filter { selection.contains($0.storageID) }
        return DaybookPage(
            title: "window.attachments",
            subtitle: "attachments.hint",
            minWidth: 440,
            minHeight: 480
        ) {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                if !allItems.isEmpty || !query.isEmpty || filter != .all || boardFilter.isActive {
                    toolbarSection(allItems: allItems, displayed: displayed)
                }
                if !selected.isEmpty {
                    AttachmentSelectionToolbar(
                        selectedCount: selected.count,
                        onSelectAll: { selectAll(displayed) },
                        onClearSelection: { selection.removeAll() },
                        onDeleteSelected: { confirmBatchTrash(selected) }
                    )
                }
                contentList(allItems: allItems, displayed: displayed)
            }
        }
        .workspaceHeader(actions: headerActions)
        .popover(isPresented: $isPreviewPresented, arrowEdge: .bottom) {
            AttachmentPreviewCarouselView(
                items: displayed.map(\.primaryReference),
                currentID: $previewID,
                imageLoader: loadedFullImage(_:),
                onExpand: { openImageViewer(for: $0, displayed: displayed) },
                onRemove: { ref in
                    isPreviewPresented = false
                    if let match = displayed.first(where: { $0.primaryReference.id == ref.id }) {
                        confirmSingleTrash(match)
                    }
                }
            )
            .padding(DaybookSpacing.sm)
        }
        .confirmMoveToTrash($pendingTrash)
        .onChange(of: allItems.map(\.storageID)) { _, storageIDs in
            let valid = Set(storageIDs)
            selection.formIntersection(valid)
            if let focusedStorageID, !valid.contains(focusedStorageID) {
                self.focusedStorageID = storageIDs.first
            }
            if let renamingStorageID, !valid.contains(renamingStorageID) {
                cancelRename()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in
            poolRevision += 1
        }
    }

    private var headerActions: [WorkspaceHeaderAction] {
        [
            WorkspaceHeaderAction(id: "attachments.upload", title: "attachments.upload", systemImage: "photo.badge.plus") {
                AttachmentActions.pickUnlinkedImage(context: modelContext, store: activeStore, root: activeRoot)
            },
            WorkspaceHeaderAction(id: "attachments.paste", title: "attachments.paste", systemImage: "doc.on.clipboard") {
                _ = AttachmentActions.pasteUnlinkedImage(context: modelContext, store: activeStore, root: activeRoot)
            }
        ]
    }

    private func toolbarSection(allItems: [AttachmentLibraryItem], displayed: [AttachmentLibraryItem]) -> some View {
        let selectedDisplayedCount = displayed.reduce(into: 0) { acc, item in
            if selection.contains(item.storageID) { acc += 1 }
        }
        return VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            HStack(spacing: DaybookSpacing.sm) {
                searchField
                    .frame(maxWidth: 360)
                Spacer(minLength: DaybookSpacing.xs)
                AttachmentViewModePicker(mode: $viewMode)
            }
            AttachmentBrowserFilterBar(
                filter: $filter,
                sort: $sort,
                boardFilter: $boardFilter,
                tags: CatalogChoices.tags(tags),
                tagCounts: projectionMemo.tagStats.counts,
                untaggedCount: projectionMemo.tagStats.untaggedCount,
                counts: projectionMemo.filterCounts,
                totalDisplayed: displayed.count,
                selectedCount: selectedDisplayedCount,
                onToggleSelectAll: { toggleSelectAll(displayed, selectedDisplayedCount: selectedDisplayedCount) }
            )
        }
    }

    private var searchField: some View {
        DaybookInputShell(kind: .search, focused: searchFocused) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DaybookPalette.text.secondary)
        } field: {
            DaybookTextField(
                text: $query,
                placeholder: L10n.string("attachments.search.placeholder", locale: locale),
                fontSize: DaybookType.bodySize,
                focus: $searchFocused,
                onSubmit: {},
                allowsShiftNewline: false,
                newlinePolicy: .searchWhitespace,
                onEscape: {
                    query = ""
                    searchFocused = false
                }
            )
            .accessibilityIdentifier("attachments.search.input")
        }
        .accessibilityLabel(Text("attachments.search.placeholder"))
    }

    private func makeViewContext(displayed: [AttachmentLibraryItem]) -> AttachmentViewContext {
        AttachmentViewContext(
            items: displayed,
            selection: selection,
            renamingStorageID: renamingStorageID,
            renameDraft: $renameDraft,
            loadImage: loadedThumbnail(_:),
            onToggleSelect: toggleSelect(_:),
            onPreview: { handlePreviewTap($0, displayed: displayed) },
            onBeginRename: beginRename(_:),
            onCommitRename: commitRename(_:),
            onCancelRename: cancelRename,
            onCopyToken: copyToken(for:),
            onCopyImage: copyImage(_:),
            onNavigateReference: navigate(to:),
            onDelete: confirmSingleTrash(_:)
        )
    }

    @ViewBuilder
    private func contentList(allItems: [AttachmentLibraryItem], displayed: [AttachmentLibraryItem]) -> some View {
        if displayed.isEmpty {
            DaybookEmptyState(
                title: allItems.isEmpty ? "attachments.empty" : "attachments.filter.empty",
                systemImage: "photo"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            let ctx = makeViewContext(displayed: displayed)
            switch viewMode {
            case .grid:
                AttachmentGridView(ctx: ctx)
            case .list:
                listViewContent(displayed: displayed)
            case .columns:
                AttachmentColumnsView(ctx: ctx, focusedStorageID: $focusedStorageID)
            case .gallery:
                AttachmentGalleryView(ctx: ctx, focusedStorageID: $focusedStorageID)
            }
        }
    }

    private func listViewContent(displayed: [AttachmentLibraryItem]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                ForEach(displayed) { item in
                    AttachmentLibraryCardView(
                        item: item,
                        image: loadedThumbnail(item.primaryReference),
                        isSelected: selection.contains(item.storageID),
                        isRenaming: renamingStorageID == item.storageID,
                        renameDraft: $renameDraft,
                        onToggleSelect: { toggleSelect(item.storageID) },
                        onPreview: { handlePreviewTap(item.primaryReference, displayed: displayed) },
                        onBeginRename: { beginRename(item) },
                        onCommitRename: { commitRename(item) },
                        onCancelRename: cancelRename,
                        onCopyToken: { copyToken(for: item) },
                        onNavigateReference: navigate(to:),
                        onDelete: { confirmSingleTrash(item) }
                    )
                }
            }
        }
        .daybookScroll()
    }

    private func handlePreviewTap(_ target: AttachmentRef, displayed: [AttachmentLibraryItem]) {
        if (NSApp.currentEvent?.clickCount ?? 1) >= 2 || (pendingTapID == target.id && pendingTapWork != nil) {
            openImageViewer(for: target, displayed: displayed)
        } else {
            pendingTapWork?.cancel(); pendingTapID = target.id
            let work = DispatchWorkItem {
                pendingTapWork = nil; pendingTapID = nil
                previewID = target.id; isPreviewPresented = true
            }
            pendingTapWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20, execute: work)
        }
    }

    private func openImageViewer(for target: AttachmentRef, displayed: [AttachmentLibraryItem]) {
        pendingTapWork?.cancel(); pendingTapWork = nil; pendingTapID = nil
        isPreviewPresented = false
        let refs = displayed.map(\.primaryReference)
        let loader = loadedFullImage(_:)
        AttachmentImageViewerWindowController.shared.show(
            items: refs.isEmpty ? [target] : refs,
            initialID: target.id,
            imageLoader: loader,
            onCopyToken: { ref in
                if let match = displayed.first(where: { $0.primaryReference.id == ref.id }) {
                    copyToken(for: match)
                }
            },
            onRemove: { ref in
                if let match = displayed.first(where: { $0.primaryReference.id == ref.id }) {
                    confirmSingleTrash(match)
                }
            }
        )
    }

    private var activeStore: AttachmentStore { hostContext?.attachments ?? .shared }
    private var activeRoot: URL? { hostContext?.attachments?.directory() }

    private func resolvedLibraryItems() -> [AttachmentLibraryItem] {
        let pool = AttachmentPoolStore.unlinkedItems(store: activeStore, root: activeRoot)
        let signature = "\(poolRevision)|\(locale.identifier)|\(attachments.count)|\(tags.count)|"
            + attachments.map { "\($0.id.uuidString):\($0.filename):\($0.storageID?.uuidString ?? "")" }.joined(separator: ",")
            + "|" + pool.map { "\($0.id.uuidString):\($0.filename)" }.joined(separator: ",")
        if projectionMemo.signature == signature {
            return projectionMemo.items
        }
        let owners = (try? AttachmentAccess.ownerIndex(context: modelContext, keys: attachments.compactMap(\.ownerKey))) ?? .empty
        let storageIDs = attachments.map { $0.storageID ?? $0.id } + pool.map(\.id)
        let hashes = AttachmentPoolStore.contentHashes(for: storageIDs, store: activeStore, root: activeRoot)
        let built = AttachmentLibraryProjection.build(
            attachments: attachments,
            unlinked: pool,
            owners: owners,
            tags: tags,
            contentHashes: hashes,
            locale: locale
        )
        projectionMemo.signature = signature
        projectionMemo.items = built
        projectionMemo.tagStats = AttachmentLibraryProjection.tagCounts(for: built)
        projectionMemo.filterCounts = AttachmentLibraryProjection.filterCounts(for: built)
        return built
    }

    private func makeDisplayedItems(from allItems: [AttachmentLibraryItem]) -> [AttachmentLibraryItem] {
        AttachmentLibraryProjection.filterAndSort(
            allItems,
            filter: filter,
            boardFilter: boardFilter,
            todayKey: todayKey,
            query: query,
            sort: sort
        )
    }

    private func loadedThumbnail(_ item: AttachmentRef) -> NSImage? {
        AttachmentPoolStore.cachedImage(
            for: item,
            maxPixelSize: 360,
            store: activeStore,
            root: activeRoot,
            useOrdinaryRead: hostContext != nil
        )
    }

    private func loadedFullImage(_ item: AttachmentRef) -> NSImage? {
        AttachmentPoolStore.cachedImage(
            for: item,
            maxPixelSize: nil,
            store: activeStore,
            root: activeRoot,
            useOrdinaryRead: hostContext != nil
        )
    }

    private func copyImage(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private func toggleSelect(_ storageID: UUID) {
        if selection.contains(storageID) {
            selection.remove(storageID)
        } else {
            selection.insert(storageID)
        }
    }

    private func selectAll(_ displayed: [AttachmentLibraryItem]) {
        for item in displayed {
            selection.insert(item.storageID)
        }
    }

    private func toggleSelectAll(_ displayed: [AttachmentLibraryItem], selectedDisplayedCount: Int) {
        if selectedDisplayedCount == displayed.count && !displayed.isEmpty {
            for item in displayed {
                selection.remove(item.storageID)
            }
        } else {
            selectAll(displayed)
        }
    }

    private func beginRename(_ item: AttachmentLibraryItem) {
        renamingStorageID = item.storageID
        renameDraft = item.filename
    }

    private func commitRename(_ item: AttachmentLibraryItem) {
        _ = AttachmentPoolStore.rename(
            item: item,
            newFilename: renameDraft,
            context: modelContext,
            store: activeStore,
            root: activeRoot
        )
        poolRevision += 1
        cancelRename()
    }

    private func cancelRename() {
        renamingStorageID = nil
        renameDraft = ""
    }

    private func copyToken(for item: AttachmentLibraryItem) {
        let token = AttachmentSyntax.spelling(for: item.filename)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(token, forType: .string)
    }

    private func navigate(to ref: AttachmentReferenceItem) {
        switch ref.kind {
        case .todo, .routine:
            navigation.revealTab(.allItems, inspecting: ref.ownerID, dayKey: ref.dayKey)
        case .diary:
            navigation.revealTab(.diary)
            if let dayKey = ref.dayKey {
                navigation.inspectDiary(id: ref.ownerID, dayKey: dayKey)
            }
        }
    }

    private func confirmSingleTrash(_ item: AttachmentLibraryItem) {
        pendingTrash = PendingTrash(title: item.filename) {
            _ = AttachmentPoolStore.trashItems(
                [item],
                context: modelContext,
                store: activeStore,
                root: activeRoot
            )
            selection.remove(item.storageID)
            poolRevision += 1
        }
    }

    private func confirmBatchTrash(_ targets: [AttachmentLibraryItem]) {
        guard !targets.isEmpty else { return }
        let summaryTitle = targets.count == 1 ? targets[0].filename : "\(targets.count)"
        pendingTrash = PendingTrash(title: summaryTitle) {
            _ = AttachmentPoolStore.trashItems(
                targets,
                context: modelContext,
                store: activeStore,
                root: activeRoot
            )
            selection.removeAll()
            poolRevision += 1
        }
    }
}

/// 仿 macOS Finder 的四态视图切换胶囊（图标网格 ⊞ / 详细列表 ☰ / 三栏分栏 ◫ / 画廊预览 ▭）。
struct AttachmentViewModePicker: View {
    @Binding var mode: AttachmentViewMode

    var body: some View {
        HStack(spacing: 2) {
            modeButton(.grid)
            modeButton(.list)
            modeButton(.columns)
            RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                .fill(DaybookPalette.border.default)
                .frame(width: 1, height: 14)
                .padding(.horizontal, 2)
            modeButton(.gallery)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous)
                .strokeBorder(DaybookPalette.border.default, lineWidth: 0.8)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("attachments.viewMode.picker")
    }

    private func modeButton(_ target: AttachmentViewMode) -> some View {
        let isSelected = mode == target
        let key = LocalizedStringKey(target.titleKey)
        return Button {
            mode = target
        } label: {
            Image(systemName: target.iconName)
                .font(DaybookType.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? DaybookPalette.text.primary : DaybookPalette.text.secondary)
                .frame(width: 28, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous)
                        .fill(isSelected ? DaybookPalette.fill.hover : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous))
        }
        .buttonStyle(.plain) // control: Finder 风格视图切换胶囊按钮
        .help(key)
        .accessibilityLabel(key)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("attachments.viewMode." + target.rawValue)
    }
}

struct AttachmentViewContext {
    let items: [AttachmentLibraryItem]
    let selection: Set<UUID>
    let renamingStorageID: UUID?
    @Binding var renameDraft: String
    var loadImage: (AttachmentRef) -> NSImage?
    var onToggleSelect: (UUID) -> Void
    var onPreview: (AttachmentRef) -> Void
    var onBeginRename: (AttachmentLibraryItem) -> Void
    var onCommitRename: (AttachmentLibraryItem) -> Void
    var onCancelRename: () -> Void
    var onCopyToken: (AttachmentLibraryItem) -> Void
    var onCopyImage: (NSImage) -> Void
    var onNavigateReference: (AttachmentReferenceItem) -> Void
    var onDelete: (AttachmentLibraryItem) -> Void
}

private final class AttachmentProjectionMemo {
    var signature: String = ""
    var items: [AttachmentLibraryItem] = []
    var tagStats: (counts: [UUID: Int], untaggedCount: Int) = ([:], 0)
    var filterCounts: [AttachmentFilterKind: Int] = [:]
}
