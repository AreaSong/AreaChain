import AppKit
import SwiftData
import SwiftUI

/// 菜单栏只展示有界的正文预览，完整阅读与编辑交给同一条手记的小窗。
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
    @State private var hoveredQuickActionTip: String? = nil
    @State private var flagsMonitor: Any? = nil
    @State private var isNoteHovered = false
    @State private var growsUpward = false
    @State private var bubbleShiftX: CGFloat = 0

    private var isSensitive: Bool { DiaryPrivacy.isSensitive(entry.snapshot, tags: privacyTags) }
    var previewText: String {
        isSensitive ? L10n.string("diary.private.title", locale: locale) : Self.preview(entry.text)
    }

    struct NotePresentation {
        let title: String?
        let body: String
    }

    var contentPresentation: NotePresentation {
        if isSensitive {
            return NotePresentation(title: nil, body: L10n.string("diary.private.title", locale: locale))
        }
        let raw = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let newlineIndex = raw.firstIndex(of: "\n") else {
            return NotePresentation(title: nil, body: raw)
        }
        let firstLine = String(raw[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rest = String(raw[raw.index(after: newlineIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

        if firstLine.isEmpty {
            return NotePresentation(title: nil, body: rest)
        }
        if rest.isEmpty {
            return NotePresentation(title: nil, body: firstLine)
        }
        return NotePresentation(title: firstLine, body: rest)
    }

    @ViewBuilder
    private var noteContentHeader: some View {
        let presentation = contentPresentation
        if let title = presentation.title {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center, spacing: 4) {
                    Text(presentation.body)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)

                    if !isSensitive && !presentation.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        noteIndicator(fullText: presentation.body)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(alignment: .center, spacing: 4) {
                Text(presentation.body)
                    .font(DaybookType.body)
                    .lineSpacing(2)
                    .foregroundStyle(isSensitive ? DaybookTheme.muted : DaybookTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)

                if !isSensitive && !presentation.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    noteIndicator(fullText: presentation.body)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateBubblePlacement(proxy) }
                        .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateBubblePlacement(proxy) }
                        .onChange(of: proxy.frame(in: .global).minX) { _, _ in updateBubblePlacement(proxy) }
                }
            )
            .contentShape(Rectangle())
            .onHover { isNoteHovered = $0 }
            .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                if isNoteHovered {
                    let arrowPadding = max(8, min(186, 8 - bubbleShiftX))
                    let transformAnchor = UnitPoint(
                        x: max(0.06, min(0.94, (arrowPadding + 3.5) / 210.0)),
                        y: growsUpward ? 1.0 : 0.0
                    )
                    noteFloatingBubble(fullText: fullText, arrowPadding: arrowPadding)
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
        let globalY = frame.minY
        let globalX = frame.minX

        growsUpward = globalY > 260

        let safeMaxX: CGFloat = 356
        let safeMinX: CGFloat = 12
        let bubbleRight = globalX + 202
        if bubbleRight > safeMaxX {
            let overflow = bubbleRight - safeMaxX
            let maxShift = max(0, (globalX - 8) - safeMinX)
            bubbleShiftX = -min(overflow, maxShift)
        } else {
            bubbleShiftX = 0
        }
    }

    private func noteFloatingBubble(fullText: String, arrowPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !growsUpward {
                HStack {
                    Spacer().frame(width: arrowPadding)
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(DaybookTheme.paper)
                        .offset(y: 1)
                    Spacer()
                }
                .frame(height: 5)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(DaybookTheme.stamp)
                    Text(L10n.string("drawer.notes.title", locale: locale))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DaybookTheme.muted)
                    Spacer(minLength: 0)
                }

                Text(fullText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineSpacing(2.5)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(width: 210, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(DaybookTheme.paper)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(DaybookTheme.rule.opacity(0.8), lineWidth: 0.8)
            )

            if growsUpward {
                HStack {
                    Spacer().frame(width: arrowPadding)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(DaybookTheme.paper)
                        .offset(y: -1)
                    Spacer()
                }
                .frame(height: 5)
            }
        }
        .frame(width: 210, alignment: .leading)
        .fixedSize()
        .allowsHitTesting(false)
        .zIndex(999)
    }

    private var assignedTags: [TagItem] {
        DiaryMemoTags.ordered(
            allTags.filter { TagIDList.contains(entry.tagIDs, $0.id) },
            name: { $0.name },
            isActive: { _ in true }
        )
    }

    static func preview(_ text: String) -> String {
        let prefix = text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(401)
        let snippet = prefix.prefix(400).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return snippet + (prefix.count > 400 ? "…" : "")
    }

    var body: some View {
        Group {
            if isHovered && isCommandPressed {
                commandActionStrip
                    .transition(.opacity)
            } else {
                HStack(alignment: .top, spacing: 6) {
                    selectableContent
                    actionCluster
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 46)
        .foregroundStyle(DaybookTheme.muted)
        .background(
            (isSelected || isHighlighted)
                ? DaybookTheme.cardSelectionFill
                : (isHovered ? DaybookTheme.hoverFill : DaybookTheme.ink.opacity(0.025)),
            in: RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(
                    (isSelected || isHighlighted)
                        ? DaybookTheme.stamp.opacity(0.4)
                        : (entry.isPinned
                            ? DaybookTheme.stamp.opacity(0.28)
                            : (isHovered ? DaybookTheme.rule.opacity(0.6) : DaybookTheme.rule.opacity(0.25))),
                    lineWidth: (isSelected || isHighlighted || entry.isPinned) ? 1.0 : 0.6
                )
        )
        .onHover { isHovered = $0 }
        .task(id: hasCopied) {
            guard hasCopied else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            if !Task.isCancelled { hasCopied = false }
        }
        .onAppear {
            setupFlagsMonitor()
        }
        .onDisappear {
            tearDownFlagsMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            isCommandPressed = false
            hoveredQuickActionTip = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("diary.summary." + entry.id.uuidString)
    }

    private var selectableContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            noteContentHeader
            metadataLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(
            DiaryRowPointerRegion(
                id: entry.id,
                onSelect: { onSelect?() },
                onOpen: openWindow
            )
            .accessibilityHidden(true)
        )
    }

    private var metadataLine: some View {
        HStack(spacing: 5) {
            if entry.isPinned { Image(systemName: "pin.fill").font(.system(size: 9.5)).accessibilityLabel("diary.pin") }
            if isSensitive { Image(systemName: "lock.shield").font(.system(size: 9.5)).accessibilityLabel("diary.privacy") }
            Text(dateLabel).lineLimit(1).font(DaybookType.badge)
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
        .frame(height: 22)
        .font(DaybookType.badge)
        .foregroundStyle(DaybookTheme.muted)
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

    private var actionCluster: some View {
        HStack(spacing: 2) {
            Button(action: openWindow) {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 11.5, weight: .semibold))
                    .frame(width: 22, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("diary.window.open")
            .help("diary.window.open")

            moreMenu
        }
        .opacity((isHovered || isSelected || isHighlighted) ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - ⌘ 快捷平铺操作条（与「···」更多菜单 1:1 对齐）

    private var commandActionStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            noteContentHeader

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
        }
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
            Image(systemName: "ellipsis").frame(width: 22, height: 24)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
        .accessibilityLabel("footer.more")
        .fixedSize()
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
        if flagsMonitor == nil {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [self] event in
                self.isCommandPressed = event.modifierFlags.contains(.command)
                return event
            }
        }
    }

    private func tearDownFlagsMonitor() {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }
}
