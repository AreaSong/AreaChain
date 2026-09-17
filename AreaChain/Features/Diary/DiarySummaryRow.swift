import AppKit
import SwiftData
import SwiftUI

/// 菜单栏只展示有界的正文预览，完整阅读与编辑交给同一条手记的小窗。
struct DiarySummaryRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    var entry: DiaryEntry
    var privacyTags: [TagItem]
    var isSelected = false
    var isHighlighted = false
    var onSelect: (() -> Void)? = nil
    var onDelete: () -> Void
    @State private var isHovered = false
    @State private var hasCopied = false

    private var isSensitive: Bool { DiaryPrivacy.isSensitive(entry.snapshot, tags: privacyTags) }
    var previewText: String {
        isSensitive ? L10n.string("diary.private.title", locale: locale) : Self.preview(entry.text)
    }

    static func preview(_ text: String) -> String {
        let prefix = text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(401)
        let snippet = prefix.prefix(400).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return snippet + (prefix.count > 400 ? "…" : "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            selectableContent
            actionCluster
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .foregroundStyle(DaybookTheme.muted)
        .background(
            (isSelected || isHighlighted) ? DaybookTheme.cardSelectionFill : (isHovered ? DaybookTheme.hoverFill : .clear),
            in: RoundedRectangle(cornerRadius: DaybookRadius.small)
        )
        .overlay(alignment: .bottom) { Divider().overlay(DaybookTheme.rule.opacity(0.5)).padding(.horizontal, 9) }
        .onHover { isHovered = $0 }
        .task(id: hasCopied) {
            guard hasCopied else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            if !Task.isCancelled { hasCopied = false }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("diary.summary." + entry.id.uuidString)
    }

    private var selectableContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(previewText)
                .font(DaybookType.body)
                .foregroundStyle(isSensitive ? DaybookTheme.muted : DaybookTheme.ink)
                .lineLimit(2).truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 5) {
                if entry.isPinned { Image(systemName: "pin.fill").accessibilityLabel("diary.pin") }
                if isSensitive { Image(systemName: "lock.shield").accessibilityLabel("diary.privacy") }
                Text(dateLabel).lineLimit(1)
                if hasCopied {
                    Label("diary.copied", systemImage: "checkmark").foregroundStyle(DaybookTheme.stamp)
                }
            }
            .font(DaybookType.badge).foregroundStyle(DaybookTheme.muted)
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

    private var moreMenu: some View {
        Menu {
            Button("diary.window.open", action: openWindow)
            Button(hasCopied ? "diary.copied" : (isSensitive ? "diary.copy.password" : "diary.copy"), action: copy)
            Button(entry.isPinned ? "diary.unpin" : "diary.pin") { DayBoardMutations.togglePinDiary(entry) }
            Button("diary.attach", action: attach).disabled(isSensitive)
            Button("diary.window.workspace") {
                BoardSelection.shared.inspectDiary(id: entry.id, dayKey: entry.dayKey)
                AppWindows.openDiary()
            }
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
