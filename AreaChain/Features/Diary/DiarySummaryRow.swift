import AppKit
import SwiftData
import SwiftUI

/// 菜单栏只展示有界的正文预览，完整阅读与编辑交给同一条手记的小窗。
struct DiarySummaryRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    var entry: DiaryEntry
    var privacyTags: [TagItem]
    var isHighlighted = false
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
            Button(action: openWindow) {
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
            }
            .buttonStyle(.plain)
            .help("diary.window.open")

            Button(action: openWindow) { Image(systemName: "arrow.up.forward.square").frame(width: 22, height: 24) }
                .buttonStyle(.plain).accessibilityLabel("diary.window.open").help("diary.window.open")
            moreMenu
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .foregroundStyle(DaybookTheme.muted)
        .background(isHighlighted ? DaybookTheme.cardSelectionFill : (isHovered ? DaybookTheme.hoverFill : .clear),
                    in: RoundedRectangle(cornerRadius: DaybookRadius.small))
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
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(entry.text, forType: .string) else {
            MutationFeedback.shared.reportFailure()
            return
        }
        hasCopied = true
    }

    private func attach() {
        AttachmentActions.pickImage(ownerKind: .diary, ownerID: entry.id, context: context, canAttach: {
            guard entry.deletedAt == nil, let tags = try? context.fetch(FetchDescriptor<TagItem>()) else { return false }
            return !DiaryPrivacy.isSensitive(entry.snapshot, tags: tags)
        })
    }
}
