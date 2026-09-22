import SwiftUI

extension DiaryNoteCard {
    var cardHeaderView: some View {
        HStack(alignment: .center, spacing: 6) {
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.stamp)
            }

            Text(formatDate(entry.createdAt))
                .font(DaybookType.caption.monospaced())
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
                .buttonStyle(.plain)
                .font(.system(size: 11))

                Button("common.save", action: saveTextEdit)
                .buttonStyle(.borderedProminent)
                .font(.system(size: 11))
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
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(DaybookTheme.muted)
                .blur(radius: 1.5)

            Spacer()

            Button {
                revealContent()
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
                if canRevealContent { maskContent() }
                else { revealContent() }
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
    }

    private var pinActionButton: some View {
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
    }

    private var editActionButton: some View {
        Button {
            guard !(isPasswordType && isMasked) else { return }
            beginEditing()
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
    }

    private var attachActionButton: some View {
        Button {
            guard !(isPasswordType && isMasked) else { return }
            AttachmentActions.pickDiaryImage(entry, context: modelContext, vault: privacyVault)
        } label: {
            Image(systemName: "photo")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(isPasswordType && isMasked)
        .opacity(isPasswordType && isMasked ? 0.35 : 1)
        .help(isPasswordType && isMasked ? "diary.unmask.first" : "diary.attach")
    }

    private var deleteActionButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.destructive.opacity(0.8))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help("alert.trash.move")
    }

    @ViewBuilder
    var managementActionButtons: some View {
        pinActionButton
        editActionButton
        attachActionButton
        deleteActionButton
    }
}
