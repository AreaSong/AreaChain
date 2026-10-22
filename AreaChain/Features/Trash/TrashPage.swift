import AppKit
import SwiftData
import SwiftUI

struct TrashPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.workspaceHostContext) private var hostContext
    @Query(filter: SoftDelete.deletedRoutines, sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(filter: SoftDelete.deletedTodos, sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query(filter: SoftDelete.deletedDiaries, sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query(filter: SoftDelete.deletedAttachments) private var attachments: [AttachmentItem]

    @WorkspaceNavigationContext private var navigation
    @State private var viewMode: TrashViewMode = .list
    @State private var categoryFilter: TrashCategoryFilter = .all
    @State private var pendingPurge: PendingTrash?
    @State private var confirmEmpty = false

    private var storage: WorkspaceAttachmentStorage? { .resolve(hostContext) }

    private var items: [TrashRow] {
        let store = storage?.store
        let standing = routines.compactMap { TrashRow.resident($0, attachments: attachments, tags: tags, attachmentStore: store) }
        let tasks = todos.compactMap { TrashRow.todo($0, attachments: attachments, tags: tags, attachmentStore: store) }
        let notes = diaries.compactMap {
            TrashRow.diary($0, attachments: attachments, tags: { tags }, locale: locale, attachmentStore: store)
        }
        let catalog = tags.compactMap { TrashRow.tag($0) }
        let rows = standing + tasks + notes + attachmentRows() + catalog
        // 无宿主附件存储时清除一律禁用（含标签行），与附件页“写入禁用”一致，不新增文案（§9.102）。
        guard store == nil else { return rows }
        return rows.map { row in
            var disabled = row
            disabled.canPurge = false
            return disabled
        }
    }

    private func attachmentRows() -> [TrashRow] {
        // 隔离宿主没有附件存储时按无附件呈现：附件行不出现，其缩略图与单行清除就不会碰到共享目录。
        guard let store = storage?.store else { return [] }
        let owners = (try? AttachmentAccess.ownerIndex(context: modelContext, keys: attachments.compactMap(\.ownerKey)))
            ?? .empty
        return attachments.compactMap { item in
            let live = item.ownerKey.map { owners.ownerIsLive($0) } ?? false
            let context = resolveAttachmentContext(for: item, owners: owners)
            return TrashRow.attachment(
                item,
                ownerDeleted: !live,
                ownerTitle: context.ownerTitle,
                isPrivate: context.isPrivate,
                titleProvider: {
                    context.isPrivate ? L10n.string("diary.private.attachment", locale: locale) : item.filename
                },
                attachmentStore: store
            )
        }
    }

    private var allSectioned: [(TrashSection, [TrashRow])] {
        let grouped = Dictionary(grouping: items, by: \.section)
        return TrashSection.allCases.compactMap { section in
            let rows = (grouped[section] ?? []).sorted { $0.deletedAt > $1.deletedAt }
            return rows.isEmpty ? nil : (section, rows)
        }
    }

    private var filteredSectioned: [(TrashSection, [TrashRow])] {
        guard let targetSection = categoryFilter.section else { return allSectioned }
        return allSectioned.filter { $0.0 == targetSection }
    }

    private var flatItems: [TrashRow] {
        filteredSectioned.flatMap(\.1)
    }

    private var filterCounts: [TrashCategoryFilter: Int] {
        let allRows = items
        var counts: [TrashCategoryFilter: Int] = [.all: allRows.count]
        let grouped = Dictionary(grouping: allRows, by: \.section)
        for filter in TrashCategoryFilter.allCases {
            if let section = filter.section {
                counts[filter] = grouped[section]?.count ?? 0
            }
        }
        return counts
    }

    var body: some View {
        DaybookPage(
            title: "window.trash",
            subtitle: "trash.hint",
            minWidth: 360,
            minHeight: 420
        ) {
            if items.isEmpty && categoryFilter == .all {
                DaybookEmptyState(title: "trash.empty", systemImage: "trash")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                    controlBarRow
                    contentBody
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .trashKeys(items: flatItems, focusedID: $navigation.focusedTrashID, onRestore: restoreFocused)
            }
        }
        .workspaceHeader(actions: [WorkspaceHeaderAction(
            id: "trash.empty", title: "trash.empty.action", systemImage: "trash",
            isEnabled: !items.isEmpty && storage != nil, role: .destructive, overflowOnly: true
        ) { confirmEmpty = true }])
        .confirmationDialog("alert.purge.all.title", isPresented: $confirmEmpty, titleVisibility: .visible) {
            Button("alert.purge.all", role: .destructive, action: emptyTrash)
            Button("alert.cancel", role: .cancel) {}
        } message: { Text("alert.purge.all.message") }
        .confirmPurge($pendingPurge)
    }

    private var controlBarRow: some View {
        HStack(spacing: DaybookSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                filterChipsBar
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            viewModePicker
        }
    }

    private var filterChipsBar: some View {
        let counts = filterCounts
        return HStack(spacing: DaybookSpacing.xs) {
            ForEach(TrashCategoryFilter.allCases, id: \.self) { filter in
                let isSelected = categoryFilter == filter
                let count = counts[filter] ?? 0
                Button {
                    categoryFilter = filter
                } label: {
                    HStack(spacing: DaybookSpacing.xxs) {
                        Text(LocalizedStringKey(filter.titleKey))
                        Text(verbatim: "\(count)")
                            .font(DaybookType.badge)
                            .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
                    }
                }
                .buttonStyle(
                    DaybookButtonStyle(
                        isSelected ? .pill(tint: DaybookPalette.accent.base) : .subtle,
                        size: .compact
                    )
                )
                .accessibilityIdentifier("trash.filter." + filter.rawValue)
            }
        }
        .padding(.vertical, 1)
    }

    private var viewModePicker: some View {
        DaybookSegmentedControl(
            selection: $viewMode,
            options: [
                DaybookSegmentOption(.split, "clipboard.viewMode.split"),
                DaybookSegmentOption(.grid, "clipboard.viewMode.grid"),
                DaybookSegmentOption(.list, "clipboard.viewMode.list")
            ]
        )
        .fixedSize()
        .accessibilityIdentifier("trash.viewMode.picker")
    }

    @ViewBuilder
    private var contentBody: some View {
        if flatItems.isEmpty {
            DaybookEmptyState(
                title: items.isEmpty ? "trash.empty" : "trash.filter.empty",
                systemImage: "trash"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            switch viewMode {
            case .split:
                splitContentView
            case .grid:
                gridContentView
            case .list:
                listScrollView(activeID: navigation.focusedTrashID)
            }
        }
    }

    private var splitContentView: some View {
        let activeItem = flatItems.first(where: { $0.id == navigation.focusedTrashID }) ?? flatItems.first
        return GeometryReader { proxy in
            if proxy.size.width >= 520 {
                let leftWidth = min(max(proxy.size.width * 0.42, 280), 420)
                HStack(alignment: .top, spacing: DaybookSpacing.md) {
                    listScrollView(activeID: activeItem?.id)
                        .frame(width: leftWidth)
                        .frame(maxHeight: .infinity)
                    TrashSplitDetailPane(
                        item: activeItem,
                        loadThumbnail: loadedThumbnail(_:),
                        loadFullImage: loadedFullImage(_:),
                        onRestore: restore(_:),
                        onPurge: askPurge(_:)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            } else {
                listScrollView(activeID: activeItem?.id)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gridContentView: some View {
        let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: DaybookSpacing.sm, alignment: .top)]
        return ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: DaybookSpacing.sm) {
                ForEach(flatItems) { item in
                    TrashGridCardView(
                        item: item,
                        isSelected: navigation.focusedTrashID == item.id,
                        loadThumbnail: loadedThumbnail(_:),
                        onSelect: { navigation.focusedTrashID = item.id },
                        onRestore: { restore(item) },
                        onPurge: { askPurge(item) }
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
    }

    private func listScrollView(activeID: UUID?) -> some View {
        let showHeaders = categoryFilter == .all
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DaybookSpacing.md) {
                    ForEach(filteredSectioned, id: \.0) { section, rows in
                        if showHeaders {
                            DaybookSectionHeader(title: section.titleKey, count: rows.count)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(rows) { item in
                                TrashListCardView(
                                    item: item,
                                    isSelected: activeID == item.id,
                                    loadThumbnail: loadedThumbnail(_:),
                                    onSelect: { navigation.focusedTrashID = item.id },
                                    onRestore: { restore(item) },
                                    onPurge: { askPurge(item) }
                                )
                                .id(item.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .daybookScroll()
            .onChange(of: navigation.focusedTrashID) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
            .onAppear {
                if let id = navigation.focusedTrashID {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func resolveAttachmentContext(
        for item: AttachmentItem,
        owners: AttachmentOwnerIndex
    ) -> (ownerTitle: String?, isPrivate: Bool) {
        if item.ownerKind == AttachmentOwner.diary.rawValue {
            guard let entry = owners.uniqueDiaries[item.ownerID],
                  !entry.hasProtectedContent,
                  !DiaryPrivacy.isSensitive(entry.snapshot, tags: tags)
            else {
                return (L10n.string("diary.private.title", locale: locale), true)
            }
            let firstLine = entry.text
                .split(whereSeparator: \.isNewline)
                .first
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            return (firstLine, item.privacyVaultID != nil)
        }
        if item.ownerKind == AttachmentOwner.todo.rawValue {
            let title = owners.liveTodos[item.ownerID]?.title
                ?? todos.first(where: { $0.id == item.ownerID })?.title
            return (title, item.privacyVaultID != nil)
        }
        if item.ownerKind == AttachmentOwner.routine.rawValue {
            let title = owners.liveRoutines[item.ownerID]?.title
                ?? routines.first(where: { $0.id == item.ownerID })?.title
            return (title, item.privacyVaultID != nil)
        }
        return (nil, item.privacyVaultID != nil)
    }

    private func loadedThumbnail(_ item: AttachmentRef) -> NSImage? {
        guard item.privacyVaultID == nil, let storage else { return nil }
        return AttachmentPoolStore.cachedImage(
            for: item,
            maxPixelSize: 320,
            store: storage.store,
            root: storage.root,
            useOrdinaryRead: storage.ordinaryOnly
        )
    }

    private func loadedFullImage(_ item: AttachmentRef) -> NSImage? {
        guard item.privacyVaultID == nil, let storage else { return nil }
        return AttachmentPoolStore.cachedImage(
            for: item,
            maxPixelSize: nil,
            store: storage.store,
            root: storage.root,
            useOrdinaryRead: storage.ordinaryOnly
        )
    }

    private func restoreFocused() {
        guard let item = flatItems.first(where: { $0.id == navigation.focusedTrashID }), item.canRestore else { return }
        restore(item)
    }

    private func restore(_ item: TrashRow) {
        item.restore()
    }

    private func askPurge(_ item: TrashRow) {
        guard item.canPurge else { return }
        pendingPurge = PendingTrash(title: "", titleProvider: { item.displayTitle }) {
            purge(item)
        }
    }

    private func purge(_ item: TrashRow) {
        guard item.purge() else { return }
        if let owner = item.purgesOwner { EditDrafts.shared.discard(owner: owner) }
    }

    private func emptyTrash() {
        guard let storage else { return }
        _ = try? LocalStorageInspector.emptyAllTrash(in: modelContext, store: storage.store, root: storage.root)
    }
}
