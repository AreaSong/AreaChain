import AppKit
import SwiftData
import SwiftUI

/// 灵感手记快捷编辑器
struct DiaryQuickComposerView: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var text: String
    var focused: Binding<Bool>
    var orderedTags: [TagItem]
    @Binding var selectedTagIDs: Set<UUID>
    var onSubmit: () -> Void
    var isCompact = false
    var status: String? = nil
    var isSensitive: Bool = false
    var onOpenWindow: (() -> Void)? = nil
    @Bindable private var shortcuts = ShortcutStore.shared
    @State private var hostWindow: NSWindow?
    @State private var autocomplete = SyntaxAutocompleteState(context: .diaryCapture, allowsLivePreview: true)
    @State private var isManuallyExpanded = false

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isExpandedForLongText: Bool {
        isManuallyExpanded || text.contains("\n") || text.count > 42
    }

    var body: some View {
        Group {
            if isCompact {
                compactInputRow
                    .syntaxSuggestions(autocomplete)
                    .animation(DaybookMotion.interactive(reduceMotion), value: focused.wrappedValue)
            } else {
                workspaceComposer
                    .syntaxSuggestions(autocomplete)
            }
        }
        .background(KeyWindowHost { hostWindow = $0 })
        .onChange(of: text) { _, newText in
            if newText.isEmpty {
                isManuallyExpanded = false
                autocomplete.reset()
            }
        }
        .onChange(of: orderedTags) { _, tags in
            autocomplete.availableTags = tags.map(\.name)
        }
        .onAppear {
            autocomplete.availableTags = orderedTags.map(\.name)
        }
    }

    @ViewBuilder
    private var workspaceComposer: some View {
        let expanded = isExpandedForLongText
        VStack(alignment: .leading, spacing: expanded ? 8 : 0) {
            HStack(alignment: expanded ? .top : .center, spacing: 8) {
                if !expanded {
                    statusIcon
                        .padding(.leading, 4)
                }
                SyntaxTextEditor(
                    text: $text,
                    focused: focused,
                    placeholder: L10n.string(
                        expanded ? "diary.composer.placeholder" : "diary.quick.placeholder",
                        locale: locale
                    ),
                    context: .diaryCapture,
                    externalAutocomplete: autocomplete,
                    availableTags: orderedTags.map(\.name),
                    onSubmit: submitWorkspace,
                    commandChord: shortcuts.armedChord(for: .commitDiary)
                )
                .frame(minHeight: expanded ? 104 : 28, maxHeight: expanded ? 196 : 28)
                .zIndex(20)

                if !expanded {
                    workspaceCompactTrailingActions
                }
            }

            if expanded {
                tagAndActionRow
            }
        }
        .padding(.horizontal, expanded ? 10 : 8)
        .padding(.vertical, expanded ? 10 : 4)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(expanded ? DaybookPalette.sidebarFill : DaybookPalette.fill.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(
                    focused.wrappedValue ? DaybookPalette.border.focus : DaybookPalette.border.subtle,
                    lineWidth: focused.wrappedValue ? 1.2 : 0.8
                )
        )
        .daybookElevation(expanded ? .panel : .flat)
        .fixedSize(horizontal: false, vertical: true)
        .animation(DaybookMotion.interactive(reduceMotion), value: expanded)
    }

    private var workspaceCompactTrailingActions: some View {
        HStack(spacing: 6) {
            Button {
                isManuallyExpanded = true
                focused.wrappedValue = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
            .help("diary.composer.placeholder")

            if let onOpenWindow {
                Button {
                    guard !hasMarkedText else { return }
                    onOpenWindow()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
                .help(canSubmit ? "diary.window.continue" : "diary.window.new")
                .accessibilityLabel(canSubmit ? "diary.window.continue" : "diary.window.new")
            }

            submitButton
        }
    }

    private func submitWorkspace() {
        guard canSubmit, !hasMarkedText else { return }
        isManuallyExpanded = false
        autocomplete.reset()
        onSubmit()
    }

    private var compactInputRow: some View {
        let focused = focused.wrappedValue

        return DaybookInputShell(kind: .composer, focused: focused) {
            statusIcon
        } field: {
            DaybookTextField(
                text: $text,
                placeholder: L10n.string("diary.quick.placeholder", locale: locale),
                focus: self.focused,
                autocomplete: autocomplete,
                availableTags: orderedTags.map(\.name),
                highlightsSyntax: true,
                onSubmit: submitCompact,
                onCommandReturn: submitCompact,
                commandChord: shortcuts.armedChord(for: .commitDiary),
                allowsShiftNewline: false
            )
            .accessibilityLabel("diary.quick.input")
        } trailing: {
            HStack(spacing: 8) {
                if let onOpenWindow {
                    Button {
                        guard !hasMarkedText else { return }
                        onOpenWindow()
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
                    .help(canSubmit ? "diary.window.continue" : "diary.window.new")
                    .accessibilityLabel(canSubmit ? "diary.window.continue" : "diary.window.new")
                    .background(SyntaxViewAnchor("syntax.diary.popout"))
                }

                CommandReturnButton(
                    enabled: canSubmit,
                    label: "diary.quick.save",
                    help: "diary.quick.save.help",
                    symbolText: diarySymbol,
                    action: submitCompact
                )
            }
        }
        .background(SyntaxViewAnchor("syntax.diary.composer"))
    }

    private var statusIcon: some View {
        let saved = status == "diary.window.saved"
        let failed = status != nil && !saved
        let systemName: String = {
            if failed { return "exclamationmark.circle" }
            if saved { return "checkmark" }
            if isSensitive { return "lock.shield" }
            return "plus"
        }()
        let iconColor: Color = {
            if failed { return DaybookPalette.status.danger }
            if focused.wrappedValue || saved || isSensitive { return DaybookPalette.accent.base }
            return DaybookPalette.text.secondary.opacity(0.8) // token-exempt: 80% 次要色没有对应令牌
        }()

        return Image(systemName: systemName)
            .font(DaybookType.caption.weight(.semibold))
            .foregroundStyle(iconColor)
            .frame(width: 14)
            .help(LocalizedStringKey(status ?? (isSensitive ? "diary.privacy" : "diary.quick.input")))
            .accessibilityLabel(LocalizedStringKey(status ?? (isSensitive ? "diary.privacy" : "diary.quick.input")))
            .accessibilityHidden(status == nil && !isSensitive)
            .animation(.easeInOut(duration: 0.2), value: status)
            .animation(.easeInOut(duration: 0.2), value: isSensitive)
    }

    private var hasMarkedText: Bool {
        (hostWindow?.firstResponder as? NSTextView)?.hasMarkedText() == true
    }

    private var diarySymbol: String? {
        let binding = shortcuts.binding(for: .commitDiary)
        guard binding.chord != ShortcutAction.commitDiary.defaultChord else { return nil }
        return binding.chord.displayName(locale: locale)
    }

    private func submitCompact() {
        guard canSubmit, !hasMarkedText else { return }
        autocomplete.dismiss()
        onSubmit()
    }

    private var tagAndActionRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "tag")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)

            tagScrollView

            Spacer()

            if isManuallyExpanded && !text.contains("\n") && text.count <= 42 {
                Button {
                    isManuallyExpanded = false
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                }
                .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
            }

            if let onOpenWindow {
                Button {
                    guard !hasMarkedText else { return }
                    onOpenWindow()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
                .help(canSubmit ? "diary.window.continue" : "diary.window.new")
                .accessibilityLabel(canSubmit ? "diary.window.continue" : "diary.window.new")
            }

            submitButton
        }
    }

    private var tagScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(orderedTags) { tag in
                    tagChip(tag)
                }
            }
        }
    }

    private func tagChip(_ tag: TagItem) -> some View {
        let isSelected = selectedTagIDs.contains(tag.id)
        let color = DiaryTagChrome.color(for: tag.name)
        return DaybookChip(tint: color, isSelected: isSelected, action: {
            if isSelected {
                selectedTagIDs.remove(tag.id)
            } else {
                selectedTagIDs.insert(tag.id)
            }
        }) {
            HStack(spacing: 3) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text("#\(tag.name)")
            }
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        standardSubmitButton
    }

    private var standardSubmitButton: some View {
        Button(action: submitWorkspace) {
            HStack(spacing: 4) {
                Image(systemName: "square.and.pencil")
                Text("diary.composer.save")
            }
            .font(DaybookType.caption.weight(.semibold))
        }
        .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
        .disabled(!canSubmit)
        .appShortcut(.commitDiary)
    }
}

