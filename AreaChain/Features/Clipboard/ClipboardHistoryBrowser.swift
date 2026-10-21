import AppKit
import SwiftUI

struct ClipboardHistoryBrowser: View {
    @Bindable var session: ClipboardHistorySession
    var showsFooter: Bool
    var commitsOnClick: Bool
    var onCommit: (UUID, Bool, Bool) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.workspaceEmbedded) private var workspaceEmbedded
    @State private var searchFocus = false

    private var effectiveViewMode: ClipboardViewMode {
        workspaceEmbedded ? session.viewMode : .list
    }

    private var footerLocalizationKey: LocalizedStringKey {
        workspaceEmbedded ? "clipboard.footer.workspace" : "clipboard.footer"
    }

    private var hasFilterBar: Bool {
        !session.items.isEmpty || session.contentFilter != .all
    }

    var body: some View {
        let rows = session.visibleItems
        let activeID = session.selectedID ?? rows.first?.id
        let currentQuery = session.query
        let currentMode = session.searchMode

        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            searchField
            if workspaceEmbedded {
                controlBarRow
            }
            if let noticeKey = session.noticeKey {
                Text(LocalizedStringKey(noticeKey))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content(rows: rows, activeID: activeID, query: currentQuery, searchMode: currentMode)
            if showsFooter {
                Text(footerLocalizationKey)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
                    .lineLimit(1)
            }
        }
        .onChange(of: searchFocus) { _, focused in
            session.clipboardFieldFocused = focused
        }
    }

    private var controlBarRow: some View {
        HStack(spacing: DaybookSpacing.sm) {
            if hasFilterBar {
                ScrollView(.horizontal, showsIndicators: false) {
                    filterChipsBar
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
            searchModeMenu
            viewModePicker
        }
    }

    private var searchField: some View {
        DaybookInputShell(kind: .search, focused: searchFocus) {
            Image(systemName: "magnifyingglass")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.tertiary)
        } field: {
            DaybookTextField(
                text: $session.query,
                placeholder: L10n.string("clipboard.search", locale: locale),
                focus: $searchFocus,
                onSubmit: {
                    if let item = session.selectedOrFirst() {
                        onCommit(item.id, session.plainByDefault, false)
                    }
                },
                allowsShiftNewline: false,
                newlinePolicy: .verbatim,
                onEscape: {
                    if !session.query.isEmpty { session.query = "" }
                }
            )
        } trailing: {
            EmptyView()
        }
    }

    private var searchModeMenu: some View {
        Menu {
            ForEach(ClipboardSearchMode.allCases, id: \.self) { mode in
                Button {
                    session.setSearchMode(mode)
                } label: {
                    HStack {
                        Text(LocalizedStringKey(searchModeKey(for: mode)))
                        if session.searchMode == mode { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: DaybookSpacing.xxs) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(DaybookType.caption)
                Text(LocalizedStringKey(searchModeKey(for: session.searchMode)))
                    .font(DaybookType.caption.weight(.medium))
            }
            .daybookMenuLabel(size: .compact)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var viewModePicker: some View {
        let binding = Binding<ClipboardViewMode>(
            get: { session.viewMode },
            set: { session.setViewMode($0) }
        )
        return DaybookSegmentedControl(
            selection: binding,
            options: [
                DaybookSegmentOption(.split, "clipboard.viewMode.split"),
                DaybookSegmentOption(.grid, "clipboard.viewMode.grid"),
                DaybookSegmentOption(.list, "clipboard.viewMode.list")
            ]
        )
        .fixedSize()
    }

    private var filterChipsBar: some View {
        let counts = session.filterCounts
        return HStack(spacing: DaybookSpacing.xs) {
            ForEach(ClipboardContentFilter.allCases, id: \.self) { filter in
                let isSelected = session.contentFilter == filter
                let count = counts[filter] ?? 0
                Button {
                    session.setContentFilter(filter)
                } label: {
                    HStack(spacing: DaybookSpacing.xxs) {
                        Text(LocalizedStringKey(titleKey(for: filter)))
                        Text(verbatim: "\(count)")
                            .font(DaybookType.badge)
                            .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
                    }
                }
                .buttonStyle(DaybookButtonStyle(isSelected ? .pill(tint: DaybookPalette.accent.base) : .subtle, size: .compact))
            }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func content(rows: [ClipboardHistoryRecord], activeID: UUID?, query: String, searchMode: ClipboardSearchMode) -> some View {
        if !session.recording && session.items.isEmpty {
            DaybookEmptyState(title: "clipboard.paused", systemImage: "pause.circle")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if rows.isEmpty {
            let isFiltered = !query.isEmpty || session.contentFilter != .all
            DaybookEmptyState(title: isFiltered ? "clipboard.empty.filtered" : "clipboard.empty", systemImage: "doc.on.clipboard")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            switch effectiveViewMode {
            case .split:
                splitContentView(rows: rows, activeID: activeID, query: query, searchMode: searchMode)
            case .grid:
                gridContentView(rows: rows, activeID: activeID, query: query, searchMode: searchMode)
            case .list:
                listScrollView(rows: rows, activeID: activeID, query: query, searchMode: searchMode, arrowEdge: .bottom)
            }
        }
    }

    private func splitContentView(rows: [ClipboardHistoryRecord], activeID: UUID?, query: String, searchMode: ClipboardSearchMode) -> some View {
        let activeItem = rows.first(where: { $0.id == activeID }) ?? rows.first
        return GeometryReader { proxy in
            if proxy.size.width >= 520 {
                let leftWidth = min(max(proxy.size.width * 0.38, 270), 380)
                HStack(alignment: .top, spacing: DaybookSpacing.md) {
                    listScrollView(rows: rows, activeID: activeItem?.id, query: query, searchMode: searchMode, arrowEdge: .trailing)
                        .frame(width: leftWidth)
                        .frame(maxHeight: .infinity)
                    ClipboardSplitDetailPane(item: activeItem, query: query, searchMode: searchMode, session: session, onCommit: onCommit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            } else {
                listScrollView(rows: rows, activeID: activeItem?.id, query: query, searchMode: searchMode, arrowEdge: .bottom)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gridContentView(rows: [ClipboardHistoryRecord], activeID: UUID?, query: String, searchMode: ClipboardSearchMode) -> some View {
        let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: DaybookSpacing.sm, alignment: .top)]
        return ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: DaybookSpacing.sm) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                    ClipboardGridCardView(
                        item: item, index: index, isSelected: activeID == item.id,
                        query: query, searchMode: searchMode, session: session,
                        commitsOnClick: commitsOnClick, onCommit: onCommit
                    )
                }
            }
            .padding(.vertical, DaybookSpacing.xxs)
        }
        .daybookScroll()
    }

    private func listScrollView(
        rows: [ClipboardHistoryRecord], activeID: UUID?, query: String, searchMode: ClipboardSearchMode, arrowEdge: Edge
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                    ClipboardHistoryRowView(
                        item: item, index: index, isSelected: activeID == item.id,
                        query: query, searchMode: searchMode, session: session,
                        commitsOnClick: commitsOnClick, previewArrowEdge: arrowEdge, onCommit: onCommit
                    )
                }
            }
        }
        .daybookScroll()
    }

    private func titleKey(for filter: ClipboardContentFilter) -> String {
        switch filter {
        case .all: "clipboard.filter.all"
        case .text: "clipboard.filter.text"
        case .image: "clipboard.filter.image"
        case .file: "clipboard.filter.file"
        case .pinned: "clipboard.filter.pinned"
        }
    }

    private func searchModeKey(for mode: ClipboardSearchMode) -> String {
        switch mode {
        case .mixed: "clipboard.searchMode.mixed"
        case .exact: "clipboard.searchMode.exact"
        case .regex: "clipboard.searchMode.regex"
        }
    }
}

// MARK: - 剪切板列表行（值传递选中态 + 16:10 宽幅缩略图 + 单手势零延迟点击）

private struct ClipboardHistoryRowView: View {
    let item: ClipboardHistoryRecord
    let index: Int
    let isSelected: Bool
    let query: String
    let searchMode: ClipboardSearchMode
    let session: ClipboardHistorySession
    var commitsOnClick: Bool
    var previewArrowEdge: Edge
    var onCommit: (UUID, Bool, Bool) -> Void

    @Environment(\.locale) private var locale
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: DaybookSpacing.sm) {
            indexBadge
            leadingVisual
            textColumn
            Spacer(minLength: 0)
            trailingAccessory
        }
        .padding(.horizontal, DaybookSpacing.sm)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { handleRowClick() }
        .clipboardCommandPreview(item: item, session: session, arrowEdge: previewArrowEdge, onCommit: onCommit)
        .clipboardContextMenu(item: item, session: session, onCommit: onCommit)
        .accessibilityLabel(Text(verbatim: ClipboardItemFormatting.title(for: item, session: session, locale: locale)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func handleRowClick() {
        let clickCount = PointerClickCount.current()
        if session.selectedID != item.id { session.selectedID = item.id }
        if clickCount >= 2 {
            onCommit(item.id, session.plainByDefault, false)
        } else if commitsOnClick {
            onCommit(item.id, session.plainByDefault, session.clickAction == .paste)
        }
    }

    private var rowBackground: Color {
        if isSelected { return DaybookPalette.fill.selection }
        if isHovered { return DaybookPalette.fill.hover }
        return Color.clear
    }

    @ViewBuilder
    private var indexBadge: some View {
        if let pinKey = item.pinKey {
            Text(pinKey.uppercased())
                .font(DaybookType.badge.weight(.semibold))
                .foregroundStyle(DaybookPalette.accent.base)
                .frame(width: DaybookSpacing.lg, alignment: .center)
                .accessibilityLabel(Text(pinKey.uppercased()))
        } else if index < 9 {
            Text("\(index + 1)")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.tertiary)
                .frame(width: DaybookSpacing.lg, alignment: .center)
        } else {
            Color.clear.frame(width: DaybookSpacing.lg)
        }
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if let thumb = session.thumbnailImage(for: item, maxPixelSize: 120) {
            Image(nsImage: thumb)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 38)
                .background(DaybookPalette.fill.subtle)
                .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                        .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.6)
                )
        } else if !item.filePaths.isEmpty {
            Image(systemName: "doc.on.doc")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.accent.base)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous).fill(DaybookPalette.fill.subtle))
        }
    }

    private var textColumn: some View {
        let titleText = ClipboardItemFormatting.rowTitle(for: item, locale: locale)
        let isPureImage = item.imageFile != nil && item.preview.isEmpty
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.xs) {
                ClipboardItemFormatting.highlightedText(titleText, query: query, mode: searchMode)
                    .font(isPureImage ? DaybookType.body.weight(.medium) : DaybookType.body)
                    .lineLimit(isPureImage ? 1 : 2)
                Spacer(minLength: 0)
                if !isHovered {
                    Text(verbatim: ClipboardItemFormatting.timestampString(for: item.copiedAt))
                        .font(DaybookType.badge.monospacedDigit())
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .lineLimit(1)
                }
            }
            HStack(spacing: 4) {
                if let icon = BundleDisplay.icon(for: item.sourceBundleID) {
                    Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                }
                Text(verbatim: ClipboardItemFormatting.rowSubtitle(for: item, session: session, locale: locale))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if isHovered {
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
                DaybookIconButton(systemName: "trash", label: "clipboard.delete", size: .inline, role: .destructive) {
                    session.delete(item.id)
                }
            }
        } else if item.isPinned {
            Image(systemName: "pin.fill")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.accent.base)
                .accessibilityLabel(Text("clipboard.pin"))
        }
    }
}

extension View {
    func clipboardContextMenu(
        item: ClipboardHistoryRecord,
        session: ClipboardHistorySession,
        onCommit: @escaping (UUID, Bool, Bool) -> Void
    ) -> some View {
        contextMenu {
            Button("clipboard.copy") { onCommit(item.id, false, false) }
            Button("clipboard.paste") { onCommit(item.id, false, true) }
            Button("clipboard.pastePlain") { onCommit(item.id, true, true) }
            Button(item.isPinned ? "clipboard.unpin" : "clipboard.pin") { session.togglePin(item.id) }
            if !item.sourceBundleID.isEmpty {
                Button("clipboard.ignoreApp") { session.ignoreApp(item.sourceBundleID) }
            }
            Divider()
            Button("clipboard.delete", role: .destructive) { session.delete(item.id) }
        }
    }
}
