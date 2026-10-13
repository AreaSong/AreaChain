import AppKit
import SwiftUI

enum ClipboardItemFormatting {
    @MainActor
    static func title(for item: ClipboardHistoryRecord, session: ClipboardHistorySession, locale: Locale) -> String {
        if !item.preview.isEmpty { return item.preview }
        if !item.filePaths.isEmpty {
            return item.filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        }
        let imageLabel = L10n.string("clipboard.image", locale: locale)
        if let meta = session.imageMetadata(for: item) {
            return "\(imageLabel) · \(meta.dimensionsLabel) · \(meta.byteCountLabel)"
        }
        return imageLabel
    }

    @MainActor
    static func rowTitle(for item: ClipboardHistoryRecord, locale: Locale) -> String {
        if !item.preview.isEmpty { return item.preview }
        if !item.filePaths.isEmpty {
            return item.filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
        }
        let imageLabel = L10n.string("clipboard.image", locale: locale)
        if !item.sourceBundleID.isEmpty {
            return "\(imageLabel) · \(BundleDisplay.name(for: item.sourceBundleID))"
        }
        return imageLabel
    }

    @MainActor
    static func rowSubtitle(for item: ClipboardHistoryRecord, session: ClipboardHistorySession, locale: Locale) -> String {
        if item.imageFile != nil, item.preview.isEmpty, item.filePaths.isEmpty {
            if let meta = session.imageMetadata(for: item) {
                return "\(meta.dimensionsLabel) · \(meta.byteCountLabel) · PNG"
            }
            return "PNG"
        }
        var parts: [String] = []
        if !item.sourceBundleID.isEmpty {
            parts.append(BundleDisplay.name(for: item.sourceBundleID))
        }
        let spec = contentSpecSummary(for: item, session: session, locale: locale)
        if !spec.isEmpty { parts.append(spec) }
        return parts.joined(separator: " · ")
    }

    @MainActor
    static func contentSpecSummary(for item: ClipboardHistoryRecord, session: ClipboardHistorySession, locale: Locale) -> String {
        if let meta = session.imageMetadata(for: item) {
            return "\(meta.dimensionsLabel) · \(meta.byteCountLabel)"
        }
        if !item.filePaths.isEmpty {
            return L10n.format("clipboard.meta.files", locale: locale, item.filePaths.count)
        }
        if !item.plainText.isEmpty {
            if item.lineCount > 1 {
                return L10n.format("clipboard.meta.charsLines", locale: locale, item.characterCount, item.lineCount)
            }
            return L10n.format("clipboard.meta.chars", locale: locale, item.characterCount)
        }
        return ""
    }

    @MainActor
    static func metadataLine(for item: ClipboardHistoryRecord, session: ClipboardHistorySession, locale: Locale) -> String {
        var parts: [String] = []
        if !item.sourceBundleID.isEmpty {
            parts.append(BundleDisplay.name(for: item.sourceBundleID))
        }
        let spec = contentSpecSummary(for: item, session: session, locale: locale)
        if !spec.isEmpty { parts.append(spec) }
        parts.append(timestampString(for: item.copiedAt))
        return parts.joined(separator: " · ")
    }

    static func formatBadges(for item: ClipboardHistoryRecord) -> [String] {
        var badges: [String] = []
        if item.imageFile != nil { badges.append("PNG") }
        if !item.filePaths.isEmpty { badges.append("FILE") }
        if let html = item.html, !html.isEmpty { badges.append("HTML") }
        if let rtf = item.rtf, !rtf.isEmpty { badges.append("RTF") }
        if !item.plainText.isEmpty { badges.append("UTF-8") }
        return badges
    }

    static func timestampString(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func detailedTimestampString(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    static func highlightedText(_ source: String, query: String, mode: ClipboardSearchMode) -> Text {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Text(verbatim: source).foregroundStyle(DaybookPalette.text.primary)
        }
        let ranges = ClipboardHistoryRules.highlightRanges(in: source, needle: query, mode: mode)
        guard !ranges.isEmpty else {
            return Text(verbatim: source).foregroundStyle(DaybookPalette.text.primary)
        }
        var attributed = AttributedString(source)
        attributed.foregroundColor = DaybookPalette.text.primary
        for range in ranges {
            guard let start = AttributedString.Index(range.lowerBound, within: attributed),
                  let end = AttributedString.Index(range.upperBound, within: attributed) else { continue }
            attributed[start..<end].foregroundColor = DaybookPalette.accent.base
        }
        return Text(attributed)
    }

    @MainActor
    static func highlightedText(_ source: String, session: ClipboardHistorySession) -> Text {
        highlightedText(source, query: session.query, mode: session.searchMode)
    }
}

// MARK: - 按住 ⌘ Command + 鼠标悬停才触发的独立浮层预览（零布局抖动）

private struct ClipboardCommandPreviewModifier: ViewModifier {
    let item: ClipboardHistoryRecord
    let session: ClipboardHistorySession
    let arrowEdge: Edge
    let onCommit: (UUID, Bool, Bool) -> Void

