import AppKit
import SwiftData
import SwiftUI

enum DiaryTagChrome {
    static func color(for name: String) -> Color {
        DaybookPalette.diaryPreset(forTagName: name)
    }
}

struct DiaryTagPill: View {
    var name: String

    var body: some View {
        let color = DiaryTagChrome.color(for: name)
        Text("#" + name)
            .font(DaybookType.micro.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                    .fill(color.opacity(0.12)) // token-exempt: 标签色 12% 底不是印章色
            )
            .foregroundStyle(color)
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5) // token-exempt: 标签色 25% 描边没有对应令牌
            )
            .help("#" + name)
    }
}

/// 灵感手记卡片：隐私遮罩、复制、置顶、就地编辑，以及「密码 / 小巧思 / 日记」打标。
struct DiaryNoteCard: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.locale) var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var entry: DiaryEntry
    var activeTags: [TagItem]
    var attachments: [AttachmentItem]
    var onDelete: () -> Void
    var isHighlighted: Bool = false
    var privacyTags: [TagItem]? = nil
    var draftStore: DiaryCardDrafts? = nil
    var vault: PrivacyVault? = nil

    @State private var chrome = BoardRowChrome()
    @State private var localDrafts = DiaryCardDrafts()
    @State var pickingDay = false
    @State var hasConvertedToTask = false
    @State private var hostWindow: NSWindow?
    @State var showsEditConflict = false
    @State var editFocused = false
    @State var isMasked = true
    @State var hasCopied = false
    @State var confirmsUnprotect = false

    var privacyVault: PrivacyVault { vault ?? .shared }
    var drafts: DiaryCardDrafts { draftStore ?? localDrafts }
    var editingSession: DiaryEditorSession? { drafts.editor(for: entry.id) }
    var isEditing: Bool { editingSession != nil }
    var isHovered: Bool { chrome.isRowHovered }
    var showsCommandStrip: Bool { isHovered && chrome.isCommandPressed }

    var isPasswordType: Bool {
        editingSession?.isSensitive == true || DiaryPrivacy.isSensitive(entry.snapshot, tags: privacyTags ?? activeTags)
    }

    var canRevealContent: Bool {
        (editingSession?.canRevealContent ?? (!entry.hasProtectedContent || privacyVault.isUnlocked))
            && DiaryPrivacy.canReveal(isSensitive: isPasswordType, isMasked: isMasked)
    }

    var displayedText: String { (try? DiaryContent.read(entry, vault: privacyVault)) ?? "" }

    private var assignedTags: [TagItem] {
        DiaryMemoTags.ordered(
            activeTags.filter { TagIDList.contains(entry.tagIDs, $0.id) },
            name: { $0.name },
            isActive: { _ in true }
        )
    }

    private var addableTags: [TagItem] {
        DiaryMemoTags.ordered(
            activeTags.filter { !TagIDList.contains(entry.tagIDs, $0.id) },
            name: { $0.name },
            isActive: { _ in true }
        )
    }

    private var noteAttachments: [AttachmentRef] {
        CatalogChoices.attachments(entry.id, in: attachments, ownerKind: .diary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeaderView

            contentView

            if !noteAttachments.isEmpty, canRevealContent {
                AttachmentThumbnails(items: noteAttachments)
                    .padding(.top, 2)
            }

            tagRow
        }
        .padding(12)
        .daybookSurface(.card, isHovered: isHovered, isSelected: isHighlighted)
        .overlay {
            if entry.isPinned && !isHighlighted {
                RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .strokeBorder(DaybookPalette.accent.border, lineWidth: 1.2) // 置顶手记的第三态描边，表面选中态留给高亮
            }
        }
        .onHover { chrome.handleRowHover($0, reduceMotion: reduceMotion) }
        .onAppear { chrome.startCommandMonitor(reduceMotion: reduceMotion) }
        .onDisappear { chrome.stop() }
        .popover(isPresented: $pickingDay) {
            DaySchedulePicker(initialKey: entry.dayKey) { key in
                DayBoardMutations.moveDiary(entry, to: key)
                pickingDay = false
            }
        }
        .background(KeyWindowHost { hostWindow = $0 })
        .alert("diary.window.reload.title", isPresented: $showsEditConflict) {
            Button("diary.window.reload") { reloadEditingDraft() }
            Button("alert.cancel", role: .cancel) {}
        } message: { Text("diary.window.save.conflict") }
        .zIndex(isEditing ? 20 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .diaryPrivacyLifecycle(
            entry: entry,
            isPasswordType: isPasswordType,
            hostWindow: hostWindow,
            privacyVault: privacyVault,
            maskContent: maskContent
        )
        .contextMenu {
            if entry.hasProtectedContent {
                Button("privacy.unprotect", role: .destructive) { confirmsUnprotect = true }
            }
        }
        .confirmationDialog("privacy.unprotect.confirm", isPresented: $confirmsUnprotect) {
            Button("privacy.unprotect", role: .destructive, action: unprotectEntry)
            Button("alert.cancel", role: .cancel) {}
        }
    }

    private func unprotectEntry() {
        PrivacyAccess.withDiary(entry, force: true, vault: privacyVault) { current in
            guard let context = current.modelContext else { throw PrivacyError.staleOperation }
            try DiaryProtection.unprotect(current, in: PrivacyPersistence(context: context, vault: privacyVault))
        }
    }

    @ViewBuilder
    private var tagRow: some View {
        if !assignedTags.isEmpty || isHovered {
            HStack(spacing: 5) {
                ForEach(assignedTags) { tag in
                    assignedTagChip(tag)
                }

                if !addableTags.isEmpty {
                    addTagMenu
                }
            }
            .padding(.top, 2)
            .transition(.opacity)
        }
    }

    private func assignedTagChip(_ tag: TagItem) -> some View {
        let color = DiaryTagChrome.color(for: tag.name)
        return DaybookChip(tint: color, isSelected: true, action: {
            PrivacyAccess.withDiary(entry, requiresUnlock: tag.isPrivateDiary, vault: privacyVault) { current in
                DayBoardMutations.toggleDiaryTag(current, tagID: tag.id)
            }
        }) {
            Text("#\(tag.name)")
        }
        .help("diary.tag.off")
    }

    @ViewBuilder
    private var addTagMenu: some View {
        Menu {
            ForEach(addableTags) { tag in
                Button("#\(tag.name)") {
                    PrivacyAccess.withDiary(entry, requiresUnlock: tag.isPrivateDiary, vault: privacyVault) { current in
                        DayBoardMutations.toggleDiaryTag(current, tagID: tag.id)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 8.5, weight: .bold)) // token-exempt: 小于 9pt 的加号，kbd 是等宽
                if assignedTags.isEmpty {
                    Text("diary.tag.add")
                        .font(DaybookType.badge.weight(.medium))
                }
            }
            .foregroundStyle(DaybookPalette.text.secondary)
            .padding(.horizontal, assignedTags.isEmpty ? 6 : 4)
            .frame(height: 18)
            .background(Capsule().fill(DaybookPalette.fill.hover)) // token-exempt: 加标签胶囊，圆角由形状决定
            .overlay(
                Capsule().strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.7) // token-exempt: 加标签胶囊，圆角由形状决定
            )
        }
        .menuStyle(.borderlessButton)
        .help("diary.tag.add")
    }

    @ViewBuilder
    var contentView: some View {
        if !canRevealContent {
            maskedPasswordContentView
        } else if isEditing {
            editingContentView
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
        copyContent(to: .general)
    }

    func copyContent(to pasteboard: NSPasteboard) {
        PrivacyAccess.withDiary(entry, vault: privacyVault) { current in
            let text = try DiaryContent.read(current, vault: privacyVault)
            guard PrivateClipboard.copy(text, sensitive: current.hasProtectedContent || isPasswordType, to: pasteboard) else {
                throw PrivacyError.storageFailure
            }
            withAnimation(.snappy) { hasCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.snappy) { hasCopied = false }
            }
        }
    }

    func revealContent() {
        PrivacyAccess.withDiary(entry, requiresUnlock: editingSession?.needsUnlock == true, vault: privacyVault) { current in
            _ = try DiaryContent.read(current, vault: privacyVault)
            editingSession?.reveal()
            isMasked = false
        }
    }

    func maskContent() {
        isMasked = true
        editingSession?.mask()
    }

    func reloadEditingDraft() {
        PrivacyAccess.withDiary(entry, requiresUnlock: editingSession?.needsUnlock == true, vault: privacyVault) { _ in
            editingSession?.reloadLatest()
            editingSession?.reveal()
            isMasked = false
        }
    }

    func discardEditingDraft() {
        drafts.discard(entry.id)
        editFocused = false
        isMasked = true
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

private struct DiaryPrivacyLifecycleModifier: ViewModifier {
    let entry: DiaryEntry
    let isPasswordType: Bool
    let hostWindow: NSWindow?
    let privacyVault: PrivacyVault?
    let maskContent: () -> Void

    func body(content: Content) -> some View {
        content
            .onDisappear { maskContent() }
            .onChange(of: entry.text) { _, _ in maskContent() }
            .onChange(of: entry.encryptedText) { _, _ in maskContent() }
            .onChange(of: entry.tagIDs) { _, _ in maskContent() }
            .onChange(of: isPasswordType) { _, _ in maskContent() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                maskContent()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
                if let window = notification.object as? NSWindow, window === hostWindow { maskContent() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .privacyWillLock, object: privacyVault)) { _ in
                maskContent()
            }
            .onReceive(NotificationCenter.default.publisher(for: .privacyMask, object: privacyVault)) { _ in
                maskContent()
            }
    }
}

extension View {
    fileprivate func diaryPrivacyLifecycle(
        entry: DiaryEntry,
        isPasswordType: Bool,
        hostWindow: NSWindow?,
        privacyVault: PrivacyVault?,
        maskContent: @escaping () -> Void
    ) -> some View {
        modifier(DiaryPrivacyLifecycleModifier(
            entry: entry,
            isPasswordType: isPasswordType,
            hostWindow: hostWindow,
            privacyVault: privacyVault,
            maskContent: maskContent
        ))
    }
}
