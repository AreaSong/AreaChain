import AppKit
import SwiftUI

struct ClipboardHistoryBrowser: View {
    @Bindable var session: ClipboardHistorySession
    var showsFooter: Bool
    var commitsOnClick: Bool
    var onCommit: (UUID, Bool, Bool) -> Void

    @State private var searchFocus = false

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
                placeholder: String(localized: "clipboard.search"),
                focus: $searchFocus,
                onSubmit: {
                    if let item = session.selectedOrFirst() {
                        onCommit(item.id, false, false)
                    }
                },
                allowsShiftNewline: false,
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
        if session.contentsHidden {
            DaybookEmptyState(title: "clipboard.locked", subtitle: "clipboard.locked.help", systemImage: "lock")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if !session.recording && session.items.isEmpty {
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
            if index < 9 {
                Text("\(index + 1)")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.tertiary)
                    .frame(width: DaybookSpacing.lg, alignment: .center)
            } else {
                Color.clear.frame(width: DaybookSpacing.lg)
            }
            thumbnail(item)
            VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
                Text(item.preview.isEmpty ? String(localized: "clipboard.image") : item.preview)
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.primary)
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
                onCommit(item.id, false, false)
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