    @State private var isHovering = false
    @State private var monitor = DashboardCommandKeyMonitor.shared

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if isHovering != hovering { isHovering = hovering }
            }
            .background {
                if isHovering && monitor.isCommandPressed {
                    Color.clear
                        .popover(
                            isPresented: Binding(
                                get: { isHovering && monitor.isCommandPressed },
                                set: { if !$0 { isHovering = false } }
                            ),
                            arrowEdge: arrowEdge
                        ) {
                            ClipboardCommandPreviewPopover(item: item, session: session, onCommit: onCommit)
                        }
                }
            }
    }
}

extension View {
    func clipboardCommandPreview(
        item: ClipboardHistoryRecord,
        session: ClipboardHistorySession,
        arrowEdge: Edge = .bottom,
        onCommit: @escaping (UUID, Bool, Bool) -> Void
    ) -> some View {
        modifier(ClipboardCommandPreviewModifier(item: item, session: session, arrowEdge: arrowEdge, onCommit: onCommit))
    }
}

struct ClipboardCommandPreviewPopover: View {
    let item: ClipboardHistoryRecord
    let session: ClipboardHistorySession
    var onCommit: (UUID, Bool, Bool) -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            header
            DaybookDivider()
            contentBody
        }
        .padding(DaybookSpacing.md)
        .frame(width: 400, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: DaybookSpacing.xs) {
            Image(systemName: iconName)
                .font(DaybookType.subtitle.weight(.semibold))
                .foregroundStyle(DaybookPalette.accent.base)
            Text(verbatim: ClipboardItemFormatting.metadataLine(for: item, session: session, locale: locale))
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(1)
            Spacer(minLength: DaybookSpacing.xs)
            Button("clipboard.copy") { onCommit(item.id, false, false) }
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
            Button("clipboard.paste") { onCommit(item.id, false, true) }
                .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if let image = session.cachedFullImage(for: item) ?? session.thumbnailImage(for: item, maxPixelSize: 480) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 280)
                .padding(DaybookSpacing.xs)
                .background(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous).fill(DaybookPalette.fill.subtle))
        }
        if !item.plainText.isEmpty {
            ScrollView {
                ClipboardItemFormatting.highlightedText(item.plainText, session: session)
                    .font(DaybookType.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)
            .daybookScroll()
        }
        if !item.filePaths.isEmpty {
            VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
                ForEach(item.filePaths, id: \.self) { path in
                    Text(verbatim: path)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var iconName: String {
        switch item.kind {
        case .image: "photo"
        case .file: "doc.on.doc"
        case .text: "text.alignleft"
        }
    }
}

// MARK: - 双栏主从视图：右侧常驻详情面板（全高自适应画布 + 底部结构化元数据栏）

struct ClipboardSplitDetailPane: View {
    let item: ClipboardHistoryRecord?
    let query: String
    let searchMode: ClipboardSearchMode
    let session: ClipboardHistorySession
    var onCommit: (UUID, Bool, Bool) -> Void

    @Environment(\.locale) private var locale
    @State private var asyncFullImage: NSImage?
    @State private var loadedImageFile: String?
    @State private var zoomActualSize = false

    var body: some View {
        Group {
            if let item {
                detailContent(for: item)
            } else {
                DaybookEmptyState(title: "clipboard.empty", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .daybookSurface(.card) { config in
            config.padding = EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 14)
        }
        .task(id: item?.imageFile) {
            await loadHighResImageIfNeeded()
        }
    }

    private func loadHighResImageIfNeeded() async {
        guard let item, let imageFile = item.imageFile else {
            asyncFullImage = nil
            loadedImageFile = nil
            return
        }
        if let cached = session.cachedFullImage(for: item) {
            asyncFullImage = cached
            loadedImageFile = imageFile
            return
        }
        let decoded = await session.loadFullImageAsync(for: item)
        if !Task.isCancelled {
            asyncFullImage = decoded
            loadedImageFile = imageFile
        }
    }

    private func detailContent(for item: ClipboardHistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            detailHeader(for: item)
            DaybookDivider()
            detailStage(for: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            DaybookDivider()
            detailMetadataFooter(for: item)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailHeader(for item: ClipboardHistoryRecord) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            sourceAppHeaderLabel(for: item)
            Spacer(minLength: DaybookSpacing.xs)
            if item.imageFile != nil {
                Button(zoomActualSize ? "clipboard.zoom.actual" : "clipboard.zoom.fit") {
                    zoomActualSize.toggle()
                }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
            Button("clipboard.copy") { onCommit(item.id, false, false) }
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
            Button("clipboard.paste") { onCommit(item.id, false, true) }
                .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
            if !item.plainText.isEmpty {
                Button("clipboard.pastePlain") { onCommit(item.id, true, true) }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
            DaybookIconButton(
                systemName: item.isPinned ? "pin.fill" : "pin",
                label: item.isPinned ? "clipboard.unpin" : "clipboard.pin",
                size: .compact,
                isActive: item.isPinned
            ) { session.togglePin(item.id) }
            DaybookIconButton(systemName: "trash", label: "clipboard.delete", size: .compact, role: .destructive) {
                session.delete(item.id)
            }
        }
    }

    private func sourceAppHeaderLabel(for item: ClipboardHistoryRecord) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            if let icon = BundleDisplay.icon(for: item.sourceBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(verbatim: ClipboardItemFormatting.rowTitle(for: item, locale: locale))
                .font(DaybookType.subtitle.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(1)
            if let pinKey = item.pinKey {
                Text(verbatim: "⌥P · \(pinKey.uppercased())")
                    .font(DaybookType.badge.weight(.semibold))
                    .foregroundStyle(DaybookPalette.accent.base)
                    .padding(.horizontal, DaybookSpacing.xs)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous).fill(DaybookPalette.accent.fill))
            }
        }
    }

    @ViewBuilder
    private func detailStage(for item: ClipboardHistoryRecord) -> some View {
        if item.imageFile != nil, item.plainText.isEmpty, item.filePaths.isEmpty {
            pureImageStage(for: item)
        } else {
            scrollableCompositeStage(for: item)
        }
    }

    @ViewBuilder
    private func pureImageStage(for item: ClipboardHistoryRecord) -> some View {
        let displayImage = resolvedImage(for: item)
        ZStack {
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
            if let displayImage {
                if zoomActualSize {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: displayImage)
                            .padding(DaybookSpacing.sm)
                    }
                    .daybookScroll()
                } else {
                    Image(nsImage: displayImage)
                        .resizable()
                        .scaledToFit()
                        .padding(DaybookSpacing.sm)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.8)
        )
    }

    private func scrollableCompositeStage(for item: ClipboardHistoryRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                if let displayImage = resolvedImage(for: item) {
                    Image(nsImage: displayImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 360)
                        .padding(DaybookSpacing.sm)
                }
                if !item.plainText.isEmpty {
                    ClipboardItemFormatting.highlightedText(item.plainText, query: query, mode: searchMode)
                        .font(DaybookType.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DaybookSpacing.sm)
                }
                if !item.filePaths.isEmpty {
                    fileListSection(paths: item.filePaths)
                        .padding(DaybookSpacing.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous).fill(DaybookPalette.fill.subtle))
        .daybookScroll()
    }

    private func resolvedImage(for item: ClipboardHistoryRecord) -> NSImage? {
        if loadedImageFile == item.imageFile, let asyncFullImage { return asyncFullImage }
        if let cached = session.cachedFullImage(for: item) { return cached }
        return session.thumbnailImage(for: item, maxPixelSize: 320)
    }

    private func detailMetadataFooter(for item: ClipboardHistoryRecord) -> some View {
        let spec = ClipboardItemFormatting.contentSpecSummary(for: item, session: session, locale: locale)
        let badges = ClipboardItemFormatting.formatBadges(for: item)
        return HStack(spacing: DaybookSpacing.sm) {
            if !item.sourceBundleID.isEmpty {
                Label(BundleDisplay.name(for: item.sourceBundleID), systemImage: "app.badge")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(1)
            }
            if !spec.isEmpty {
                Text(verbatim: spec)
                    .font(DaybookType.caption.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(1)
            }
            Text(verbatim: ClipboardItemFormatting.detailedTimestampString(for: item.copiedAt))
                .font(DaybookType.caption.monospacedDigit())
                .foregroundStyle(DaybookPalette.text.tertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: DaybookSpacing.xxs) {
                ForEach(badges, id: \.self) { badge in
                    Text(verbatim: badge)
                        .font(DaybookType.badge.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous).fill(DaybookPalette.fill.subtle))
                }
            }
        }
    }

    private func fileListSection(paths: [String]) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            ForEach(paths, id: \.self) { path in
                HStack(spacing: DaybookSpacing.xs) {
                    Image(systemName: "doc")
                        .font(DaybookType.body)
                        .foregroundStyle(DaybookPalette.accent.base)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: URL(fileURLWithPath: path).lastPathComponent)
                            .font(DaybookType.body.weight(.medium))
                            .foregroundStyle(DaybookPalette.text.primary)
                        Text(verbatim: path)
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookPalette.text.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(DaybookSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
