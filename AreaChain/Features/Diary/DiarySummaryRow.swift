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

    private var isSensitive: Bool { DiaryPrivacy.isSensitive(entry.snapshot, tags: privacyTags) }
    var previewText: String {
        isSensitive ? L10n.string("diary.private.title", locale: locale) : Self.preview(entry.text)
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
            Text(previewText)
                .font(DaybookType.body)
                .lineSpacing(2)
                .foregroundStyle(isSensitive ? DaybookTheme.muted : DaybookTheme.ink)
                .lineLimit(2).truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            metadataLine
        }
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
            Text(previewText)
                .font(DaybookType.body)
                .lineSpacing(2)
                .foregroundStyle(isSensitive ? DaybookTheme.muted : DaybookTheme.ink)
                .lineLimit(2).truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    // 1. 打开小窗 ↗
                    commandStripButton(
                        icon: "arrow.up.forward.square",
                        key: "diary.quick.open",
                        action: openWindow
                    )
                    // 2. 复制手记 📋
                    commandStripButton(
                        icon: "doc.on.doc",
                        key: "diary.quick.copy",
                        action: copy
                    )
                    // 3. 置顶 / 取消置顶 📌
                    commandStripButton(
                        icon: entry.isPinned ? "pin.slash" : "pin",
                        key: entry.isPinned ? "diary.quick.unpin" : "diary.quick.pin",
                        isActive: entry.isPinned,
                        action: togglePin
                    )
                    // 4. 添加附件 📎
                    commandStripButton(
                        icon: "paperclip",
                        key: "diary.quick.attach",
                        action: attach
                    )
                    .disabled(isSensitive)
                    // 5. 工作台查看 🖥
                    commandStripButton(
                        icon: "macwindow",
                        key: "diary.quick.workspace",
                        action: inspectInWorkspace
                    )
                    // 6. 删除手记 🗑
                    commandStripButton(
                        icon: "trash",
                        key: "diary.quick.delete",
                        isDestructive: true,
                        action: onDelete
                    )
                }
                .fixedSize(horizontal: true, vertical: true)

                if let tip = hoveredQuickActionTip {
                    Text(tip)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DaybookTheme.ink.opacity(0.85))
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(
                            Capsule()
                                .fill(DaybookTheme.surface)
                                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(DaybookTheme.rule.opacity(0.4), lineWidth: 0.5)
                        )
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .frame(height: 22)
            .clipped()
        }
    }

    private func commandStripButton(
        icon: String,
        key: String,
        isActive: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let localizedText = L10n.string(String.LocalizationValue(stringLiteral: key), locale: locale)
        return Button(action: action) {
            commandStripIcon(
                icon: icon,
                isButtonHovered: hoveredQuickActionTip == localizedText,
                isActive: isActive,
                isDestructive: isDestructive
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LocalizedStringKey(key))
        .help(LocalizedStringKey(key))
        .background(
            QuickActionHoverArea { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    if hovering {
                        hoveredQuickActionTip = localizedText
                    } else if hoveredQuickActionTip == localizedText {
                        hoveredQuickActionTip = nil
                    }
                }
            }
        )
    }

    private func commandStripIcon(
        icon: String,
        isButtonHovered: Bool,
        isActive: Bool = false,
        isDestructive: Bool = false
    ) -> some View {
        Image(systemName: icon)
            .font(.system(size: 10.5, weight: .medium))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(
                        isDestructive
                            ? (isButtonHovered ? Color.red.opacity(0.18) : Color.red.opacity(0.08))
                            : (isActive
                                ? DaybookTheme.stamp.opacity(isButtonHovered ? 0.22 : 0.14)
                                : (isButtonHovered ? DaybookTheme.ink.opacity(0.12) : DaybookTheme.ink.opacity(0.05)))
                    )
            )
            .foregroundStyle(
                isDestructive
                    ? Color.red
                    : (isActive ? DaybookTheme.stamp : DaybookTheme.ink.opacity(isButtonHovered ? 0.95 : 0.72))
            )
            .contentShape(Rectangle())
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

/// 原生 clickCount 让第一次点击立即选中，双击直接打开独立编辑小窗
struct DiaryRowPointerRegion: NSViewRepresentable {
    var id: UUID
    var onSelect: () -> Void
    var onOpen: () -> Void

    func makeNSView(context: Context) -> DiaryRowPointerView {
        let view = DiaryRowPointerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: DiaryRowPointerView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        view.onSelect = onSelect
        view.onOpen = onOpen
    }
}

final class DiaryRowPointerView: NSView {
    var onSelect: (() -> Void)?
    var onOpen: (() -> Void)?
    private var mouseDownLocation: NSPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.control) else {
            super.mouseDown(with: event)
            return
        }
        mouseDownLocation = event.locationInWindow
        window?.makeFirstResponder(self)
        onSelect?()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownLocation = nil }
        let stayedNearStart = mouseDownLocation.map {
            hypot(event.locationInWindow.x - $0.x, event.locationInWindow.y - $0.y) < 4
        } ?? false
        let shouldOpen = event.clickCount == 2
            && !event.modifierFlags.contains(.control)
            && stayedNearStart && bounds.contains(convert(event.locationInWindow, from: nil))
        super.mouseUp(with: event)
        if shouldOpen { onOpen?() }
    }
}
