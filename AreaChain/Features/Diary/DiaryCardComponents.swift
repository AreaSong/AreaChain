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

            Spacer()

            actionButtons
        }
    }

    var editingContentView: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextEditor(text: $editDraft)
                .font(DaybookType.body)
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
    }

    var maskedPasswordContentView: some View {
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
    }

    var readOnlyTextView: some View {
        Text(entry.text)
            .font(DaybookType.body)
            .lineSpacing(3.5)
            .foregroundStyle(DaybookTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                editDraft = entry.text
                isEditing = true
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
    }

    private var attachActionButton: some View {
        Button {
            guard !(isPasswordType && isMasked) else { return }
            AttachmentActions.pickImage(ownerKind: .diary, ownerID: entry.id, context: modelContext)
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
