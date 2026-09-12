import SwiftData
import SwiftUI

struct DiaryComposerDraft {
    var text = ""
    var selectedTagIDs: Set<UUID> = []
}

struct DiaryPageOptions {
    var showsComposer: Bool = true
    var usesSharedDiaryDay: Bool = false
    var maxScrollHeight: CGFloat? = nil
    var showsPageHeader: Bool = true
    var externalSelectedTagID: Binding<UUID?>? = nil
    var composerDraft: Binding<DiaryComposerDraft>? = nil
}

/// 灵感手记：按「密码 / 小巧思 / 日记」分类记录，可筛选、置顶与就地编辑。
struct DiaryPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    var todayKey: String
    var entries: [DiaryEntry]
    var showsComposer: Bool = true
    var usesSharedDiaryDay: Bool = false
    var maxScrollHeight: CGFloat? = nil
    var showsPageHeader: Bool = true
    var externalSelectedTagID: Binding<UUID?>? = nil
    var composerDraft: Binding<DiaryComposerDraft>? = nil

    @Query(sort: \TagItem.sortOrder) private var allTags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State private var selectedTagID: UUID? = nil
    @State private var searchQuery: String = ""
    @State private var localComposerDraft = DiaryComposerDraft()
    @State private var pendingTrash: PendingTrash?
    @FocusState private var composerFocused: Bool
    @Bindable private var boardSelection = BoardSelection.shared

    init(
        todayKey: String,
        entries: [DiaryEntry],
        options: DiaryPageOptions = DiaryPageOptions()
    ) {
        self.todayKey = todayKey
        self.entries = entries
        self.showsComposer = options.showsComposer
        self.usesSharedDiaryDay = options.usesSharedDiaryDay
        self.maxScrollHeight = options.maxScrollHeight
        self.showsPageHeader = options.showsPageHeader
        self.externalSelectedTagID = options.externalSelectedTagID
        self.composerDraft = options.composerDraft
    }

    init(
        todayKey: String,
        entries: [DiaryEntry],
        showsComposer: Bool = true,
        usesSharedDiaryDay: Bool = false,
        showsPageHeader: Bool = true,
        externalSelectedTagID: Binding<UUID?>? = nil
    ) {
        self.init(
            todayKey: todayKey,
            entries: entries,
            options: DiaryPageOptions(
                showsComposer: showsComposer,
                usesSharedDiaryDay: usesSharedDiaryDay,
                showsPageHeader: showsPageHeader,
                externalSelectedTagID: externalSelectedTagID
            )
        )
    }

    private var activeTags: [TagItem] {
        allTags.filter { $0.deletedAt == nil }
    }

    private var draftBinding: Binding<DiaryComposerDraft> { composerDraft ?? $localComposerDraft }

    private var draftText: String {
        get { draftBinding.wrappedValue.text }
        nonmutating set { draftBinding.wrappedValue.text = newValue }
    }

    private var composerSelectedTagIDs: Set<UUID> {
        get { draftBinding.wrappedValue.selectedTagIDs }
        nonmutating set { draftBinding.wrappedValue.selectedTagIDs = newValue }
    }

    private var orderedTags: [TagItem] {
        DiaryMemoTags.ordered(activeTags, name: { $0.name }, isActive: { _ in true })
    }

    private var nonDeletedEntries: [DiaryEntry] {
        entries.filter { $0.deletedAt == nil }
    }

    private var filteredEntries: [DiaryEntry] {
        nonDeletedEntries
            .filter { entry in
                if let selectedTagID {
                    guard TagIDList.contains(entry.tagIDs, selectedTagID) else { return false }
                }
                let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !query.isEmpty {
                    let matchesText = entry.text.localizedCaseInsensitiveContains(query)
                    let matchesTag = activeTags.contains { tag in
                        TagIDList.contains(entry.tagIDs, tag.id) && tag.name.localizedCaseInsensitiveContains(query)
                    }
                    if !matchesText && !matchesTag {
                        return false
                    }
                }
                return true
            }
            .sorted { a, b in
                if a.isPinned != b.isPinned {
                    return a.isPinned && !b.isPinned
                }
                return a.createdAt > b.createdAt
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: showsPageHeader ? 12 : 8) {
            if showsPageHeader {
                topHeader
            } else {
                searchChrome
            }

            tagFilterBar

            if showsComposer {
                quickComposer
            }

            entryListSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmMoveToTrash($pendingTrash)
        .onAppear {
            DayBoardMutations.ensureDiaryPresetTags(among: Array(allTags), context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryAppendToken)) { notif in
            if let token = notif.object as? String {
                let prefix = (draftText.isEmpty || draftText.hasSuffix(" ") || draftText.hasSuffix("\n")) ? "" : " "
                draftText += prefix + token
                DispatchQueue.main.async {
                    composerFocused = true
                }
            }
        }
        .onAppear {
            if let ext = externalSelectedTagID?.wrappedValue {
                selectedTagID = ext
            }
        }
        .onChange(of: externalSelectedTagID?.wrappedValue) { _, newID in
            if selectedTagID != newID {
                selectedTagID = newID
            }
        }
        .onChange(of: selectedTagID) { _, newID in
            if let ext = externalSelectedTagID, ext.wrappedValue != newID {
                ext.wrappedValue = newID
            }
        }
    }

    private var topHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("diary.page.title")
                        .font(DaybookType.title)
                        .foregroundStyle(DaybookTheme.ink)

                    Text("diary.page.count \(filteredEntries.count)")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(DaybookTheme.hoverFill)
                        )
                }

                Text("diary.page.subtitle")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookTheme.muted)
            }

            Spacer()

            searchChrome
                .frame(width: 200)
        }
    }

    private var searchChrome: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            TextField("diary.search.placeholder", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.ink)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, showsPageHeader ? 5 : 4)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookTheme.hoverFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.8)
        )
    }

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill(title: L10n.string("filter.all", locale: locale), count: nonDeletedEntries.count, isSelected: selectedTagID == nil) {
                    selectedTagID = nil
                }

                ForEach(orderedTags) { tag in
                    let count = nonDeletedEntries.filter { TagIDList.contains($0.tagIDs, tag.id) }.count
                    filterPill(
                        title: "#\(tag.name)",
                        count: count,
                        isSelected: selectedTagID == tag.id,
                        color: DiaryTagChrome.color(for: tag.name)
                    ) {
                        if selectedTagID == tag.id {
                            selectedTagID = nil
                        } else {
                            selectedTagID = tag.id
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterPill(
        title: String,
        count: Int,
        isSelected: Bool,
        color: Color = DaybookTheme.stamp,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .opacity(0.8)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.16) : DaybookTheme.hoverFill.opacity(0.8))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.4) : DaybookTheme.cardBorder, lineWidth: 0.8)
            )
            .foregroundStyle(isSelected ? color : DaybookTheme.ink)
        }
        .buttonStyle(.plain)
    }

    private var quickComposer: some View {
        DiaryQuickComposerView(
            text: draftBinding.text,
            focused: $composerFocused,
            orderedTags: orderedTags,
            selectedTagIDs: draftBinding.selectedTagIDs,
            onSubmit: submitNote
        )
    }

    private var entryListSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredEntries) { entry in
                            DiaryNoteCard(
                                entry: entry,
                                activeTags: activeTags,
                                attachments: attachments,
                                onDelete: {
                                    pendingTrash = .diary(entry, tags: { Array(allTags) }, locale: locale) {
                                        DayBoardMutations.deleteDiary(entry)
                                    }
                                },
                                isHighlighted: boardSelection.inspectingDiaryID == entry.id,
                                privacyTags: Array(allTags)
                            )
                            .id(entry.id)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .daybookScroll()
            .frame(maxWidth: .infinity, maxHeight: maxScrollHeight ?? .infinity)
            .onAppear { scrollToInspected(proxy) }
            .onChange(of: boardSelection.inspectingDiaryID) { _, id in
                if id != nil {
                    selectedTagID = nil
                    searchQuery = ""
                }
                scrollToInspected(proxy)
            }
        }
    }

    private func scrollToInspected(_ proxy: ScrollViewProxy) {
        guard let id = boardSelection.inspectingDiaryID else { return }
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(DaybookTheme.muted.opacity(0.5))
            Text(selectedTagID != nil || !searchQuery.isEmpty ? "diary.empty.filtered" : "diary.empty.title")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DaybookTheme.muted)
            Text("diary.empty.hint")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func submitNote() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard DayBoardMutations.addDiary(
            text: text,
            dayKey: todayKey,
            selectedTagIDs: composerSelectedTagIDs,
            tags: Array(allTags),
            context: modelContext
        ) else { return }
        draftText = ""
        composerSelectedTagIDs.removeAll()
    }
}
