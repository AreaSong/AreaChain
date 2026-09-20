import SwiftData
import SwiftUI

struct DiaryPageOptions {
    var showsComposer: Bool = true
    var usesSharedDiaryDay: Bool = false
    var maxScrollHeight: CGFloat? = nil
    var showsPageHeader: Bool = true
    var externalSelectedTagID: Binding<UUID?>? = nil
    var composerDraft: Binding<DiaryComposerDraft>? = nil
    var vault: PrivacyVault? = nil
}

/// 灵感手记：按「密码 / 小巧思 / 日记」分类记录，可筛选、置顶与就地编辑。
struct DiaryPage: View {
    @Environment(\.daybookViewStyle) private var style
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) private var locale

    var todayKey: String
    var entries: [DiaryEntry]
    var showsComposer: Bool = true
    var usesSharedDiaryDay: Bool = false
    var maxScrollHeight: CGFloat? = nil
    var showsPageHeader: Bool = true
    var externalSelectedTagID: Binding<UUID?>? = nil
    @Binding private var externalComposerDraft: DiaryComposerDraft
    private let usesExternalComposerDraft: Bool
    private let vault: PrivacyVault

    @Query(sort: \TagItem.sortOrder) var allTags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State private var localSelectedTagID: UUID? = nil
    @State private var searchQuery: String = ""
    @State private var localComposerDraft = DiaryComposerDraft()
    @State private var pendingTrash: PendingTrash?
    @State private var composerFocused = false
    @State private var searchFocused = false
    @State private var composerStatus: String?
    @State private var confirmsDiscardDraft = false
    @State private var cardDrafts = DiaryCardDrafts()
    @State var hostWindow: NSWindow?
    @Bindable private var boardSelection = BoardSelection.shared
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
        self.externalSelectedTagID = options.externalSelectedTagID
        self._externalComposerDraft = options.composerDraft ?? .constant(DiaryComposerDraft())
        self.usesExternalComposerDraft = options.composerDraft != nil
        self.vault = options.vault ?? .shared
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

    // 外部草稿必须是动态属性，否则子编辑器会更新，父级的锁定分支却可能没有刷新。
    private var draftBinding: Binding<DiaryComposerDraft> {
        usesExternalComposerDraft ? $externalComposerDraft : $localComposerDraft
    }

    private var composerNeedsProtection: Bool {
        if draftBinding.wrappedValue.sealed != nil { return true }
        let names = Set((TagSyntax.names(in: draftText) + DiaryMemoTags.autoTagNames(in: draftText)).map(TagSyntax.normalizedName))
        return allTags.contains {
            $0.isPrivateDiary && (composerSelectedTagIDs.contains($0.id) || names.contains(TagSyntax.normalizedName($0.name)))
        }
    }

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

    var filteredEntries: [DiaryEntry] {
        let query = BoardSearch.parseQuery(searchQuery)
        let tagMap = Dictionary(uniqueKeysWithValues: activeTags.map { ($0.id, $0.name) })
        return nonDeletedEntries
            .filter { entry in
                if let selectedTagID {
                    guard TagIDList.contains(entry.tagIDs, selectedTagID) else { return false }
                }
                return BoardSearch.matchesDiary(DiaryContent.snapshot(entry, vault: vault), query: query, tagMap: tagMap)
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
                if !style.isWorkspace { tagFilterBar }
            }

            if showsComposer {
                quickComposer.zIndex(20)
            }

            if showsPageHeader && style.isWorkspace { tagFilterBar }

            entryListSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyWindowHost { hostWindow = $0 })
        .confirmMoveToTrash($pendingTrash)
        .onChange(of: draftText) { _, text in
            if !text.isEmpty { composerStatus = nil }
            draftBinding.wrappedValue.needsProtection = composerNeedsProtection
            if composerNeedsProtection { vault.touch() }
        }
        .onChange(of: composerSelectedTagIDs) { _, _ in draftBinding.wrappedValue.needsProtection = composerNeedsProtection }
        .onReceive(NotificationCenter.default.publisher(for: .privacyWillLock, object: vault)) { _ in sealComposer() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyMask, object: vault)) { _ in sealComposer() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in sealComposer() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window === hostWindow { sealComposer() }
        }
        .onDisappear {
            sealComposer()
            tearDownKeyMonitor()
        }
        .confirmationDialog("privacy.draft.discard.confirm", isPresented: $confirmsDiscardDraft) {
            Button("privacy.draft.discard", role: .destructive) { draftBinding.wrappedValue = DiaryComposerDraft() }
            Button("alert.cancel", role: .cancel) {}
        }
        .onAppear {
            DayBoardMutations.ensureDiaryPresetTags(among: Array(allTags), context: modelContext)
            setupKeyMonitor()
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
        DaybookPageHeader {
            HStack(spacing: 8) {
                Text("diary.page.title")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookTheme.ink)
                Text("diary.page.count \(filteredEntries.count)")
                    .font(WorkspaceStyle.countFont)
                    .foregroundStyle(DaybookTheme.muted)
            }
        } subtitle: {
            Text("diary.page.subtitle")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookTheme.muted)
        } trailing: {
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
                focused: $searchFocused, context: .tagSearch, fontSize: DaybookType.subtitleSize,
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
        .daybookInputChrome(focused: searchFocused, kind: .search)
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
            if style.isWorkspace {
                WorkspaceFilterLabel(isSelected: isSelected, tint: color) {
                    HStack(spacing: 4) {
                        Text(title)
                        if count > 0 { Text("\(count)").font(WorkspaceStyle.countFont) }
                    }
                }
            } else {
                standardFilterLabel(title: title, count: count, isSelected: isSelected, color: color)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func standardFilterLabel(title: String, count: Int, isSelected: Bool, color: Color) -> some View {
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
        .background(Capsule().fill(isSelected ? color.opacity(0.16) : DaybookTheme.hoverFill.opacity(0.8)))
        .overlay(Capsule().strokeBorder(isSelected ? color.opacity(0.4) : DaybookTheme.cardBorder, lineWidth: 0.8))
        .foregroundStyle(isSelected ? color : DaybookTheme.ink)
    }

    @ViewBuilder private var quickComposer: some View {
        if draftBinding.wrappedValue.sealed != nil || (composerNeedsProtection && !vault.isUnlocked) {
            HStack {
                Label("privacy.draft.locked", systemImage: "lock")
                Spacer()
                Button("privacy.unlock.title") {
                    PrivacyAccess.perform(requiresUnlock: true, vault: vault) {
                        try draftBinding.wrappedValue.restore(vault: vault)
                        composerFocused = true
                    }
                }
                Button("privacy.draft.discard") { confirmsDiscardDraft = true }
            }
            .font(DaybookType.caption).padding(10).daybookInputChrome(focused: false, kind: .composer)
        } else {
            DiaryQuickComposerView(
                text: draftBinding.text, focused: $composerFocused, orderedTags: orderedTags,
                selectedTagIDs: draftBinding.selectedTagIDs, onSubmit: submitNote,
                isCompact: !showsPageHeader, status: composerStatus,
                isSensitive: composerNeedsProtection, onOpenWindow: detachDraft
            )
        }
    }

    private var entryListSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: showsPageHeader ? 10 : 4) {
                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredEntries) { entry in
                            entryRow(entry).id(entry.id)
                        }

                        if !showsPageHeader && filteredEntries.count <= 5 {
                            quietEmptyWatermark
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
                          privacyTags: Array(allTags), draftStore: cardDrafts, vault: vault)
        } else {
            DiarySummaryRow(entry: entry, privacyTags: Array(allTags),
                            allTags: activeTags,
                            isSelected: selectedEntryID == entry.id,
                            isHighlighted: boardSelection.inspectingDiaryID == entry.id,
                            onSelect: { selectedEntryID = entry.id },
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
                .foregroundStyle(DaybookTheme.muted.opacity(0.4))
                .padding(.vertical, 14)
            Spacer()
        }
    }

    private func submitNote() {
        guard draftBinding.wrappedValue.hasContent else { return }
        let draftID = draftBinding.wrappedValue.id
        PrivacyAccess.perform(requiresUnlock: composerNeedsProtection, vault: vault) {
            guard draftBinding.wrappedValue.id == draftID else { throw PrivacyError.staleOperation }
            try draftBinding.wrappedValue.restore(vault: vault)
            let rawText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawText.isEmpty else { return }

            let parsed = NaturalLanguageParser.parseDiaryCapture(rawText)
            let textToSave: String = {
                if parsed.hasNoteSeparator && !parsed.cleanTitle.isEmpty {
                    return parsed.cleanTitle + (parsed.body.isEmpty ? "" : "\n" + parsed.body)
                } else if !parsed.body.isEmpty {
                    return parsed.body
                } else {
                    return NaturalLanguageParser.unescapeSyntax(rawText)
                }
            }()
            guard !textToSave.isEmpty else { return }

            var effectiveTagIDs = composerSelectedTagIDs
            if !parsed.tagNames.isEmpty {
                let resolvedIDs = try InputTagResolver.resolve(parsed.tagNames, in: modelContext)
                effectiveTagIDs.formUnion(resolvedIDs)
            }

            guard DayBoardMutations.addDiary(
                text: textToSave, dayKey: todayKey, selectedTagIDs: effectiveTagIDs,
                tags: Array(allTags), context: modelContext
            ) else { composerStatus = "diary.window.save.failed"; return }
            draftBinding.wrappedValue = DiaryComposerDraft()
            composerStatus = "diary.window.saved"
            composerFocused = true
        }
    }

    private func sealComposer() {
        draftBinding.wrappedValue.needsProtection = composerNeedsProtection
        do { try draftBinding.wrappedValue.seal(vault: vault) }
        catch { composerStatus = "privacy.error.corruptData" }
    }

    func requestTrash(_ entry: DiaryEntry) {
        pendingTrash = .diary(entry, tags: { Array(allTags) }, locale: locale) {
            DayBoardMutations.deleteDiary(entry)
        }
    }

    private func detachDraft() {
        composerFocused = false
        if draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DiaryWindows.shared.openDraft(DiaryComposerDraft(), dayKey: todayKey, context: modelContext)
        } else {
            DiaryWindows.shared.openDraft(draftBinding.wrappedValue, dayKey: todayKey, context: modelContext) {
                draftBinding.wrappedValue = DiaryComposerDraft()
                composerStatus = nil
            }
        }
    }
}
