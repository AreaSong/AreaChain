import AppKit
import SwiftData
import SwiftUI

/// 菜单栏手记紧凑数据条：严格锁定 48pt 固定高度，规范化展示标题/正文预览，并通过统一设置菜单与 ⌘ 快捷键提供深度操作。
struct DiarySummaryRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var entry: DiaryEntry
    var privacyTags: [TagItem] = []
    var allTags: [TagItem] = []
    var isSelected = false
    var isHighlighted = false
    var onSelect: (() -> Void)? = nil
    var onDelete: () -> Void

    @State private var isHovered = false
    @State private var hasCopied = false
    @State private var isCommandPressed = false
    @State private var flagsMonitor: Any? = nil
    @State private var isTitleTextHovered = false
    @State private var isNoteHovered = false
    @State private var growsUpward = false
    @State private var bubbleShiftX: CGFloat = 0

    private var isSensitive: Bool { DiaryPrivacy.isSensitive(entry.snapshot, tags: privacyTags) }
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

    private var shouldShowTitleBubble: Bool {
        !isSensitive && isTitleTextHovered && RowTitleTruncation.isTruncated(contentPresentation.mainText)
    }

    private var shouldShowNoteBubble: Bool {
        !isSensitive && isNoteHovered && contentPresentation.note != nil
    }

    private var assignedTags: [TagItem] {
        DiaryMemoTags.ordered(
            allTags.filter { TagIDList.contains(entry.tagIDs, $0.id) },
            name: { $0.name },
            isActive: { _ in true }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
                .frame(height: 18)

            footerRow
                .frame(height: 24)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 54)
        .modernRow(
            cornerRadius: DaybookRadius.small,
            isHovered: isHovered,
            isSelected: isSelected || isHighlighted
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(
                    (entry.isPinned && !isSelected && !isHighlighted)
                        ? DaybookTheme.stamp.opacity(0.28)
                        : Color.clear,
                    lineWidth: 0.8
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .overlay(
            DiaryRowPointerRegion(
                id: entry.id,
                onSelect: { onSelect?() },
                onOpen: openWindow
            )
            .accessibilityHidden(true)
        )
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                isCommandPressed = NSEvent.modifierFlags.contains(.command)
            }
        }
        .task(id: hasCopied) {
            guard hasCopied else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            if !Task.isCancelled { hasCopied = false }
        }
        .onAppear { setupFlagsMonitor() }
        .onDisappear { tearDownFlagsMonitor() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            isCommandPressed = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("diary.summary." + entry.id.uuidString)
        .zIndex((isHovered || shouldShowTitleBubble || shouldShowNoteBubble) ? 100 : 1)
    }

    // MARK: - 第 1 行：主视觉行 (标题/正文首行 + 恒定 22x22 占位的设置按钮)

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 4) {
            noteContentHeader
                .frame(maxWidth: .infinity, alignment: .leading)

            actionCluster
                .frame(width: 22, height: 22)
        }
        .frame(height: 18)
    }

    @ViewBuilder
    private var noteContentHeader: some View {
        let presentation = contentPresentation
        HStack(alignment: .center, spacing: 4) {
            Text(presentation.mainText.isEmpty ? " " : presentation.mainText)
                .font(DaybookType.body)
                .foregroundStyle(isSensitive ? DaybookTheme.muted : DaybookTheme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        isTitleTextHovered = hovering
                    }
                }
                .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                    if shouldShowTitleBubble {
                        RowTitleBubble(title: presentation.mainText, growsUpward: growsUpward)
                            .offset(y: growsUpward ? -6 : 22)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: growsUpward ? .bottomLeading : .topLeading)),
                                removal: .opacity
                            ))
                    }
                }

            if !isSensitive, let note = presentation.note, !note.isEmpty {
                noteIndicator(fullText: note)
            }

            Spacer(minLength: 0)
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

    private func noteIndicator(fullText: String) -> some View {
        Image(systemName: "text.alignleft")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65))
            .padding(.horizontal, 3.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(isNoteHovered ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04))
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isNoteHovered = hovering
                }
            }
            .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                if shouldShowNoteBubble {
                    let arrowPadding = max(8, min(186, 8 - bubbleShiftX))
                    let transformAnchor = UnitPoint(
                        x: max(0.06, min(0.94, (arrowPadding + 3.5) / 210.0)),
                        y: growsUpward ? 1.0 : 0.0
                    )
                    RowNoteBubble(note: fullText, growsUpward: growsUpward, bubbleShiftX: bubbleShiftX, headerTitleKey: "drawer.notes.title")
                        .offset(x: -8 + bubbleShiftX, y: growsUpward ? -18 : 16)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: transformAnchor)),
                            removal: .opacity
                        ))
                }
            }
    }

    private func updateBubblePlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        let placement = RowBubblePlacement.calculate(globalPoint: CGPoint(x: frame.minX, y: frame.minY), isWorkspace: false)
        growsUpward = placement.growsUpward
        bubbleShiftX = placement.bubbleShiftX
    }

    // MARK: - 右侧单按钮设置菜单 (恒定 22x22 占位，避免任何横向跳动)

    private var actionCluster: some View {
        moreMenu
            .opacity((isHovered || isSelected || isHighlighted) && !isCommandPressed ? 1.0 : 0.0)
            .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
            .animation(DaybookMotion.interactive(reduceMotion), value: isSelected)
            .animation(DaybookMotion.interactive(reduceMotion), value: isCommandPressed)
    }

    private var moreMenu: some View {
        Menu {
            Button("diary.window.open", action: openWindow)
            Button(hasCopied ? "diary.copied" : (isSensitive ? "diary.copy.password" : "diary.copy"), action: copy)
            Button(entry.isPinned ? "diary.unpin" : "diary.pin", action: togglePin)
            Button("diary.attach", action: attach).disabled(isSensitive)
            Button("diary.window.workspace", action: inspectInWorkspace)
            Divider()
            Button("alert.trash.move", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(DaybookTheme.ink.opacity(0.06))
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help("footer.more")
        .accessibilityLabel("footer.more")
        .fixedSize()
    }

    // MARK: - 第 2 行：次视觉行 (原位平滑互换：平时元数据 vs ⌘ 平铺条，恒定 22pt)

    private var footerRow: some View {
        ZStack(alignment: .leading) {
            if isHovered && isCommandPressed {
                DiaryRowCommandStrip(
                    isSensitive: isSensitive,
                    isPinned: entry.isPinned,
                    onOpen: openWindow,
                    onCopy: copy,
                    onTogglePin: togglePin,
                    onAttach: attach,
                    onInspect: inspectInWorkspace,
                    onDelete: onDelete
                )
                .transition(.opacity)
            } else {
                metadataLine
                    .transition(.opacity)
            }
        }
        .frame(height: 24, alignment: .leading)
        .animation(DaybookMotion.interactive(reduceMotion), value: isHovered && isCommandPressed)
    }

    private var metadataLine: some View {
        HStack(spacing: 5) {
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8.5))
                    .foregroundStyle(DaybookTheme.stamp)
                    .accessibilityLabel("diary.pin")
            }
            if isSensitive {
                Image(systemName: "lock.shield")
                    .font(.system(size: 8.5))
                    .foregroundStyle(DaybookTheme.muted)
                    .accessibilityLabel("diary.privacy")
            }
            Text(dateLabel)
                .lineLimit(1)
                .font(DaybookType.badge)
                .foregroundStyle(DaybookTheme.muted)

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
                    .foregroundStyle(DaybookTheme.stamp)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 24)
        .font(DaybookType.badge)
    }

    private func tagPill(_ tag: TagItem) -> some View {
        let color = DiaryTagChrome.color(for: tag.name)
        return Text("#" + tag.name)
            .font(.system(size: 9.5, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .foregroundStyle(color)
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
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

    private func openWindow() { DiaryWindows.shared.open(entry: entry, context: context) }

    private func copy() {
        PrivacyAccess.withDiary(entry) { current in
            let text = try DiaryContent.read(current)
            guard PrivateClipboard.copy(text, sensitive: current.hasProtectedContent || isSensitive) else { throw PrivacyError.storageFailure }
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

    private func setupFlagsMonitor() {
        isCommandPressed = NSEvent.modifierFlags.contains(.command)
        guard flagsMonitor == nil else { return }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            isCommandPressed = event.modifierFlags.contains(.command)
            return event
        }
    }

    private func tearDownFlagsMonitor() {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }
}
