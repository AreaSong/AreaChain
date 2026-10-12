import SwiftData
import SwiftUI

struct DiaryPageOptions {
    var showsComposer: Bool = true
    var usesSharedDiaryDay: Bool = false
    var maxScrollHeight: CGFloat? = nil
    var showsPageHeader: Bool = true
    var externalFilter: Binding<BoardFilter>? = nil
    var composerDraft: Binding<BoardComposerDraft>? = nil
    var vault: PrivacyVault? = nil
    var initializesPresetTags = true
}

/// 灵感手记：按「密码 / 小巧思 / 日记」分类记录，可筛选、置顶与就地编辑。
struct DiaryPage: View {
    @Environment(\.workspaceEmbedded) private var embedded
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) private var locale

    var todayKey: String
    var entries: [DiaryEntry]
    var showsComposer: Bool = true
    var usesSharedDiaryDay: Bool = false
    var maxScrollHeight: CGFloat? = nil
    var showsPageHeader: Bool = true
    var externalFilter: Binding<BoardFilter>? = nil
    @Binding private var externalComposerDraft: BoardComposerDraft
    private let usesExternalComposerDraft: Bool
    private let initializesPresetTags: Bool
    private let vault: PrivacyVault

    @Query(sort: \TagItem.sortOrder) var allTags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State private var searchQuery: String = ""
    @State private var localFilter = BoardFilter()
    @State private var pendingTrash: PendingTrash?
    @State private var searchFocused = false
    @State private var cardDrafts = DiaryCardDrafts()
    @State var hostWindow: NSWindow?
    @WorkspaceBoardContext private var boardSelection
    @State var selectedEntryID: UUID? = nil
    @State var keyMonitor: Any? = nil

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
        self.externalFilter = options.externalFilter
        self._externalComposerDraft = options.composerDraft ?? .constant(BoardComposerDraft())
        self.usesExternalComposerDraft = options.composerDraft != nil
        self.vault = options.vault ?? .shared
        self.initializesPresetTags = options.initializesPresetTags
    }

    init(
        todayKey: String,
        entries: [DiaryEntry],
        showsComposer: Bool = true,
        usesSharedDiaryDay: Bool = false,
        showsPageHeader: Bool = true,
        externalFilter: Binding<BoardFilter>? = nil
    ) {
        self.init(
            todayKey: todayKey,
            entries: entries,
            options: DiaryPageOptions(
                showsComposer: showsComposer,
                usesSharedDiaryDay: usesSharedDiaryDay,
                showsPageHeader: showsPageHeader,
                externalFilter: externalFilter
            )
        )
    }

    private var activeTags: [TagItem] {
        allTags.filter { $0.deletedAt == nil }
    }

    private var filterBinding: Binding<BoardFilter> { externalFilter ?? $localFilter }

    private var selectedTagID: UUID? {
        get { filterBinding.wrappedValue.tagID }
        nonmutating set { filterBinding.wrappedValue = filterBinding.wrappedValue.withTag(newValue) }
    }

    private var orderedTags: [TagItem] {
        DiaryMemoTags.ordered(activeTags, name: { $0.name }, isActive: { _ in true })
    }

    func makeListModel() -> DiaryPageListModel {
        DiaryPageListModel.make(
            entries: entries,
            activeTags: activeTags,
            allTags: Array(allTags),
            searchQuery: searchQuery,
            selectedTagID: selectedTagID,
            vault: vault
        )
    }

    var body: some View {
        let list = makeListModel()
        Group {
            if embedded && showsPageHeader {
                DaybookScrollablePageShell {
                    if showsComposer {
                        quickComposer
                    }
                } filterBar: {
                    HStack(spacing: DaybookSpacing.sm) {
                        tagFilterBar(list)
                        Spacer(minLength: DaybookSpacing.sm)
                        searchChrome
                            .frame(width: 210)
                    }
                } content: {
                    entryListSection(list)
                }
            } else {
                VStack(alignment: .leading, spacing: showsPageHeader ? 12 : 8) {
                    // 菜单栏由共享底栏负责搜索与筛选，避免页内再出现一套入口。
                    if showsPageHeader {
                        topHeader(list).zIndex(50)
                        if !embedded { tagFilterBar(list) }
                    }

                    if showsComposer {
                        quickComposer.zIndex(20)
                    }

                    entryListSection(list)
                }
            }
        }
        .workspaceHeader(
            status: embedded && showsPageHeader ? AnyView(
                Text("diary.page.count \(list.rows.count)")
                    .font(DaybookType.caption.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.secondary)
            ) : nil
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyWindowHost { hostWindow = $0 })
        .confirmMoveToTrash($pendingTrash)
        .onDisappear { tearDownKeyMonitor() }
        .onAppear {
            if initializesPresetTags { DayBoardMutations.ensureDiaryPresetTags(among: Array(allTags), context: modelContext) }
            setupKeyMonitor()
        }
    }

    @ViewBuilder
    private func topHeader(_ list: DiaryPageListModel) -> some View {
        DaybookPageHeader {
            HStack(spacing: 8) {
                Text("diary.page.title")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.primary)
                Text("diary.page.count \(list.rows.count)")
                    .font(DaybookType.caption.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
        } subtitle: {
            Text("diary.page.subtitle")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
        } trailing: {
            searchChrome
                .frame(width: 200)
        }
    }

    private var searchChrome: some View {
        DaybookInputShell(kind: .search, focused: searchFocused) {
            DaybookIconButton(systemName: "magnifyingglass", label: "diary.search.placeholder", size: .inline) {
                searchFocused = true
            }
            .appShortcut(.search, enabled: showsPageHeader && !embedded)
        } field: {
            SyntaxTextField(
                text: $searchQuery, placeholder: L10n.string("diary.search.placeholder", locale: locale),
                focused: $searchFocused, context: .tagSearch, fontSize: DaybookType.subtitleSize,
                newlinePolicy: .searchWhitespace,
                onEscape: {
                    if !searchQuery.isEmpty { searchQuery = "" }
                    else { NSApp.keyWindow?.makeFirstResponder(nil) }
                }
            )
        } trailing: {
            if !searchQuery.isEmpty {
                DaybookIconButton(systemName: "xmark.circle.fill", label: "footer.search.clear", size: .inline) {
                    searchQuery = ""
                }
            }
        }
    }

    private func tagFilterBar(_ list: DiaryPageListModel) -> some View {
        let choices = BoardFilterChoices.tags(
            filter: filterBinding.wrappedValue,
            rows: orderedTags.map { BoardFilterChoices.NamedRow(id: $0.id, name: $0.name) },
            counts: list.tagCounts,
            untaggedCount: nil,
            includeNone: false,
            totalCount: list.liveEntries.count,
            locale: locale
        )
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(choices) { choice in
                    filterPill(
                        title: BoardFilterChoices.markedTagTitle(choice),
                        count: choice.count ?? 0,
                        isSelected: choice.isSelected,
                        color: choice.dotColor ?? DaybookPalette.accent.base
                    ) {
                        filterBinding.wrappedValue = choice.isSelected ? choice.cleared : choice.applied
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
        color: Color = DaybookPalette.accent.base,
        action: @escaping () -> Void
    ) -> some View {
        DaybookChip(tint: color, isSelected: isSelected, action: action) {
            HStack(spacing: 4) {
                Text(title)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded)) // token-exempt: 筛选计数用圆体
                }
            }
        }
    }

    private var quickComposer: some View {
        DiaryComposerHostSection(
            todayKey: todayKey,
            showsPageHeader: showsPageHeader,
            orderedTags: orderedTags,
            allTags: Array(allTags),
            vault: vault,
            hostWindow: hostWindow,
            externalComposerDraft: $externalComposerDraft,
            usesExternalComposerDraft: usesExternalComposerDraft
        )
    }

    private func entryListSection(_ list: DiaryPageListModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: showsPageHeader ? 10 : 4) {
                    if list.rows.isEmpty {
                        emptyState
                    } else {
                        ForEach(list.rows) { row in
                            entryRow(row).id(row.id)
                        }

                        if !showsPageHeader && list.rows.count <= 5 {
                            quietEmptyWatermark
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .daybookScroll(featherEdges: true)
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

    @ViewBuilder private func entryRow(_ row: DiaryPageListModel.Row) -> some View {
        if showsPageHeader {
            DiaryNoteCard(
                entry: row.entry, activeTags: activeTags, attachments: attachments,
                onDelete: { requestTrash(row.entry) },
                isHighlighted: boardSelection.inspectingDiaryID == row.id,
                privacyTags: Array(allTags), draftStore: cardDrafts, vault: vault,
                projectedSensitive: row.isSensitive
            )
        } else {
            DiarySummaryRow(
                entry: row.entry, privacyTags: Array(allTags),
                allTags: activeTags,
                isSelected: selectedEntryID == row.id,
                isHighlighted: boardSelection.inspectingDiaryID == row.id,
                projectedSensitive: row.isSensitive,
                onSelect: { selectedEntryID = row.id },
                onDelete: { requestTrash(row.entry) }
            )
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
        DaybookEmptyState(
            title: selectedTagID != nil || !searchQuery.isEmpty ? "diary.empty.filtered" : "diary.empty.title",
            subtitle: showsPageHeader ? "diary.empty.hint" : "diary.quick.empty.hint",
            systemImage: selectedTagID != nil || !searchQuery.isEmpty ? "magnifyingglass" : "note.text",
            alignment: .center,
            centerVertically: true
        )
    }

    private var quietEmptyWatermark: some View {
        HStack {
            Spacer()
            Label("diary.quick.empty.hint", systemImage: "sparkles")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary.opacity(0.4)) // token-exempt: 40% 次要色没有对应令牌
                .padding(.vertical, 14)
            Spacer()
        }
    }

    func requestTrash(_ entry: DiaryEntry) {
        pendingTrash = .diary(entry, tags: { Array(allTags) }, locale: locale) {
            DayBoardMutations.deleteDiary(entry)
        }
    }
}
