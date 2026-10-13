import AppKit
import SwiftUI

struct ClipboardHistoryPage: View {
    @Bindable var session = ClipboardHistorySession.shared
    @State private var showsOptions = false

    var body: some View {
        DaybookPage(
            title: "window.clipboard",
            subtitle: "clipboard.subtitle",
            minWidth: 440,
            minHeight: 480,
            trailing: {
                HStack(spacing: DaybookSpacing.sm) {
                    Button("clipboard.showPanel") {
                        ClipboardHistoryPanel.shared.toggle()
                    }
                    .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
                    DaybookIconButton(
                        systemName: session.recording ? "pause" : "play",
                        label: session.recording ? "clipboard.pause" : "clipboard.resume",
                        size: .compact
                    ) {
                        session.setRecording(!session.recording)
                    }
                    DaybookIconButton(systemName: "gearshape", label: "clipboard.options", size: .compact) {
                        showsOptions = true
                    }
                    Menu {
                        Button("clipboard.clearUnpinned") { session.clear(includingPinned: false) }
                        Button("clipboard.clearAll", role: .destructive) { session.clear(includingPinned: true) }
                    } label: {
                        Image(systemName: "trash")
                            .font(DaybookType.caption.weight(.semibold))
                            .daybookMenuLabel(size: .compact)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .accessibilityLabel(Text("clipboard.clearUnpinned"))
                }
            },
            content: {
                ClipboardHistoryBrowser(session: session, showsFooter: true, commitsOnClick: false) { id, plain, paste in
                    ClipboardHistoryKeys.commit(id: id, plain: plain, paste: paste, inPanel: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        )
        .workspaceHeader(actions: headerActions)
        .onAppear { session.pageOwnsKeys = true }
        .onDisappear { session.pageOwnsKeys = false }
        .onChange(of: showsOptions) { _, shown in
            session.pageOwnsKeys = !shown
        }
        .sheet(isPresented: $showsOptions) {
            // macOS 的 sheet 不会带上工作台的语言环境，不补上就会落回系统语言。
            ClipboardHistoryOptions(session: session)
                .appChrome()
        }
    }

    private var headerActions: [WorkspaceHeaderAction] {
        [
            WorkspaceHeaderAction(id: "clipboard.record", title: session.recording ? "clipboard.pause" : "clipboard.resume",
                                  systemImage: session.recording ? "pause" : "play") { session.setRecording(!session.recording) },
            WorkspaceHeaderAction(id: "clipboard.panel", title: "clipboard.showPanel", systemImage: "macwindow") {
                ClipboardHistoryPanel.shared.toggle()
            },
            WorkspaceHeaderAction(id: "clipboard.options", title: "clipboard.options", systemImage: "gearshape", overflowOnly: true) {
                showsOptions = true
            },
            WorkspaceHeaderAction(id: "clipboard.clear", title: "clipboard.clearUnpinned", systemImage: "trash", overflowOnly: true) {
                session.clear(includingPinned: false)
            },
            WorkspaceHeaderAction(id: "clipboard.clearAll", title: "clipboard.clearAll", systemImage: "trash", role: .destructive, overflowOnly: true) {
                session.clear(includingPinned: true)
            }
        ]
    }
}

// MARK: - 卡片网格视图单元（值传递选中态 + 单手势零延迟点击）

struct ClipboardGridCardView: View {
    let item: ClipboardHistoryRecord
    let index: Int
    let isSelected: Bool
    let query: String
    let searchMode: ClipboardSearchMode
    let session: ClipboardHistorySession
    var commitsOnClick: Bool
    var onCommit: (UUID, Bool, Bool) -> Void

    @Environment(\.locale) private var locale
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            cardHeader
            cardStage
            cardFooter
        }
        .daybookSurface(.card, isHovered: isHovered, isSelected: isSelected) { config in
            config.padding = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { handleItemClick() }
        .clipboardCommandPreview(item: item, session: session, onCommit: onCommit)
        .clipboardContextMenu(item: item, session: session, onCommit: onCommit)
    }

    private func handleItemClick() {
        let clickCount = NSApp.currentEvent?.clickCount ?? 1
        if session.selectedID != item.id { session.selectedID = item.id }
        if clickCount >= 2 {
            onCommit(item.id, session.plainByDefault, false)
        } else if commitsOnClick {
            onCommit(item.id, session.plainByDefault, session.clickAction == .paste)
        }
    }

    private var cardHeader: some View {
        HStack(spacing: DaybookSpacing.xs) {
            badgeView
            if !item.sourceBundleID.isEmpty {
                Text(verbatim: BundleDisplay.name(for: item.sourceBundleID))
                    .font(DaybookType.caption.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isHovered || item.isPinned {
                HStack(spacing: 2) {
                    DaybookIconButton(systemName: "doc.on.doc", label: "clipboard.copy", size: .inline) {
                        onCommit(item.id, false, false)
                    }
                    DaybookIconButton(
                        systemName: item.isPinned ? "pin.fill" : "pin",
                        label: item.isPinned ? "clipboard.unpin" : "clipboard.pin",
                        size: .inline,
                        isActive: item.isPinned
                    ) { session.togglePin(item.id) }
                }
            }
        }
    }

    @ViewBuilder
    private var badgeView: some View {
        if let pinKey = item.pinKey {
            Text(verbatim: pinKey.uppercased())
                .font(DaybookType.badge.weight(.semibold))
                .foregroundStyle(DaybookPalette.accent.base)
        } else if index < 9 {
            Text(verbatim: "\(index + 1)")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
        }
    }

    @ViewBuilder
    private var cardStage: some View {
        if let thumb = session.thumbnailImage(for: item, maxPixelSize: 320) {
            ZStack {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous).fill(DaybookPalette.fill.subtle)
                Image(nsImage: thumb).resizable().scaledToFit().padding(DaybookSpacing.xxs)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        } else {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous).fill(DaybookPalette.fill.subtle)
                ClipboardItemFormatting.highlightedText(
                    ClipboardItemFormatting.rowTitle(for: item, locale: locale),
                    query: query,
                    mode: searchMode
                )
                .font(DaybookType.caption)
                .lineLimit(5)
                .padding(DaybookSpacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 116)
        }
    }

    private var cardFooter: some View {
        HStack(spacing: DaybookSpacing.xs) {
            Text(verbatim: ClipboardItemFormatting.contentSpecSummary(for: item, session: session, locale: locale))
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(verbatim: ClipboardItemFormatting.timestampString(for: item.copiedAt))
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
                .lineLimit(1)
        }
    }
}
