import AppKit
import SwiftData
import SwiftUI

/// 菜单栏手记紧凑数据条：严格锁定 48pt 固定高度，规范化展示标题/正文预览，并通过统一设置菜单与 ⌘ 快捷键提供深度操作。
struct DiarySummaryRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var entry: DiaryEntry
    var privacyTags: [TagItem] = []
    var allTags: [TagItem] = []
    var isSelected = false
    var isHighlighted = false
    var onSelect: (() -> Void)? = nil
    var onDelete: () -> Void

    @State var chrome = BoardRowChrome()
    @State private var hasCopied = false
    @State var hasNoteCopied = false
    @State private var hasConvertedToTask = false
    @State private var pickingDay = false
    @State var growsUpward = false
    @State var bubbleShiftX: CGFloat = 0

    var isHovered: Bool {
        get { chrome.isRowHovered }
        nonmutating set { chrome.isRowHovered = newValue }
    }

    var isCommandPressed: Bool {
        get { chrome.isCommandPressed }
        nonmutating set { chrome.isCommandPressed = newValue }
    }

    var isTitleTextHovered: Bool {
        get { chrome.isTitleTextHovered }
        nonmutating set { chrome.isTitleTextHovered = newValue }
    }

    var isTitleBubbleHovered: Bool {
        get { chrome.isTitleBubbleHovered }
        nonmutating set { chrome.isTitleBubbleHovered = newValue }
    }

    var isNoteHovered: Bool {
        get { chrome.isNoteHovered }
        nonmutating set { chrome.isNoteHovered = newValue }
    }

    var isNoteBubbleHovered: Bool {
        get { chrome.isNoteBubbleHovered }
        nonmutating set { chrome.isNoteBubbleHovered = newValue }
    }

    var isSensitive: Bool { DiaryPrivacy.isSensitive(entry.snapshot, tags: privacyTags) }
    var previewText: String {
        isSensitive ? L10n.string("diary.private.title", locale: locale) : Self.preview(entry.text)
    }

    struct NotePresentation {
        let mainText: String
        let note: String?

        var hasMultipleLines: Bool { note != nil }
        var title: String? { note == nil ? nil : mainText }
        var body: String { note ?? mainText }
    }

    static func preview(_ text: String) -> String {
        let prefix = text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(401)
        let snippet = prefix.prefix(400).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return snippet + (prefix.count > 400 ? "…" : "")
    }

    var contentPresentation: NotePresentation {
        if isSensitive {
            return NotePresentation(mainText: L10n.string("diary.private.title", locale: locale), note: nil)
        }
        let raw = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let newlineIndex = raw.firstIndex(of: "\n") else {
            return NotePresentation(mainText: raw, note: nil)
        }
        let firstLine = String(raw[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rest = String(raw[raw.index(after: newlineIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

        if firstLine.isEmpty {
            return NotePresentation(mainText: rest, note: nil)
        }
        return NotePresentation(mainText: firstLine, note: rest.isEmpty ? nil : rest)
    }

    private var assignedTags: [TagItem] {
        DiaryMemoTags.ordered(
            allTags.filter { TagIDList.contains(entry.tagIDs, $0.id) },
            name: { $0.name },
            isActive: { _ in true }
        )
    }

    private var assignedTagIDs: Set<UUID> {
        Set(TagIDList.parse(entry.tagIDs))
    }

    var body: some View {
        rowContent
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 46)
            .daybookSurface(.row, isHovered: isHovered, isSelected: isSelected || isHighlighted)
            .overlay(pinnedBorderOverlay)
            .background(pointerRegion(isTitle: false).accessibilityHidden(true))
            .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
            .simultaneousGesture(TapGesture().onEnded {
                chrome.revealRow(reduceMotion: reduceMotion)
                onSelect?()
            })
            .onHover { chrome.handleRowHover($0, reduceMotion: reduceMotion) }
            .popover(isPresented: $pickingDay) { daySchedulePopover }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("diary.summary." + entry.id.uuidString)
            .zIndex((shouldShowTitleBubble || shouldShowNoteBubble) ? 120 : (isHovered ? 100 : 1))
            .contextMenu { diaryMenuItems }
            .modifier(DiaryRowTaskLifecycleModifier(
                chrome: chrome,
                reduceMotion: reduceMotion,
                hasCopied: $hasCopied,
                hasNoteCopied: $hasNoteCopied,
                hasConvertedToTask: $hasConvertedToTask
            ))
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            headerRow.zIndex(10)
            footerRow.zIndex(1)
        }
    }

    private var pinnedBorderOverlay: some View {
        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
            .strokeBorder(
                (entry.isPinned && !isSelected && !isHighlighted)
                    ? DaybookPalette.accent.base.opacity(0.28) // token-exempt: 28% 印章色没有对应令牌
                    : Color.clear,
                lineWidth: 0.8
            )
            .allowsHitTesting(false)
    }

    // MARK: - 第 1 行：主视觉行 (标题/正文首行 + 恒定 22x22 占位的设置按钮)

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 4) {
            noteContentHeader
                .frame(maxWidth: .infinity, alignment: .leading)

            actionCluster
                .frame(width: 48, height: 22)
        }
    }

    @ViewBuilder
    private var noteContentHeader: some View {
        let presentation = contentPresentation
        HStack(alignment: .center, spacing: 4) {
            Text(presentation.mainText.isEmpty ? " " : presentation.mainText)
                .font(DaybookType.body)
                .foregroundStyle(isSensitive ? DaybookPalette.text.secondary : DaybookPalette.text.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)
                .overlay(pointerRegion(isTitle: true).accessibilityHidden(true))
                .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                    titleBubbleOverlay(for: presentation.mainText)
                }

            if !isSensitive, let note = presentation.note, !note.isEmpty {
                noteIndicator(fullText: note)
                    .fixedSize()
            }

            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .contentShape(Rectangle())
                .overlay(pointerRegion(isTitle: false).accessibilityHidden(true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { updateBubblePlacement(proxy) }
                    .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateBubblePlacement(proxy) }
                    .onChange(of: proxy.frame(in: .global).minX) { _, _ in updateBubblePlacement(proxy) }
            }
        )
    }

    // MARK: - 右侧快捷操作区 (恒定 48x22 占位：📋 复制 + ··· 更多菜单，纯透明度渐变，零抖动)

    private var actionCluster: some View {
        HStack(spacing: 4) {
            copyButton
            moreMenu
        }
        .frame(width: 48, height: 22)
        .opacity((isHovered || isSelected || isHighlighted) && !isCommandPressed ? 1.0 : 0.0)
        .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
        .animation(DaybookMotion.interactive(reduceMotion), value: isSelected)
        .animation(DaybookMotion.interactive(reduceMotion), value: isCommandPressed)
    }

    private var copyButton: some View {
        Button(action: copy) {
            Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                .font(DaybookType.caption.weight(.semibold))
        }
        .buttonStyle(DaybookButtonStyle(hasCopied ? .iconActive : .icon, size: .compact))
        .help(L10n.string(hasCopied ? "diary.copied" : "diary.quick.copy", locale: locale))
        .accessibilityLabel(L10n.string(hasCopied ? "diary.copied" : "diary.quick.copy", locale: locale))
        .fixedSize()
    }

    private var moreMenu: some View {
        Menu {
            diaryMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(DaybookType.caption.weight(.semibold))
                .daybookMenuLabel(size: .compact)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("footer.more")
        .accessibilityLabel("footer.more")
        .fixedSize()
    }

    @ViewBuilder
    private var diaryMenuItems: some View {
        // 分区 1: 核心动作与流转
        Button("diary.quick.copy", action: copy)
        Button("diary.quick.open", action: openWindow)

        // 分区 2: 组织与分类（标签、排程日期、置顶）
        if !allTags.isEmpty {
            Menu("diary.quick.tags") {
                DiaryTagToggleButtons(
                    tags: allTags,
                    assignedIDs: Set(TagIDList.parse(entry.tagIDs)),
                    onToggle: toggleTag
                )
            }
        }

        Menu("diary.quick.schedule") {
            DiaryDayMoveButtons(onMove: moveDiary(to:), onPickCustom: { pickingDay = true })
        }

        Button(entry.isPinned ? "diary.unpin" : "diary.pin", action: togglePin)

        Divider()

        // 分区 3: 资产与安全环境
        Button("diary.attach", action: attach).disabled(isSensitive)
        Button(isSensitive ? "diary.quick.privacy.unlock" : "diary.quick.privacy.lock", action: togglePrivate)
        Button("diary.window.workspace", action: inspectInWorkspace)

        Divider()

        // 分区 4: 危险操作（移入废纸篓）
        Button("alert.trash.move", role: .destructive, action: onDelete)
    }

    // MARK: - 第 2 行：微信息区 (状态 / 时间 / 标签)

    private var footerRow: some View {
        Group {
            if isHovered && isCommandPressed {
                DiaryRowCommandStrip(
                    isSensitive: isSensitive,
                    isPinned: entry.isPinned,
                    hasConvertedToTask: hasConvertedToTask,
                    allTags: allTags,
                    assignedTagIDs: Set(TagIDList.parse(entry.tagIDs)),
                    currentDayKey: entry.dayKey,
                    onOpen: openWindow,
                    onConvertToTask: convertToTask,
                    onCopy: copy,
                    onToggleTag: toggleTag,
                    onMoveToDay: moveDiary,
                    onPickCustomDate: { pickingDay = true },
                    onTogglePin: togglePin,
                    onAttach: attach,
                    onTogglePrivate: togglePrivate,
                    onInspect: inspectInWorkspace,
                    onDelete: onDelete
                )
                .transition(.opacity)
            } else {
                metadataLine
                    .contentShape(Rectangle())
                    .overlay(
                        pointerRegion(isTitle: false)
                            .accessibilityHidden(true)
                    )
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 24, alignment: .leading)
        .animation(DaybookMotion.interactive(reduceMotion), value: isHovered && isCommandPressed)
    }

    private var metadataLine: some View {
        HStack(spacing: 5) {
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8.5)) // token-exempt: 小于 9pt 的图钉和锁图标
                    .foregroundStyle(DaybookPalette.accent.base)
                    .accessibilityLabel("diary.pin")
            }
            if isSensitive {
                Image(systemName: "lock.shield")
                    .font(.system(size: 8.5)) // token-exempt: 小于 9pt 的图钉和锁图标
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityLabel("diary.privacy")
            }
            Text(dateLabel)
                .lineLimit(1)
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.secondary)

            if !assignedTags.isEmpty {
                HStack(spacing: 3) {
                    ForEach(assignedTags) { tag in
                        tagPill(tag)
                    }
                }
            }
            if hasCopied {
                Label("diary.copied", systemImage: "checkmark")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.accent.base)
            }
            Spacer(minLength: 0)
        }
        .font(DaybookType.badge)
    }

    private func tagPill(_ tag: TagItem) -> some View {
        DiaryTagPill(name: tag.name)
    }

    private var dateLabel: String {
        let format = DateFormatter()
        format.locale = locale
        format.timeStyle = .short
        let time = format.string(from: entry.createdAt)
        if Calendar.current.isDateInToday(entry.createdAt) { return L10n.format("diary.date.today", locale: locale, time) }
        if Calendar.current.isDateInYesterday(entry.createdAt) { return L10n.format("diary.date.yesterday", locale: locale, time) }
        format.dateStyle = .short
        return format.string(from: entry.createdAt)
    }

    func openWindow() { DiaryWindows.shared.open(entry: entry, context: context) }

    private func copy() {
        PrivacyAccess.withDiary(entry) { current in
            let text = try DiaryContent.read(current)
            guard PrivateClipboard.copy(text, sensitive: current.hasProtectedContent || isSensitive) else { throw PrivacyError.storageFailure }
            hasCopied = true
        }
    }

    func copyTitle(_ title: String) {
        PrivacyAccess.withDiary(entry) { current in
            guard PrivateClipboard.copy(title, sensitive: current.hasProtectedContent || isSensitive) else { throw PrivacyError.storageFailure }
            hasCopied = true
        }
    }

    func copyNote(_ note: String) {
        PrivacyAccess.withDiary(entry) { current in
            guard PrivateClipboard.copy(note, sensitive: current.hasProtectedContent || isSensitive) else { throw PrivacyError.storageFailure }
            hasCopied = true
        }
    }

    private func attach() {
        AttachmentActions.pickImage(ownerKind: .diary, ownerID: entry.id, context: context, canAttach: {
            guard entry.deletedAt == nil, let tags = try? context.fetch(FetchDescriptor<TagItem>()) else { return false }
            return !DiaryPrivacy.isSensitive(entry.snapshot, tags: tags)
        })
    }

    private func togglePin() {
        DayBoardMutations.togglePinDiary(entry)
    }

    private func inspectInWorkspace() {
        BoardSelection.shared.inspectDiary(id: entry.id, dayKey: entry.dayKey)
        AppWindows.openDiary()
    }

    private func convertToTask() {
        if DayBoardMutations.convertDiaryToTodo(entry, context: context) {
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                hasConvertedToTask = true
            }
        }
    }

    private func toggleTag(_ tagID: UUID) {
        DayBoardMutations.toggleDiaryTag(entry, tagID: tagID)
    }

    private func moveDiary(to newDayKey: String) {
        DayBoardMutations.moveDiary(entry, to: newDayKey)
    }

    private func togglePrivate() {
        DayBoardMutations.togglePrivateDiary(entry)
    }

    @ViewBuilder
    private var daySchedulePopover: some View {
        DaySchedulePicker(initialKey: entry.dayKey) { key in
            moveDiary(to: key)
            pickingDay = false
        }
    }
}

// MARK: - 生命周期与事件监听辅助修饰符

private struct DiaryRowTaskLifecycleModifier: ViewModifier {
    var chrome: BoardRowChrome
    var reduceMotion: Bool
    @Binding var hasCopied: Bool
    @Binding var hasNoteCopied: Bool
    @Binding var hasConvertedToTask: Bool

    func body(content: Content) -> some View {
        content
            .task(id: hasCopied) {
                guard hasCopied else { return }
                try? await Task.sleep(for: .milliseconds(1200))
                if !Task.isCancelled { hasCopied = false }
            }
            .task(id: hasNoteCopied) {
                guard hasNoteCopied else { return }
                try? await Task.sleep(for: .milliseconds(1200))
                if !Task.isCancelled { hasNoteCopied = false }
            }
            .task(id: hasConvertedToTask) {
                guard hasConvertedToTask else { return }
                try? await Task.sleep(for: .milliseconds(1500))
                if !Task.isCancelled { hasConvertedToTask = false }
            }
            .onAppear { chrome.startCommandMonitor(reduceMotion: reduceMotion) }
            .onDisappear { chrome.stop() }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
                chrome.resignCommand()
            }
    }
}
