import SwiftData
import SwiftUI

/// 组织 > 标签：平面列表、筛选、创建、重命名、排序、合并与颜色。
struct TagManagementPage: View {
    var saveTag: (String, ModelContext) -> TagItem? = { name, context in
        DayBoardMutations.createTag(name: name, context: context)
    }
    var vault: PrivacyVault = .shared
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) var locale

    @Query(sort: \TagItem.sortOrder) var tags: [TagItem]
    @Query private var todos: [TodoItem]
    @Query private var routines: [DailyRoutine]
    @Query private var diaries: [DiaryEntry]

    @State private var filter: TagListFilter = .all
    @State private var query = ""
    @State private var searchFocused = false
    @State private var draftName = ""
    @State private var createFocused = false
    @State private var createError: String?
    @State var createAsPrivate = false
    @State var selection: Set<UUID> = []
    @State private var renamingID: UUID?
    @State private var renameDraft = ""
    @State private var renameError: String?
    @State private var confirmDelete = false
    @State private var confirmCleanup = false
    @State private var confirmPurge = false
    @State private var showsDeleted = false
    @State var mergeTarget: UUID?
    @State var showMerge = false
    @State var showingPrivacySetup = false
    @State var pendingPrivacyTagIDs: Set<UUID> = []
    var customColors = CustomTagColorStore.shared
    @State var showingColorPicker = false
    @State var pendingColorTagIDs: Set<UUID> = []
    @State var pageError: String?

    var body: some View {
        tagPage
            .confirmationDialog("tags.delete.confirm.title", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("tags.batch.delete", role: .destructive, action: commitBatchDelete)
            Button("alert.cancel", role: .cancel) {}
        } message: {
            Text("tags.delete.confirm.message")
        }
        .confirmationDialog("tags.cleanup.confirm.title", isPresented: $confirmCleanup, titleVisibility: .visible) {
            Button("tags.cleanup.unused", role: .destructive, action: commitCleanup)
            Button("alert.cancel", role: .cancel) {}
        } message: {
            Text("tags.cleanup.confirm.message")
        }
        .confirmationDialog("tags.purge.confirm.title", isPresented: $confirmPurge, titleVisibility: .visible) {
            Button("trash.purge", role: .destructive, action: commitPurge)
            Button("alert.cancel", role: .cancel) {}
        } message: {
            Text("tags.purge.confirm.message")
        }
        .sheet(isPresented: $showMerge) {
            mergeSheet
                .environment(\.locale, locale)
        }
        .sheet(isPresented: $showingPrivacySetup) {
            privacySetupSheet
                .environment(\.locale, locale)
        }
        .sheet(isPresented: $showingColorPicker) {
            colorPickerSheet
                .environment(\.locale, locale)
        }
        .workspaceHeader(actions: headerActions)
    }

    private var tagPage: some View {
        DaybookPage(title: "tab.tags", systemImage: "tag", subtitle: "tags.page.subtitle") {
            pageContent
        }
    }

    private var headerActions: [WorkspaceHeaderAction] {
        [
            WorkspaceHeaderAction(id: "tags.cleanup", title: "tags.cleanup.unused", systemImage: "trash",
                                  isEnabled: !showsDeleted && !unusedOrdinary.isEmpty, overflowOnly: true) {
                confirmCleanup = true
            }
        ]
    }

    private var topInputsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: DaybookSpacing.sm) {
                searchField
                    .frame(width: 240)
                if !showsDeleted {
                    createField
                        .frame(minWidth: 280, maxWidth: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                searchField.frame(maxWidth: 360)
                if !showsDeleted {
                    createField
                }
            }
        }
    }

    private var toolbarRow: some View {
        let selected = showsDeleted ? deletedSelection : liveSelection
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: DaybookSpacing.sm) {
                HStack(spacing: 6) { filterButtons }
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: DaybookSpacing.xs)
                if !selected.isEmpty {
                    HStack(spacing: 6) { selectionActions(count: selected.count) }
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                filterBar
                selectionToolbar
            }
        }
    }

    @ViewBuilder private var selectionToolbar: some View {
        let selected = showsDeleted ? deletedSelection : liveSelection
        if !selected.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { selectionActions(count: selected.count) }
                VStack(alignment: .leading, spacing: DaybookSpacing.xs) { selectionActions(count: selected.count) }
            }
        }
    }

    @ViewBuilder private func selectionActions(count: Int) -> some View {
        Text("tags.selection.count \(count)")
            .font(DaybookType.badge)
            .foregroundStyle(DaybookPalette.text.tertiary)
        if showsDeleted {
            actionChip(title: "trash.restore", systemImage: "arrow.uturn.backward", action: commitRestore)
            actionChip(title: "trash.purge", systemImage: "trash", tint: DaybookPalette.status.danger) {
                confirmPurge = true
            }
        } else {
            actionChip(title: "tags.batch.delete", systemImage: "trash") { confirmDelete = true }
            if !ordinarySelection.isEmpty {
                colorMenu
                privacySelectionButtons
                if ordinarySelection.count >= 2 {
                    actionChip(title: "tags.merge", systemImage: "arrow.triangle.merge", action: beginMerge)
                }
            }
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            topInputsRow
            toolbarRow
            if let pageError {
                Text(LocalizedStringKey(pageError))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger)
            }
            tagList
        }
    }

    private var usage: [UUID: TagUsageRecord] {
        TagUsage.records(TagUsage.subjects(todos: todos, routines: routines, diaries: diaries))
    }

    private var displayed: [TagItem] {
        let base = showsDeleted ? deletedTags : TagUsage.filtered(tags, filter: filter, usage: usage)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return base }
        return base.filter { $0.name.localizedStandardContains(needle) }
    }

    private var deletedTags: [TagItem] {
        tags.filter { $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    private var deletedSelection: [TagItem] {
        deletedTags.filter { selection.contains($0.id) }
    }

    private var liveSelection: [TagItem] {
        Catalog.liveTags(tags).filter { selection.contains($0.id) }
    }

    var ordinarySelection: [TagItem] {
        liveSelection.filter { !$0.isDiaryPreset }
    }

    private var unusedOrdinary: [TagItem] {
        TagUsage.filtered(tags, filter: .unused, usage: usage)
    }

    private var canReorder: Bool {
        !showsDeleted && filter == .all && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchField: some View {
        DaybookInputShell(
            kind: .search,
            focused: searchFocused,
            configure: {
                $0.height = DaybookMetrics.inputHeight
                $0.radius = DaybookMetrics.Radius.inputComposer
            }
        ) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DaybookPalette.text.secondary)
        } field: {
            DaybookTextField(
                text: $query,
                placeholder: L10n.string("tags.search.placeholder", locale: locale),
                fontSize: 13,
                focus: $searchFocused,
                onSubmit: {},
                allowsShiftNewline: false,
                newlinePolicy: .searchWhitespace,
                onEscape: { query = ""; searchFocused = false }
            )
        }
        .accessibilityLabel(Text("tags.search.placeholder"))
    }

    private var createField: some View {
        VStack(alignment: .leading, spacing: 4) {
            DaybookInputShell(kind: .composer, focused: createFocused) {
                Image(systemName: "plus")
                    .foregroundStyle(DaybookPalette.text.secondary)
            } field: {
                DaybookTextField(
                    text: $draftName,
                    placeholder: L10n.string("tags.create.name", locale: locale),
                    fontSize: 13,
                    focus: $createFocused,
                    onSubmit: commitCreate,
                    allowsShiftNewline: false,
                    onEscape: cancelCreate
                )
                .accessibilityIdentifier("tags.create.input")
            } trailing: {
                createPrivacyToggle
                Button("tags.create", action: commitCreate)
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("tags.create.submit")
            }
            if let createError {
                Text(LocalizedStringKey(createError))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger)
            }
        }
    }

    private var filterBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { filterButtons }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading) { filterButtons }
        }
    }

    @ViewBuilder private var filterButtons: some View {
        ForEach(TagListFilter.allCases, id: \.self) { item in
            filterChip(
                title: filterTitle(item),
                count: TagUsage.filtered(tags, filter: item, usage: usage).count,
                isSelected: !showsDeleted && filter == item
            ) {
                showsDeleted = false
                filter = item
            }
        }
        filterChip(
            title: "tags.deleted.show",
            count: deletedTags.count,
            isSelected: showsDeleted
        ) {
            showsDeleted = true
            selection.removeAll()
        }
    }

    private var colorMenu: some View {
        Menu {
            colorMenuItems(for: Set(ordinarySelection.map(\.id)))
        } label: {
            Text("tags.color")
                .daybookMenuLabel(size: .compact, fitsLabel: true)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private var tagList: some View {
            if displayed.isEmpty {
            DaybookEmptyState(
                title: emptyTitle,
                systemImage: "tag"
            )
        } else {
            List(selection: $selection) {
                ForEach(displayed) { tag in
                    tagRow(tag)
                        .tag(tag.id)
                }
                .onMove(perform: canReorder ? moveTags : nil)
            }
            .listStyle(.inset)
            .daybookScroll()
            .frame(minHeight: 240)
        }
    }

    private func tagRow(_ tag: TagItem) -> some View {
        let count = usage[tag.id]?.activeCount ?? 0
        return HStack(spacing: 10) {
            DaybookStatusDot(color: DaybookPalette.tagMark(name: tag.name, token: tag.colorToken), size: 10)
                .accessibilityLabel(colorAccessibilityLabel(for: tag))
            if renamingID == tag.id {
                DaybookTextField(
                    text: $renameDraft,
                    placeholder: tag.name,
                    fontSize: 13,
                    focus: .constant(true),
                    onSubmit: { commitRename(tag) },
                    allowsShiftNewline: false,
                    onEscape: { cancelRename() }
                )
                .onChange(of: createFocused) { _, _ in }
            } else {
                Text(tag.name)
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .onTapGesture(count: 2) {
                        guard tag.deletedAt == nil else { return }
                        renamingID = tag.id
                        renameDraft = tag.name
                        renameError = nil
                    }
            }
            if tag.isPrivateDiary {
                HStack(spacing: 3) {
                    Image(systemName: "lock.fill")
                        .font(DaybookType.micro)
                    Text("tags.privacy.badge")
                        .font(DaybookType.badge)
                }
                .foregroundStyle(DaybookPalette.text.secondary)
            }
            Spacer(minLength: 8)
            Text(verbatim: L10n.format("tags.usage.count", locale: locale, count))
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .contextMenu { tagRowContextMenu(tag) }
    }

    private var emptyTitle: LocalizedStringKey {
        if showsDeleted { return query.isEmpty ? "tags.deleted.empty" : "tags.empty.filtered" }
        return query.isEmpty && filter == .all ? "tags.empty" : "tags.empty.filtered"
    }

    private func filterTitle(_ item: TagListFilter) -> LocalizedStringKey {
        switch item {
        case .all: "tags.filter.all"
        case .frequent: "tags.filter.frequent"
        case .recent: "tags.filter.recent"
        case .unused: "tags.filter.unused"
        }
    }

    func colorTitle(_ token: TagColorToken) -> LocalizedStringKey {
        switch token {
        case .moss: "tags.color.moss"
        case .stamp: "tags.color.stamp"
        case .ink: "tags.color.ink"
        case .clay: "tags.color.clay"
        case .amber: "tags.color.amber"
        case .slate: "tags.color.slate"
        }
    }

    private func commitCreate() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            createError = "tags.error.empty"
            return
        }
        let key = TagSyntax.normalizedName(name)
        if Catalog.liveTags(tags).contains(where: { TagSyntax.normalizedName($0.name) == key }) {
            createError = "tags.error.duplicate"
            return
        }
        guard let created = saveTag(name, modelContext) else {
            createError = "tags.error.save"
            return
        }
        let shouldAuthorize = createAsPrivate
        cancelCreate()
        pageError = nil
        if shouldAuthorize {
            requestSetPrivacy(ids: [created.id], isPrivate: true)
        }
    }

    private func cancelCreate() {
        draftName = ""
        createError = nil
        createAsPrivate = false
        createFocused = false
    }

    private func commitRename(_ tag: TagItem) {
        let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            renameError = "tags.error.empty"
            pageError = renameError
            return
        }
        let key = TagSyntax.normalizedName(name)
        if Catalog.liveTags(tags).contains(where: { $0.id != tag.id && TagSyntax.normalizedName($0.name) == key }) {
            pageError = "tags.error.duplicate"
            return
        }
        guard DayBoardMutations.renameTag(id: tag.id, name: name, context: modelContext) else {
            pageError = "tags.error.save"
            return
        }
        cancelRename()
        pageError = nil
    }

    private func cancelRename() {
        renamingID = nil
        renameDraft = ""
        renameError = nil
    }

    private func moveTags(from source: IndexSet, to destination: Int) {
        var ordered = displayed
        ordered.move(fromOffsets: source, toOffset: destination)
        guard DayBoardMutations.reorderTags(orderedIDs: ordered.map(\.id), context: modelContext) else {
            pageError = "tags.error.save"
            return
        }
        pageError = nil
    }

    private func commitBatchDelete() {
        let ids = liveSelection.map(\.id)
        if DayBoardMutations.batchTrashTags(ids: ids, context: modelContext) {
            selection.removeAll()
            pageError = nil
        } else {
            pageError = "tags.error.save"
        }
    }

    private func commitCleanup() {
        let ids = unusedOrdinary.map(\.id)
        pageError = DayBoardMutations.batchTrashTags(ids: ids, context: modelContext) ? nil : "tags.error.save"
    }

    private func commitRestore() {
        if DayBoardMutations.batchRestoreTags(deletedSelection) {
            selection.removeAll()
            pageError = nil
        } else {
            pageError = "tags.error.save"
        }
    }

    private func commitPurge() {
        if DayBoardMutations.batchPurgeTags(deletedSelection) {
            selection.removeAll()
            pageError = nil
        } else {
            pageError = "tags.error.save"
        }
    }
}
