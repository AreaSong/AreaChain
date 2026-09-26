import SwiftData
import SwiftUI

/// 组织 > 标签：平面列表、筛选、创建、重命名、排序、合并与颜色。
struct TagManagementPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var todos: [TodoItem]
    @Query private var routines: [DailyRoutine]
    @Query private var diaries: [DiaryEntry]

    @State private var filter: TagListFilter = .all
    @State private var query = ""
    @State private var searchFocused = false
    @State private var draftName = ""
    @State private var createFocused = false
    @State private var createError: String?
    @State private var selection: Set<UUID> = []
    @State private var renamingID: UUID?
    @State private var renameDraft = ""
    @State private var renameError: String?
    @State private var confirmDelete = false
    @State private var confirmCleanup = false
    @State private var confirmPurge = false
    @State private var showsDeleted = false
    @State private var mergeTarget: UUID?
    @State private var showMerge = false
    @State private var pageError: String?

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
        .sheet(isPresented: $showMerge) { mergeSheet }
    }

    private var tagPage: some View {
        DaybookPage(title: "tab.tags", systemImage: "tag", subtitle: "tags.page.subtitle") {
            pageToolbar
        } content: {
            pageContent
        }
    }

    private var pageToolbar: some View {
        HStack(spacing: 8) {
            if showsDeleted {
                Button("trash.restore", action: commitRestore)
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                    .disabled(deletedSelection.isEmpty)
                Button("trash.purge") { confirmPurge = true }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                    .disabled(deletedSelection.isEmpty)
            } else {
                liveToolbar
            }
        }
    }

    private var liveToolbar: some View {
        HStack(spacing: 8) {
            Button("tags.create", action: commitCreate)
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if !ordinarySelection.isEmpty {
                Button("tags.batch.delete") { confirmDelete = true }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                colorMenu
                if ordinarySelection.count >= 2 {
                    Button("tags.merge") { beginMerge() }
                        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                }
            }
            if !unusedOrdinary.isEmpty {
                Button("tags.cleanup.unused") { confirmCleanup = true }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            searchField
            if !showsDeleted {
                createField
            }
            filterBar
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
        tags.filter { $0.deletedAt != nil && !$0.isDiaryPreset }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    private var deletedSelection: [TagItem] {
        deletedTags.filter { selection.contains($0.id) }
    }

    private var ordinarySelection: [TagItem] {
        Catalog.liveTags(tags).filter { selection.contains($0.id) && !$0.isDiaryPreset }
    }

    private var unusedOrdinary: [TagItem] {
        TagUsage.filtered(tags, filter: .unused, usage: usage).filter { !$0.isDiaryPreset }
    }

    private var canReorder: Bool {
        !showsDeleted && filter == .all && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchField: some View {
        DaybookInputShell(kind: .search, focused: searchFocused) {
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
                    onEscape: { draftName = ""; createError = nil; createFocused = false }
                )
            }
            if let createError {
                Text(LocalizedStringKey(createError))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(TagListFilter.allCases, id: \.self) { item in
                Button(filterTitle(item)) {
                    showsDeleted = false
                    filter = item
                }
                .buttonStyle(DaybookButtonStyle(!showsDeleted && filter == item ? .prominent : .quiet, size: .compact))
            }
            Button("tags.deleted.show") {
                showsDeleted = true
                selection.removeAll()
            }
            .buttonStyle(DaybookButtonStyle(showsDeleted ? .prominent : .quiet, size: .compact))
        }
    }

    private var colorMenu: some View {
        Menu {
            ForEach(TagColorToken.allCases, id: \.self) { token in
                Button(colorTitle(token)) { applyColor(token) }
            }
        } label: {
            Text("tags.color")
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
            .frame(minHeight: 240)
        }
    }

    private func tagRow(_ tag: TagItem) -> some View {
        let count = usage[tag.id]?.activeCount ?? 0
        return HStack(spacing: 10) {
            Circle() // token-exempt: 标签色点，不是按钮
                .fill(DaybookPalette.tagMark(name: tag.name, token: tag.colorToken))
                .frame(width: 10, height: 10)
                .accessibilityLabel(Text(colorTitle(tag.resolvedColorToken)))
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
                        guard tag.deletedAt == nil, !tag.isDiaryPreset else { return }
                        renamingID = tag.id
                        renameDraft = tag.name
                        renameError = nil
                    }
            }
            Spacer(minLength: 8)
            Text(tag.isDiaryPreset ? "tags.kind.preset" : "tags.kind.task")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            Text("tags.usage.count \(count)")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var mergeSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("tags.merge.confirm.title")
                .font(DaybookType.body.weight(.semibold))
            Text("tags.merge.confirm.message")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            Picker("tags.merge.pickTarget", selection: Binding(
                get: { mergeTarget ?? ordinarySelection.first?.id ?? UUID() },
                set: { mergeTarget = $0 }
            )) {
                ForEach(ordinarySelection) { tag in
                    Text(tag.name).tag(tag.id)
                }
            }
            HStack {
                Spacer()
                Button("alert.cancel") { showMerge = false }
                Button("tags.merge") { commitMerge() }
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
            }
        }
        .padding(DaybookSpacing.page)
        .frame(width: 360)
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

    private func colorTitle(_ token: TagColorToken) -> LocalizedStringKey {
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
        if DiaryMemoTags.isPresetName(name) {
            createError = "tag.preset.reserved"
            return
        }
        let key = TagSyntax.normalizedName(name)
        if Catalog.liveTags(tags).contains(where: { TagSyntax.normalizedName($0.name) == key }) {
            createError = "tags.error.duplicate"
            return
        }
        guard DayBoardMutations.createTag(name: name, context: modelContext) != nil else {
            createError = "tags.error.save"
            return
        }
        draftName = ""
        createError = nil
        pageError = nil
    }

    private func commitRename(_ tag: TagItem) {
        let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            renameError = "tags.error.empty"
            pageError = renameError
            return
        }
        if DiaryMemoTags.isPresetName(name) {
            pageError = "tag.preset.reserved"
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

    private func applyColor(_ token: TagColorToken) {
        let ids = Set(ordinarySelection.map(\.id))
        guard !ids.isEmpty else { return }
        if DayBoardMutations.batchSetTagColor(ids: ids, colorToken: token.rawValue, context: modelContext) {
            pageError = nil
        } else {
            pageError = "tags.error.save"
        }
    }

    private func commitBatchDelete() {
        let ids = ordinarySelection.map(\.id)
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

    private func beginMerge() {
        mergeTarget = ordinarySelection.first?.id
        showMerge = true
    }

    private func commitMerge() {
        guard let target = mergeTarget else { return }
        let sources = ordinarySelection.map(\.id).filter { $0 != target }
        guard DayBoardMutations.mergeTags(sourceIDs: sources, into: target, context: modelContext) else {
            pageError = "tags.error.save"
            return
        }
        selection = [target]
        showMerge = false
        pageError = nil
    }
}
