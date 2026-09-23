import SwiftUI

extension DiaryNoteCard {
    var cardHeaderView: some View {
        HStack(alignment: .center, spacing: 6) {
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookTheme.stamp)
            }

            Text(formatDate(entry.createdAt))
                .font(DaybookType.caption.monospaced())
                .foregroundStyle(DaybookTheme.muted)

            if isPasswordType {
                HStack(spacing: 3) {
                    Image(systemName: "lock.shield.fill")
                        .font(DaybookType.micro)
                    Text("diary.privacy")
                        .font(DaybookType.badge.weight(.medium))
                }
                .foregroundStyle(DaybookPalette.status.danger.opacity(0.85)) // token-exempt: 85% 危险色没有对应令牌
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(DaybookPalette.status.danger.opacity(0.10))) // token-exempt: 10% 危险色底没有对应令牌
            }

            if showsCommandStrip {
                DiaryRowCommandStrip(
                    isSensitive: isPasswordType,
                    isPinned: entry.isPinned,
                    hasConvertedToTask: hasConvertedToTask,
                    allTags: activeTags,
                    assignedTagIDs: Set(TagIDList.parse(entry.tagIDs)),
                    currentDayKey: entry.dayKey,
                    onOpen: openDiaryWindow,
                    onConvertToTask: convertDiaryToTask,
                    onCopy: copyContent,
                    onToggleTag: { toggleDiaryTag($0) },
                    onMoveToDay: { DayBoardMutations.moveDiary(entry, to: $0) },
                    onPickCustomDate: { pickingDay = true },
                    onTogglePin: { _ = DayBoardMutations.togglePinDiary(entry) },
                    onAttach: attachImage,
                    onTogglePrivate: { _ = DayBoardMutations.togglePrivateDiary(entry) },
                    onInspect: inspectDiaryInWorkspace,
                    onDelete: onDelete
                )
            } else {
                Spacer()
                actionButtons
            }
        }
    }

    private func openDiaryWindow() {
        DiaryWindows.shared.open(entry: entry, context: modelContext)
    }

    private func convertDiaryToTask() {
        if DayBoardMutations.convertDiaryToTodo(entry, context: modelContext) {
            hasConvertedToTask = true
        }
    }

    private func toggleDiaryTag(_ tagID: UUID) {
        DayBoardMutations.toggleDiaryTag(entry, tagID: tagID)
    }

    private func attachImage() {
        guard !(isPasswordType && isMasked) else { return }
        AttachmentActions.pickDiaryImage(entry, context: modelContext, vault: privacyVault)
    }

    private func inspectDiaryInWorkspace() {
        BoardSelection.shared.inspectDiary(id: entry.id, dayKey: entry.dayKey)
        AppWindows.openDiary()
    }

    @ViewBuilder var editingContentView: some View {
        if let session = editingSession {
            editingContent(session)
        }
    }

    private func editingContent(_ session: DiaryEditorSession) -> some View {
        @Bindable var session = session
        return VStack(alignment: .trailing, spacing: 6) {
            DaybookInputShell(kind: .editor, focused: editFocused) {
                SyntaxTextEditor(
                    text: $session.text, focused: $editFocused,
                    placeholder: L10n.string("diary.composer.placeholder", locale: locale), onSubmit: saveTextEdit
                )
                .frame(minHeight: 64, maxHeight: 160)
                .onAppear { editFocused = true }
            }
            .zIndex(20)

            HStack {
                Button("alert.cancel", action: discardEditingDraft)
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .font(DaybookType.caption)

                Button("common.save", action: saveTextEdit)
                .buttonStyle(.borderedProminent)
                .font(DaybookType.caption)
            }
        }
    }

    private func saveTextEdit() {
        guard let session = editingSession else { return }
        PrivacyAccess.withDiary(entry, requiresUnlock: session.needsUnlock, vault: privacyVault) { _ in
            if session.save() { discardEditingDraft() }
            else if session.issue == .conflict { showsEditConflict = true }
        }
    }

    func beginEditing() {
        PrivacyAccess.withDiary(entry, requiresUnlock: editingSession?.needsUnlock == true, vault: privacyVault) { current in
            _ = drafts.begin(current, context: modelContext, vault: privacyVault)
            showsEditConflict = false
            isMasked = false
        }
    }

    var maskedPasswordContentView: some View {
        HStack(spacing: 8) {
            Text("••••••••••••••••")
                .font(.system(size: 14, weight: .bold, design: .monospaced)) // token-exempt: 密码占位用等宽粗体，bodyLarge 是 14pt 常规无衬线
                .foregroundStyle(DaybookTheme.muted)
                .blur(radius: 1.5)

            Spacer()

            Button {
                revealContent()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "eye")
                    Text("diary.reveal")
                }
                .font(DaybookType.caption)
            }
            .buttonStyle(DaybookButtonStyle(.pill(tint: DaybookPalette.accent.base), size: .compact))
        }
        .padding(.vertical, 4)
    }

    var readOnlyTextView: some View {
        Text(displayedText)
            .font(DaybookType.body)
            .lineSpacing(3.5)
            .foregroundStyle(DaybookTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .overlay {
                BoardRowPointerRegion(
                    id: entry.id,
                    plainDoubleClick: true,
                    onSelect: { _, _ in },
                    onDoubleClick: beginEditing
                )
                .accessibilityHidden(true)
            }
    }

    @ViewBuilder
    var copyAndMaskButtons: some View {
        if isPasswordType {
            Button(action: copyContent) {
                HStack(spacing: 2) {
                    Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                    Text(hasCopied ? "diary.copied" : "diary.copy.password")
                }
                .font(DaybookType.badge.weight(.medium))
            }
            .buttonStyle(DaybookButtonStyle(hasCopied ? .active : .prominent, size: .compact))
            .help("diary.copy.password.help")

            Button {
                if canRevealContent { maskContent() }
                else { revealContent() }
            } label: {
                Image(systemName: isMasked ? "eye" : "eye.slash")
            }
            .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
            .help(isMasked ? "diary.unmask" : "diary.mask")
            .accessibilityLabel(isMasked ? "diary.unmask" : "diary.mask")
        } else {
            Button(action: copyContent) {
                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(DaybookButtonStyle(hasCopied ? .iconActive : .icon, size: .compact))
            .help("diary.copy")
            .accessibilityLabel("diary.copy")
        }
    }

    private var pinActionButton: some View {
        Button {
            DayBoardMutations.togglePinDiary(entry)
        } label: {
            Image(systemName: entry.isPinned ? "pin.fill" : "pin")
        }
        .buttonStyle(DaybookButtonStyle(entry.isPinned ? .iconActive : .icon, size: .compact))
        .help(entry.isPinned ? "diary.unpin" : "diary.pin")
        .accessibilityLabel(entry.isPinned ? "diary.unpin" : "diary.pin")
    }

    private var editActionButton: some View {
        Button {
            guard !(isPasswordType && isMasked) else { return }
            beginEditing()
        } label: {
            Image(systemName: "pencil")
        }
        .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
        .disabled(isPasswordType && isMasked)
        .help(isPasswordType && isMasked ? "diary.unmask.first" : "diary.edit.help")
        .accessibilityLabel("diary.edit.help")
    }

    private var attachActionButton: some View {
        Button {
            guard !(isPasswordType && isMasked) else { return }
            AttachmentActions.pickDiaryImage(entry, context: modelContext, vault: privacyVault)
        } label: {
            Image(systemName: "photo")
        }
        .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
        .disabled(isPasswordType && isMasked)
        .help(isPasswordType && isMasked ? "diary.unmask.first" : "diary.attach")
        .accessibilityLabel("diary.attach")
    }

    private var deleteActionButton: some View {
        DaybookIconButton(systemName: "trash", label: "alert.trash.move", size: .compact, role: .destructive, action: onDelete)
    }

    @ViewBuilder
    var managementActionButtons: some View {
        pinActionButton
        editActionButton
        attachActionButton
        deleteActionButton
    }
}
