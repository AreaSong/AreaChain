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

    @State private var filter: AttachmentFilterKind = .all
    @State private var sort: AttachmentSortOrder = .newest
    @State private var query = ""
    @State private var searchFocused = false
    @State private var selection: Set<UUID> = []
    @State private var renamingStorageID: UUID?
    @State private var renameDraft = ""
    @State private var preview: AttachmentRef?
    @State private var pendingTrash: PendingTrash?
    @State private var poolRevision = 0

    var body: some View {
        DaybookPage(
            title: "window.attachments",
            subtitle: "attachments.hint",
            minWidth: 440,
            minHeight: 480
        ) {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                if !allLibraryItems.isEmpty || !query.isEmpty || filter != .all {
                    toolbarSection
                }
                if !selectedItems.isEmpty {
                    AttachmentSelectionToolbar(
                        selectedCount: selectedItems.count,
                        onSelectAll: selectAllDisplayed,
                        onClearSelection: { selection.removeAll() },
                        onDeleteSelected: confirmBatchTrash
                    )
                }
                contentList
            }
        }
        .workspaceHeader(actions: headerActions)
        .confirmMoveToTrash($pendingTrash)
        .popover(item: $preview) { item in
            previewBody(item)
        }
        .onChange(of: allLibraryItems.map(\.storageID)) { _, storageIDs in
            let valid = Set(storageIDs)
            selection.formIntersection(valid)
            if let renamingStorageID, !valid.contains(renamingStorageID) {
                cancelRename()
            }
            if let preview, !allLibraryItems.contains(where: { $0.primaryReference.id == preview.id }) {
                self.preview = nil
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

    private var toolbarSection: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            searchField
                .frame(maxWidth: 360)
            AttachmentBrowserFilterBar(
                filter: $filter,
                sort: $sort,
                counts: filterCounts,
                totalDisplayed: displayedItems.count,
                selectedCount: selectedDisplayedCount,
                onToggleSelectAll: toggleSelectAllDisplayed
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

    @ViewBuilder
    private var contentList: some View {
        if displayedItems.isEmpty {
            DaybookEmptyState(
                title: allLibraryItems.isEmpty ? "attachments.empty" : "attachments.filter.empty",
                systemImage: "photo"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                    ForEach(displayedItems) { item in
                        AttachmentLibraryCardView(
                            item: item,
                            image: loadedImage(item.primaryReference),
                            isSelected: selection.contains(item.storageID),
                            isRenaming: renamingStorageID == item.storageID,
                            renameDraft: $renameDraft,
                            onToggleSelect: { toggleSelect(item.storageID) },
                            onPreview: { preview = item.primaryReference },
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
    }

    private var activeStore: AttachmentStore {
        hostContext?.attachments ?? .shared
    }

    private var activeRoot: URL? {
        hostContext?.attachments?.directory()
    }

    private var owners: AttachmentOwnerIndex {
        (try? AttachmentAccess.ownerIndex(context: modelContext, keys: attachments.compactMap(\.ownerKey)))
            ?? .empty
    }

    private var unlinkedPool: [UnlinkedAttachmentEntry] {
        _ = poolRevision
        return AttachmentPoolStore.unlinkedItems(store: activeStore, root: activeRoot)
    }

    private var allLibraryItems: [AttachmentLibraryItem] {
        let pool = unlinkedPool
        let storageIDs = attachments.map { $0.storageID ?? $0.id } + pool.map(\.id)
        let hashes = AttachmentPoolStore.contentHashes(for: storageIDs, store: activeStore, root: activeRoot)
        return AttachmentLibraryProjection.build(
            attachments: attachments,
            unlinked: pool,
            owners: owners,
            tags: tags,
            contentHashes: hashes,
            locale: locale
        )
    }

    private var displayedItems: [AttachmentLibraryItem] {
        AttachmentLibraryProjection.filterAndSort(
            allLibraryItems,
            filter: filter,
            query: query,
            sort: sort
        )
    }

    private var filterCounts: [AttachmentFilterKind: Int] {
        var result: [AttachmentFilterKind: Int] = [:]
        for kind in AttachmentFilterKind.allCases {
            result[kind] = AttachmentLibraryProjection.filterAndSort(allLibraryItems, filter: kind).count
        }
        return result
    }

    private var selectedItems: [AttachmentLibraryItem] {
        allLibraryItems.filter { selection.contains($0.storageID) }
    }

    private var selectedDisplayedCount: Int {
        displayedItems.filter { selection.contains($0.storageID) }.count
    }

    @ViewBuilder
    private func previewBody(_ item: AttachmentRef) -> some View {
        if !allLibraryItems.contains(where: { $0.primaryReference.id == item.id }) {
            Text("diary.private.title")
        } else if let image = loadedImage(item) {
            LoadedAttachmentImage(image: image)
                .frame(maxWidth: 420, maxHeight: 420)
                .padding(8)
        } else {
            Text(item.filename)
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
                .padding(12)
        }
    }

    private func loadedImage(_ item: AttachmentRef) -> NSImage? {
        if let hostContext {
            guard let store = hostContext.attachments,
                  let data = try? store.readOrdinary(reference: item, root: store.directory()) else { return nil }
            return NSImage(data: data)
        }
        return AttachmentStore.image(reference: item)
    }

    private func toggleSelect(_ storageID: UUID) {
        if selection.contains(storageID) {
            selection.remove(storageID)
        } else {
            selection.insert(storageID)
        }
    }

    private func selectAllDisplayed() {
        for item in displayedItems {
            selection.insert(item.storageID)
        }
    }

    private func toggleSelectAllDisplayed() {
        if selectedDisplayedCount == displayedItems.count && !displayedItems.isEmpty {
            for item in displayedItems {
                selection.remove(item.storageID)
            }
        } else {
            selectAllDisplayed()
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

    private func confirmBatchTrash() {
        let targets = selectedItems
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