/// 独立承载手记快速输入区状态，避免每次按键触发整页列表与卡片重建。
struct DiaryComposerHostSection: View {
    @Environment(\.modelContext) private var modelContext
    var todayKey: String
    var showsPageHeader: Bool
    var orderedTags: [TagItem]
    var allTags: [TagItem]
    var vault: PrivacyVault
    var hostWindow: NSWindow?
    @Binding var externalComposerDraft: BoardComposerDraft
    var usesExternalComposerDraft: Bool

    @State private var localComposerDraft = BoardComposerDraft()
    @State private var composerFocused = false
    @State private var composerStatus: String?
    @State private var confirmsDiscardDraft = false

    // 外部草稿必须是动态属性，否则子编辑器会更新，父级的锁定分支却可能没有刷新。
    private var draftBinding: Binding<BoardComposerDraft> {
        usesExternalComposerDraft ? $externalComposerDraft : $localComposerDraft
    }

    private var composerNeedsProtection: Bool {
        if draftBinding.wrappedValue.sealed != nil { return true }
        return DiaryContent.requiresProtection(text: draftText, tagIDs: composerSelectedTagIDs, tags: allTags)
    }

    private var draftText: String {
        get { draftBinding.wrappedValue.text }
        nonmutating set { draftBinding.wrappedValue.text = newValue }
    }

    private var composerSelectedTagIDs: Set<UUID> {
        get { draftBinding.wrappedValue.selectedTagIDs }
        nonmutating set { draftBinding.wrappedValue.selectedTagIDs = newValue }
    }

