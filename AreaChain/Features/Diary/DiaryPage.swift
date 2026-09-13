import SwiftData
import SwiftUI

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

    @State private var localSelectedTagID: UUID? = nil
    @State private var searchQuery: String = ""
    @State private var localComposerDraft = DiaryComposerDraft()
    @State private var pendingTrash: PendingTrash?
    @State private var composerFocused = false
    @State private var searchFocused = false
    @State private var composerStatus: LocalizedStringKey?
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

    private var selectedTagBinding: Binding<UUID?> { externalSelectedTagID ?? $localSelectedTagID }

    private var selectedTagID: UUID? {
        get { selectedTagBinding.wrappedValue }
        nonmutating set { selectedTagBinding.wrappedValue = newValue }
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
        let query = BoardSearch.parseQuery(searchQuery)
        let tagMap = Dictionary(uniqueKeysWithValues: activeTags.map { ($0.id, $0.name) })
        return nonDeletedEntries
            .filter { entry in
                if let selectedTagID {
                    guard TagIDList.contains(entry.tagIDs, selectedTagID) else { return false }
                }
                return BoardSearch.matchesDiary(entry.snapshot, query: query, tagMap: tagMap)
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
            // 菜单栏由共享底栏负责搜索与筛选，避免页内再出现一套入口。
            if showsPageHeader {
                topHeader.zIndex(50)
                tagFilterBar
            }

            if showsComposer {
                quickComposer.zIndex(20)
            }

            entryListSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmMoveToTrash($pendingTrash)
        .onChange(of: draftText) { _, text in
            if !text.isEmpty { composerStatus = nil }
        }
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
            Button { searchFocused = true } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(showsPageHeader ? KeyboardShortcut("f", modifiers: .command) : nil)
            .accessibilityLabel("diary.search.placeholder")
            SyntaxTextField(
                text: $searchQuery, placeholder: L10n.string("diary.search.placeholder", locale: locale),
                focused: $searchFocused, context: .tagSearch, fontSize: 11,
                onEscape: {
                    if !searchQuery.isEmpty { searchQuery = "" }
                    else { NSApp.keyWindow?.makeFirstResponder(nil) }
                }
            )
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("footer.search.clear")
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
                .strokeBorder(searchFocused ? DaybookTheme.focusRing : DaybookTheme.cardBorder, lineWidth: searchFocused ? 1.4 : 0.8)
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
            onSubmit: submitNote,
            isCompact: !showsPageHeader,
            status: composerStatus,
            onOpenWindow: detachDraft
        )
    }

    private var entryListSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: showsPageHeader ? 10 : 0) {
                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredEntries) { entry in
                            entryRow(entry).id(entry.id)
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

    @ViewBuilder private func entryRow(_ entry: DiaryEntry) -> some View {
        if showsPageHeader {
            DiaryNoteCard(entry: entry, activeTags: activeTags, attachments: attachments,
                          onDelete: { requestTrash(entry) },
                          isHighlighted: boardSelection.inspectingDiaryID == entry.id,
                          privacyTags: Array(allTags))
        } else {
            DiarySummaryRow(entry: entry, privacyTags: Array(allTags),
                            isHighlighted: boardSelection.inspectingDiaryID == entry.id,
                            onDelete: { requestTrash(entry) })
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
            Text(showsPageHeader ? "diary.empty.hint" : "diary.quick.empty.hint")
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
        ) else { composerStatus = "diary.window.save.failed"; return }
        draftBinding.wrappedValue = DiaryComposerDraft()
        composerStatus = "diary.window.saved"
        composerFocused = true
    }

    private func requestTrash(_ entry: DiaryEntry) {
        pendingTrash = .diary(entry, tags: { Array(allTags) }, locale: locale) {
            DayBoardMutations.deleteDiary(entry)
        }
    }

    private func detachDraft() {
        guard !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        composerFocused = false
        DiaryWindows.shared.openDraft(draftBinding.wrappedValue, dayKey: todayKey, context: modelContext) {
            draftBinding.wrappedValue = DiaryComposerDraft()
            composerStatus = nil
        }
    }
}
