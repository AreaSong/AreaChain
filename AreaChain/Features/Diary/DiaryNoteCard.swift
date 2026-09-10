import AppKit
import SwiftData
import SwiftUI

enum DiaryTagChrome {
    static func color(for name: String) -> Color {
        if DiaryMemoTags.isPasswordName(name) { return .red }
        if name == DiaryMemoTags.idea { return .orange }
        if name == DiaryMemoTags.journal { return .blue }
        return DaybookTheme.stamp
    }
}

/// 灵感手记卡片：隐私遮罩、复制、置顶、就地编辑，以及「密码 / 小巧思 / 日记」打标。
struct DiaryNoteCard: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) var locale
    var entry: DiaryEntry
    var activeTags: [TagItem]
    var attachments: [AttachmentItem]
    var onDelete: () -> Void
    var isHighlighted: Bool = false

    @State var isHovered = false
    @State var isEditing = false
    @State var editDraft = ""
    @State var isMasked = true
    @State var hasCopied = false

    var isPasswordType: Bool {
        let hasPasswordTag = activeTags.contains { tag in
            DiaryMemoTags.isPasswordName(tag.name) && TagIDList.contains(entry.tagIDs, tag.id)
        }
        return hasPasswordTag || entry.text.contains("#\(DiaryMemoTags.password)")
    }

    private var presetTags: [TagItem] {
        DiaryMemoTags.presets.compactMap { name in
            activeTags.first { $0.name == name }
        }
    }

    private var extraAssignedTags: [TagItem] {
        activeTags.filter { tag in
            !DiaryMemoTags.isPresetName(tag.name) && TagIDList.contains(entry.tagIDs, tag.id)
        }
    }

    private var addableTags: [TagItem] {
        activeTags.filter { tag in
            !DiaryMemoTags.isPresetName(tag.name) && !TagIDList.contains(entry.tagIDs, tag.id)
        }
    }

    private var noteAttachments: [AttachmentRef] {
        CatalogChoices.attachments(entry.id, in: attachments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeaderView

            contentView

            if !noteAttachments.isEmpty, !(isPasswordType && isMasked && !isEditing) {
                AttachmentThumbnails(items: noteAttachments)
                    .padding(.top, 2)
            }

            tagRow
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(isHovered ? DaybookTheme.cardSurfaceHover : DaybookTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(
                    isHighlighted
                        ? DaybookTheme.stamp
                        : (entry.isPinned ? DaybookTheme.stamp.opacity(0.35) : (isHovered ? DaybookTheme.cardBorderHover : DaybookTheme.cardBorder)),
                    lineWidth: isHighlighted || entry.isPinned ? 1.2 : 0.8
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var tagRow: some View {
        HStack(spacing: 5) {
            ForEach(presetTags) { tag in
                tagToggleChip(tag, assigned: TagIDList.contains(entry.tagIDs, tag.id))
            }
            ForEach(extraAssignedTags) { tag in
                tagToggleChip(tag, assigned: true)
            }
            if !addableTags.isEmpty {
                Menu {
                    ForEach(addableTags) { tag in
                        Button("#\(tag.name)") {
                            DayBoardMutations.toggleDiaryTag(entry, tagID: tag.id)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DaybookTheme.muted)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(DaybookTheme.hoverFill))
                }
                .menuStyle(.borderlessButton)
                .help("diary.tag.add")
            }
        }
        .padding(.top, 2)
    }

    private func tagToggleChip(_ tag: TagItem, assigned: Bool) -> some View {
        let color = DiaryTagChrome.color(for: tag.name)
        return Button {
            DayBoardMutations.toggleDiaryTag(entry, tagID: tag.id)
        } label: {
            Text("#\(tag.name)")
                .font(.system(size: 10.5, weight: assigned ? .semibold : .medium))
                .foregroundStyle(assigned ? color : DaybookTheme.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(assigned ? color.opacity(0.12) : DaybookTheme.hoverFill)
                )
                .overlay(
                    Capsule().strokeBorder(assigned ? color.opacity(0.4) : DaybookTheme.cardBorder, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .help(assigned ? "diary.tag.off" : "diary.tag.on")
    }

    @ViewBuilder
    var contentView: some View {
        if isEditing {
            editingContentView
        } else if isPasswordType && isMasked {
            maskedPasswordContentView
        } else {
            readOnlyTextView
        }
    }

    var actionButtons: some View {
        HStack(spacing: 3) {
            copyAndMaskButtons
            managementActionButtons
        }
        .opacity(isHovered || isPasswordType || entry.isPinned ? 1.0 : 0.0)
    }

    func copyContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        withAnimation(.snappy) {
            hasCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.snappy) {
                hasCopied = false
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: date)
        if Calendar.current.isDateInToday(date) {
            return L10n.format("diary.date.today", locale: locale, time)
        }
        if Calendar.current.isDateInYesterday(date) {
            return L10n.format("diary.date.yesterday", locale: locale, time)
        }
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