    var body: some View {
        Group {
            if draftBinding.wrappedValue.sealed != nil {
                lockedBanner
            } else {
                DiaryQuickComposerView(
                    text: draftBinding.text, focused: $composerFocused, orderedTags: orderedTags,
                    selectedTagIDs: draftBinding.selectedTagIDs, onSubmit: submitNote,
                    isCompact: !showsPageHeader, status: composerStatus,
                    isSensitive: composerNeedsProtection, onOpenWindow: detachDraft
                )
            }
        }
        .onChange(of: draftText) { _, text in
            if composerStatus != nil, !text.isEmpty { composerStatus = nil }
            let needsProtection = composerNeedsProtection
            if draftBinding.wrappedValue.needsProtection != needsProtection {
                draftBinding.wrappedValue.needsProtection = needsProtection
            }
            if needsProtection { vault.touch() }
        }
        .onChange(of: composerSelectedTagIDs) { _, _ in
            let needsProtection = composerNeedsProtection
            if draftBinding.wrappedValue.needsProtection != needsProtection {
                draftBinding.wrappedValue.needsProtection = needsProtection
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .privacyWillLock, object: vault)) { _ in sealComposer() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyMask, object: vault)) { _ in sealComposer() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in sealComposer() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window === hostWindow, window.attachedSheet == nil {
                sealComposer()
            }
        }
        .onDisappear { sealComposer() }
        .confirmationDialog("privacy.draft.discard.confirm", isPresented: $confirmsDiscardDraft) {
            Button("privacy.draft.discard", role: .destructive) { draftBinding.wrappedValue = BoardComposerDraft() }
            Button("alert.cancel", role: .cancel) {}
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryAppendToken)) { notif in
            if let token = notif.object as? String {
                let prefix = (draftText.isEmpty || draftText.hasSuffix(" ") || draftText.hasSuffix("\n")) ? "" : " "
                draftText += prefix + token
                DispatchQueue.main.async { composerFocused = true }
            }
        }
    }

    private var lockedBanner: some View {
        HStack {
            Label("privacy.draft.locked", systemImage: "lock")
            Spacer()
            Button("privacy.unlock.title") {
                PrivacyAccess.perform(requiresUnlock: true, vault: vault) {
                    try draftBinding.wrappedValue.restore(vault: vault)
                    composerFocused = true
                }
            }
            .buttonStyle(DaybookButtonStyle(.prominent))
            Button("privacy.draft.discard") { confirmsDiscardDraft = true }
                .buttonStyle(DaybookButtonStyle(.quiet))
        }
        .font(DaybookType.caption)
        .daybookSurface(.banner)
    }

    private func submitNote() {
        guard draftBinding.wrappedValue.hasContent else { return }
        let draftID = draftBinding.wrappedValue.id
        PrivacyAccess.perform(requiresUnlock: draftBinding.wrappedValue.sealed != nil, vault: vault) {
            guard draftBinding.wrappedValue.id == draftID else { throw PrivacyError.staleOperation }
            try draftBinding.wrappedValue.restore(vault: vault)
            let rawText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawText.isEmpty else { return }

            let parsed = NaturalLanguageParser.parseDiaryCapture(rawText)
            let textToSave: String = {
                if parsed.hasNoteSeparator && !parsed.cleanTitle.isEmpty {
                    return parsed.cleanTitle + (parsed.body.isEmpty ? "" : "\n" + parsed.body)
                } else if !parsed.body.isEmpty {
                    return parsed.body
                } else {
                    return NaturalLanguageParser.unescapeSyntax(rawText)
                }
            }()
            guard !textToSave.isEmpty else { return }

            var effectiveTagIDs = composerSelectedTagIDs
            if !parsed.tagNames.isEmpty {
                let resolvedIDs = try InputTagResolver.resolve(parsed.tagNames, in: modelContext)
                effectiveTagIDs.formUnion(resolvedIDs)
            }

            guard DayBoardMutations.addDiary(
                text: textToSave, dayKey: todayKey, selectedTagIDs: effectiveTagIDs,
                tags: allTags, context: modelContext
            ) else { composerStatus = "diary.window.save.failed"; return }
            draftBinding.wrappedValue = BoardComposerDraft()
            composerStatus = "diary.window.saved"
            composerFocused = true
        }
    }

    private func sealComposer() {
        draftBinding.wrappedValue.needsProtection = composerNeedsProtection
        do { try draftBinding.wrappedValue.seal(vault: vault) }
        catch { composerStatus = "privacy.error.corruptData" }
    }

    private func detachDraft() {
        composerFocused = false
        if draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DiaryWindows.shared.openDraft(BoardComposerDraft(), dayKey: todayKey, context: modelContext)
        } else {
            DiaryWindows.shared.openDraft(draftBinding.wrappedValue, dayKey: todayKey, context: modelContext) {
                draftBinding.wrappedValue = BoardComposerDraft()
                composerStatus = nil
            }
        }
    }
}
