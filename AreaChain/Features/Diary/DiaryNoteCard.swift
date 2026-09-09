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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    var entry: DiaryEntry
    var activeTags: [TagItem]
    var attachments: [AttachmentItem]
    var onDelete: () -> Void
    var isHighlighted: Bool = false

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editDraft = ""
    @State private var isMasked = true
    @State private var hasCopied = false

    private var isPasswordType: Bool {
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
            HStack(alignment: .center, spacing: 6) {
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DaybookTheme.stamp)
                }

                Text(formatDate(entry.createdAt))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(DaybookTheme.muted)

                if isPasswordType {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 9))
                        Text("diary.privacy")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.red.opacity(0.10)))
                }

                Spacer()

                actionButtons
            }

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
    private var contentView: some View {
        if isEditing {
            VStack(alignment: .trailing, spacing: 6) {
                TextEditor(text: $editDraft)
                    .font(.system(size: 13))
                    .frame(minHeight: 50)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DaybookTheme.surface)
                            .stroke(DaybookTheme.focusRing, lineWidth: 1.2)
                    )

                HStack {
                    Button("alert.cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))

                    Button("common.save") {
                        let next = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !next.isEmpty {
                            DayBoardMutations.editDiary(entry, text: next)
                        }
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 11))
                }
            }
        } else if isPasswordType && isMasked {
            HStack(spacing: 8) {
                Text("••••••••••••••••")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(DaybookTheme.muted)
                    .blur(radius: 1.5)

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        isMasked = false
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "eye")
                            .font(.system(size: 10))
                        Text("diary.reveal")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(DaybookTheme.stamp)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        } else {
            Text(entry.text)
                .font(.system(size: 13))
                .lineSpacing(3.5)
                .foregroundStyle(DaybookTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    editDraft = entry.text
                    isEditing = true
                }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 3) {
            if isPasswordType {
                Button(action: copyContent) {
                    HStack(spacing: 2) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .bold))
                        Text(hasCopied ? "diary.copied" : "diary.copy.password")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(hasCopied ? Color.green : DaybookTheme.stamp)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule().fill((hasCopied ? Color.green : DaybookTheme.stamp).opacity(0.14))
                    )
                }
                .buttonStyle(.plain)
                .help("diary.copy.password.help")

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        isMasked.toggle()
                    }
                } label: {
                    Image(systemName: isMasked ? "eye" : "eye.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(isMasked ? "diary.unmask" : "diary.mask")
            } else {
                Button(action: copyContent) {
                    Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(hasCopied ? Color.green : DaybookTheme.muted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("diary.copy")
            }

            Button {
                DayBoardMutations.togglePinDiary(entry)
            } label: {
                Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundStyle(entry.isPinned ? DaybookTheme.stamp : DaybookTheme.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(entry.isPinned ? "diary.unpin" : "diary.pin")

            Button {
                guard !(isPasswordType && isMasked) else { return }
                editDraft = entry.text
                isEditing = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(isPasswordType && isMasked)
            .opacity(isPasswordType && isMasked ? 0.35 : 1)
            .help(isPasswordType && isMasked ? "diary.unmask.first" : "diary.edit.help")

            Button {
                AttachmentActions.pickImage(ownerKind: .diary, ownerID: entry.id, context: modelContext)
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("diary.attach")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.destructive.opacity(0.8))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("alert.trash.move")
        }
        .opacity(isHovered || isPasswordType || entry.isPinned ? 1.0 : 0.0)
    }

    private func copyContent() {
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

    private func formatDate(_ date: Date) -> String {
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
