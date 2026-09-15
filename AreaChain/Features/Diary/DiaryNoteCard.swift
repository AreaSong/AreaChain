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
    @Environment(\.daybookViewStyle) var viewStyle
    var entry: DiaryEntry
    var activeTags: [TagItem]
    var attachments: [AttachmentItem]
    var onDelete: () -> Void
    var isHighlighted: Bool = false
    var privacyTags: [TagItem]? = nil
    var draftStore: DiaryCardDrafts? = nil
    var vault: PrivacyVault? = nil

    @State var isHovered = false
    @State private var localDrafts = DiaryCardDrafts()
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
        .background(
            RoundedRectangle(cornerRadius: viewStyle.isWorkspace ? WorkspaceStyle.cardRadius : DaybookRadius.medium, style: .continuous)
                .fill(isHovered ? (viewStyle.isWorkspace ? WorkspaceStyle.hover : DaybookTheme.cardSurfaceHover) : viewStyle.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: viewStyle.isWorkspace ? WorkspaceStyle.cardRadius : DaybookRadius.medium, style: .continuous)
                .strokeBorder(
                    isHighlighted
                        ? DaybookTheme.stamp
                        : (entry.isPinned ? DaybookTheme.stamp.opacity(0.35) : (isHovered ? DaybookTheme.cardBorderHover : viewStyle.cardBorder)),
                    lineWidth: isHighlighted || entry.isPinned ? 1.2 : 0.8
                )
        )
        .onHover { isHovered = $0 }
        .background(KeyWindowHost { hostWindow = $0 })
        .alert("diary.window.reload.title", isPresented: $showsEditConflict) {
            Button("diary.window.reload") { reloadEditingDraft() }
            Button("alert.cancel", role: .cancel) {}
        } message: { Text("diary.window.save.conflict") }
        .zIndex(isEditing ? 20 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onDisappear { maskContent() }
        .onChange(of: entry.text) { _, _ in isMasked = true }
        .onChange(of: entry.encryptedText) { _, _ in isMasked = true }
        .onChange(of: entry.tagIDs) { _, _ in isMasked = true }
        .onChange(of: isPasswordType) { _, _ in isMasked = true }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            maskContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window === hostWindow { maskContent() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .privacyWillLock, object: privacyVault)) { _ in maskContent() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyMask, object: privacyVault)) { _ in maskContent() }
        .contextMenu {
            if entry.hasProtectedContent {
                Button("privacy.unprotect", role: .destructive) { confirmsUnprotect = true }
            }
        }
        .confirmationDialog("privacy.unprotect.confirm", isPresented: $confirmsUnprotect) {
            Button("privacy.unprotect", role: .destructive) {
                PrivacyAccess.withDiary(entry, force: true, vault: privacyVault) { current in
                    guard let context = current.modelContext else { throw PrivacyError.staleOperation }
                    try DiaryProtection.unprotect(current, in: PrivacyPersistence(context: context, vault: privacyVault))
                }
            }
            Button("alert.cancel", role: .cancel) {}
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
        return Button {
            PrivacyAccess.withDiary(entry, requiresUnlock: tag.isPrivateDiary, vault: privacyVault) { current in
                DayBoardMutations.toggleDiaryTag(current, tagID: tag.id)
            }
        } label: {
            HStack(spacing: 3) {
                Text("#\(tag.name)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                Capsule().fill(color.opacity(0.12))
            )
            .overlay(
                Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
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
                    .font(.system(size: 8.5, weight: .bold))
                if assignedTags.isEmpty {
                    Text("diary.tag.add")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundStyle(DaybookTheme.muted)
            .padding(.horizontal, assignedTags.isEmpty ? 6 : 4)
            .frame(height: 18)
            .background(Capsule().fill(DaybookTheme.hoverFill))
            .overlay(
                Capsule().strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.7)
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
