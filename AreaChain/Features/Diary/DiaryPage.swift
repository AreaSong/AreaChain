import AppKit
import SwiftData
import SwiftUI

/// 现代灵感手记（Notes & Memos）主视图：支持多维标签分类（小巧思/密码/日记等）、隐私遮罩、瀑布流展示与极速记录
struct DiaryPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    var todayKey: String
    var entries: [DiaryEntry]
    var showsComposer: Bool = true
    var usesSharedDiaryDay: Bool = false
    var maxScrollHeight: CGFloat? = nil

    @Query(sort: \TagItem.sortOrder) private var allTags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State private var selectedTagID: UUID? = nil
    @State private var searchQuery: String = ""
    @State private var draftText: String = ""
    @State private var composerSelectedTagIDs: Set<UUID> = []
    @State private var pendingTrash: PendingTrash?
    @FocusState private var composerFocused: Bool

    init(
        todayKey: String,
        entries: [DiaryEntry],
        showsComposer: Bool = true,
        usesSharedDiaryDay: Bool = false,
        maxScrollHeight: CGFloat? = nil
    ) {
        self.todayKey = todayKey
        self.entries = entries
        self.showsComposer = showsComposer
        self.usesSharedDiaryDay = usesSharedDiaryDay
        self.maxScrollHeight = maxScrollHeight
    }

    private var activeTags: [TagItem] {
        allTags.filter { $0.deletedAt == nil }
    }

    private var nonDeletedEntries: [DiaryEntry] {
        entries.filter { $0.deletedAt == nil }
    }

    /// 过滤后的手记列表：按置顶优先、创建时间倒序
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
        VStack(alignment: .leading, spacing: 12) {
            topHeader

            tagFilterBar

            if showsComposer {
                quickComposer
            }

            entryListSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmMoveToTrash($pendingTrash)
    }

    // MARK: - Top Header

    private var topHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("灵感手记")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DaybookTheme.ink)

                    Text("\(filteredEntries.count) 条记录")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DaybookTheme.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(DaybookTheme.hoverFill)
                        )
                }

                Text("记录小巧思、密码备忘与日常随笔")
                    .font(.system(size: 11.5))
                    .foregroundStyle(DaybookTheme.muted)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
                TextField("搜索巧思、密码或标签...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
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
            .padding(.vertical, 5)
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookTheme.hoverFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.8)
            )
        }
    }

    // MARK: - Tag Filter Bar

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill(title: "全部", count: nonDeletedEntries.count, isSelected: selectedTagID == nil) {
                    selectedTagID = nil
                }

                ForEach(activeTags) { tag in
                    let count = nonDeletedEntries.filter { TagIDList.contains($0.tagIDs, tag.id) }.count
                    filterPill(
                        title: "#\(tag.name)",
                        count: count,
                        isSelected: selectedTagID == tag.id,
                        color: tagColor(tag.name)
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

    // MARK: - Quick Note Composer

    private var quickComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if draftText.isEmpty {
                    Text("随时记下小巧思、备忘或密码（可在正文中输入 #标签 快速归类，按 ⌘Return 提交）...")
                        .font(.system(size: 12.5))
                        .foregroundStyle(DaybookTheme.muted.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.leading, 8)
                }

                TextEditor(text: $draftText)
                    .font(.system(size: 13))
                    .foregroundStyle(DaybookTheme.ink)
                    .frame(minHeight: 48, maxHeight: 100)
                    .scrollContentBackground(.hidden)
                    .focused($composerFocused)
                    .padding(4)
            }
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .stroke(composerFocused ? DaybookTheme.focusRing : DaybookTheme.cardBorder, lineWidth: composerFocused ? 1.4 : 0.8)
            )

            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(presetOrActiveTags) { tag in
                            let isSelected = composerSelectedTagIDs.contains(tag.id)
                            Button {
                                if isSelected {
                                    composerSelectedTagIDs.remove(tag.id)
                                } else {
                                    composerSelectedTagIDs.insert(tag.id)
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    Text("#\(tag.name)")
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? tagColor(tag.name).opacity(0.18) : Color.clear)
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isSelected ? tagColor(tag.name).opacity(0.5) : DaybookTheme.rule.opacity(0.6), lineWidth: 0.8)
                                )
                                .foregroundStyle(isSelected ? tagColor(tag.name) : DaybookTheme.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                Button(action: submitNote) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 10, weight: .semibold))
                        Text("存入手记")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                            .fill(canSubmit ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.2))
                    )
                    .foregroundStyle(canSubmit ? Color.white : DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(DaybookTheme.hoverFill.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.8)
        )
    }

    private var canSubmit: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var presetOrActiveTags: [TagItem] {
        activeTags
    }

    // MARK: - Entry List Section

    private var entryListSection: some View {
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
                            onTagTap: { tagID in
                                selectedTagID = tagID
                            },
                            onDelete: {
                                pendingTrash = PendingTrash(title: entry.text) {
                                    DayBoardMutations.deleteDiary(entry)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .daybookScroll()
        .frame(maxWidth: .infinity, maxHeight: maxScrollHeight ?? .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(DaybookTheme.muted.opacity(0.5))
            Text(selectedTagID != nil || !searchQuery.isEmpty ? "未找到匹配的记录" : "还没有记录任何灵感或备忘")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DaybookTheme.muted)
            Text("在上方输入框中写下你的第一条小巧思、备忘或密码吧")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func submitNote() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        var finalTagIDs = composerSelectedTagIDs
        let parsed = NaturalLanguageParser.parse(text)
        if let tagName = parsed.tagName {
            if let existing = activeTags.first(where: { $0.name == tagName }) {
                finalTagIDs.insert(existing.id)
            } else {
                let newTag = TagItem(name: tagName, sortOrder: activeTags.count)
                modelContext.insert(newTag)
                finalTagIDs.insert(newTag.id)
            }
        }

        autoTagIfKeywordsMatch(text: text, targetSet: &finalTagIDs)

        let tagIDsString = finalTagIDs.map(\.uuidString).joined(separator: ",")

        let newEntry = DiaryEntry(
            text: text,
            dayKey: todayKey,
            tagIDs: tagIDsString
        )
        modelContext.insert(newEntry)
        draftText = ""
        composerSelectedTagIDs.removeAll()
        BoardEvents.changed()
    }

    private func autoTagIfKeywordsMatch(text: String, targetSet: inout Set<UUID>) {
        let lower = text.lowercased()
        if lower.contains("密码") || lower.contains("password") || lower.contains("pwd") {
            ensureTag(named: "密码", into: &targetSet)
        }
        if lower.contains("巧思") || lower.contains("灵感") || lower.contains("idea") {
            ensureTag(named: "小巧思", into: &targetSet)
        }
    }

    private func ensureTag(named name: String, into targetSet: inout Set<UUID>) {
        if let found = activeTags.first(where: { $0.name == name }) {
            targetSet.insert(found.id)
        } else {
            let tag = TagItem(name: name, sortOrder: activeTags.count)
            modelContext.insert(tag)
            targetSet.insert(tag.id)
        }
    }

    private func tagColor(_ name: String) -> Color {
        if name == "密码" { return Color.red }
        if name == "小巧思" { return Color.orange }
        if name == "日记" { return Color.blue }
        return DaybookTheme.stamp
    }
}

// MARK: - Diary Note Card

/// 现代灵感手记独立卡片：支持隐私遮罩、快捷复制、置顶、就地编辑与标签导航
struct DiaryNoteCard: View {
    @Environment(\.modelContext) private var modelContext
    var entry: DiaryEntry
    var activeTags: [TagItem]
    var attachments: [AttachmentItem]
    var onTagTap: (UUID) -> Void
    var onDelete: () -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editDraft = ""
    @State private var isMasked = true
    @State private var hasCopied = false

    /// 是否属于密码类型的记录
    private var isPasswordType: Bool {
        let hasPasswordTag = activeTags.contains { tag in
            (tag.name == "密码" || tag.name.localizedCaseInsensitiveContains("password"))
                && TagIDList.contains(entry.tagIDs, tag.id)
        }
        let textContainsPassword = entry.text.contains("#密码")
        return hasPasswordTag || textContainsPassword
    }

    private var entryTags: [TagItem] {
        activeTags.filter { TagIDList.contains(entry.tagIDs, $0.id) }
    }

    private var noteAttachments: [AttachmentRef] {
        CatalogChoices.attachments(entry.id, in: attachments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 卡片顶栏：时间戳、置顶徽章、操作按钮
            HStack(alignment: .center, spacing: 6) {
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DaybookTheme.stamp)
                }

                Text(formatDate(entry.createdAt))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(DaybookTheme.muted)

                if isPasswordType {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 9))
                        Text("隐私备忘")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(
                        Capsule().fill(Color.red.opacity(0.10))
                    )
                }

                Spacer()

                actionButtons
            }

            // 正文内容（支持密码隐私遮罩）
            contentView

            // 附件缩略图
            if !noteAttachments.isEmpty {
                AttachmentThumbnails(items: noteAttachments)
                    .padding(.top, 2)
            }

            // 底部标签栏
            if !entryTags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(entryTags) { tag in
                        Button {
                            onTagTap(tag.id)
                        } label: {
                            Text("#\(tag.name)")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(tag.name == "密码" ? Color.red : DaybookTheme.stamp)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill((tag.name == "密码" ? Color.red : DaybookTheme.stamp).opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("筛选此标签")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(isHovered ? DaybookTheme.cardSurfaceHover : DaybookTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(entry.isPinned ? DaybookTheme.stamp.opacity(0.35) : (isHovered ? DaybookTheme.cardBorderHover : DaybookTheme.cardBorder), lineWidth: entry.isPinned ? 1.2 : 0.8)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if isEditing {
            VStack(alignment: .trailing, spacing: 6) {
                TextEditor(text: $editDraft)
                    .font(.system(size: 13))
                    .frame(minHeight: 50)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DaybookTheme.surface)
                            .stroke(DaybookTheme.focusRing, lineWidth: 1.2)
                    )

                HStack {
                    Button("取消") {
                        isEditing = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))

                    Button("保存") {
                        let next = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !next.isEmpty {
                            DayBoardMutations.editDiary(entry, text: next)
                        }
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 11))
                }
            }
        } else {
            if isPasswordType && isMasked {
                HStack(spacing: 8) {
                    Text("••••••••••••••••")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(DaybookTheme.muted)
                        .blur(radius: 1.5)

                    Spacer()

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            isMasked = false
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "eye")
                                .font(.system(size: 10))
                            Text("显示内容")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(DaybookTheme.stamp)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(DaybookTheme.stamp.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            } else {
                Text(entry.text)
                    .font(.system(size: 13))
                    .lineSpacing(3.5)
                    .foregroundStyle(DaybookTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editDraft = entry.text
                        isEditing = true
                    }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 3) {
            if isPasswordType {
                Button(action: copyContent) {
                    HStack(spacing: 2) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .bold))
                        Text(hasCopied ? "已复制" : "复制密码")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(hasCopied ? Color.green : DaybookTheme.stamp)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule().fill((hasCopied ? Color.green : DaybookTheme.stamp).opacity(0.14))
                    )
                }
                .buttonStyle(.plain)
                .help("复制密码内容到剪贴板")

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        isMasked.toggle()
                    }
                } label: {
                    Image(systemName: isMasked ? "eye" : "eye.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(isMasked ? "显示明文" : "隐藏遮罩")
            } else {
                Button(action: copyContent) {
                    Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(hasCopied ? Color.green : DaybookTheme.muted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("复制内容")
            }

            Button {
                DayBoardMutations.togglePinDiary(entry)
            } label: {
                Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundStyle(entry.isPinned ? DaybookTheme.stamp : DaybookTheme.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(entry.isPinned ? "取消置顶" : "置顶到顶部")

            Button {
                editDraft = entry.text
                isEditing = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("编辑记录 (可双击文字)")

            Button {
                AttachmentActions.pickImage(ownerKind: .diary, ownerID: entry.id, context: modelContext)
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("添加图片附件")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.destructive.opacity(0.8))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("移入废纸篓")
        }
        .opacity(isHovered || isPasswordType || entry.isPinned ? 1.0 : 0.0)
    }

    private func copyContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        withAnimation(.snappy) {
            hasCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.snappy) {
                hasCopied = false
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "今天 HH:mm"
            return formatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "昨天 HH:mm"
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
