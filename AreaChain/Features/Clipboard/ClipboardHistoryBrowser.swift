import AppKit
import SwiftUI

struct ClipboardHistoryBrowser: View {
    @Bindable var session: ClipboardHistorySession
    var showsFooter: Bool
    var commitsOnClick: Bool
    var onCommit: (UUID, Bool, Bool) -> Void

    @Environment(\.locale) private var locale
    @State private var searchFocus = false
    @State private var previewID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            searchField
            if let noticeKey = session.noticeKey {
                Text(LocalizedStringKey(noticeKey))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
            if let preview = previewItem {
                previewCard(preview)
            }
            if showsFooter {
                Text("clipboard.footer")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.tertiary)
            }
        }
        .onChange(of: searchFocus) { _, focused in
            session.clipboardFieldFocused = focused
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
                    if session.query.isEmpty == false {
                        session.query = ""
                    }
                }
            )
        } trailing: {
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
        if !session.recording && session.items.isEmpty {
            DaybookEmptyState(title: "clipboard.paused", systemImage: "pause.circle")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if session.visibleItems.isEmpty {
            DaybookEmptyState(
                title: session.query.isEmpty ? "clipboard.empty" : "clipboard.empty.filtered",
                systemImage: "doc.on.clipboard"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                    ForEach(Array(session.visibleItems.enumerated()), id: \.element.id) { index, item in
                        row(item, index: index)
                    }
                }
            }
            .daybookScroll()
        }
    }

    private func row(_ item: ClipboardHistoryRecord, index: Int) -> some View {
        let selected = session.selectedID == item.id
        return HStack(alignment: .center, spacing: DaybookSpacing.sm) {
            if let pinKey = item.pinKey {
                Text(pinKey.uppercased())
                    .font(DaybookType.badge)
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
            thumbnail(item)
            VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
                highlightedPreview(item)
                    .font(DaybookType.body)
                    .lineLimit(2)
                if !item.sourceBundleID.isEmpty {
                    Text(BundleDisplay.name(for: item.sourceBundleID))
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.accent.base)
                    .accessibilityLabel(Text("clipboard.pin"))
            }
        }
        .padding(.horizontal, DaybookSpacing.sm)
        .padding(.vertical, DaybookSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? DaybookPalette.fill.selection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            session.selectedID = item.id
            if commitsOnClick {
                onCommit(item.id, session.plainByDefault, session.clickAction == .paste)
            }
        }
        .onHover { inside in
            guard showsExtendedPreview(item) else { return }
            if inside {
                previewID = item.id
            } else if previewID == item.id {
                previewID = nil
            }
        }
        .contextMenu {
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
            .accessibilityLabel(Text(item.preview.isEmpty ? String(localized: "clipboard.image") : item.preview))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var previewItem: ClipboardHistoryRecord? {
        guard let previewID else { return nil }
        return session.visibleItems.first { $0.id == previewID }
    }

    private func showsExtendedPreview(_ item: ClipboardHistoryRecord) -> Bool {
        item.imageFile != nil || !item.filePaths.isEmpty || item.plainText.count > 180 || item.plainText.contains("\n")
    }

    private func highlightedPreview(_ item: ClipboardHistoryRecord) -> Text {
        let source = item.preview.isEmpty ? String(localized: "clipboard.image") : item.preview
        let ranges = ClipboardHistoryRules.highlightRanges(in: source, needle: session.query, mode: session.searchMode)
        var attributed = AttributedString(source)
        attributed.foregroundColor = DaybookPalette.text.primary
        for range in ranges {
            guard let start = AttributedString.Index(range.lowerBound, within: attributed),
                  let end = AttributedString.Index(range.upperBound, within: attributed) else { continue }
            attributed[start..<end].foregroundColor = DaybookPalette.accent.base
        }
        return Text(attributed)
    }

    private func previewCard(_ item: ClipboardHistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            if let data = session.imageData(for: item), let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 140)
            }
            if !item.plainText.isEmpty {
                Text(item.plainText)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !item.filePaths.isEmpty {
                Text(item.filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: "\n"))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(4)
            }
        }
        .padding(DaybookSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DaybookPalette.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func thumbnail(_ item: ClipboardHistoryRecord) -> some View {
        if let data = session.imageData(for: item), let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous))
        }
    }
}
