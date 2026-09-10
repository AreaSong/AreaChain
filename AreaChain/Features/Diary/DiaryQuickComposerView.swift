import SwiftUI

/// 灵感手记快捷编辑器
struct DiaryQuickComposerView: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var orderedTags: [TagItem]
    @Binding var selectedTagIDs: Set<UUID>
    var onSubmit: () -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            editorInputView
            tagAndActionRow
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(DaybookTheme.hoverFill.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.8)
        )
    }

    private var editorInputView: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("diary.composer.placeholder")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7))
                    .padding(.top, 8)
                    .padding(.leading, 8)
            }

            TextEditor(text: $text)
                .font(DaybookType.body)
                .foregroundStyle(DaybookTheme.ink)
                .frame(minHeight: 48, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .focused(focused)
                .padding(4)
        }
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .stroke(focused.wrappedValue ? DaybookTheme.focusRing : DaybookTheme.cardBorder, lineWidth: focused.wrappedValue ? 1.4 : 0.8)
        )
    }

    private var tagAndActionRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "tag")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)

            tagScrollView

            Spacer()

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
        return Button {
            if isSelected {
                selectedTagIDs.remove(tag.id)
            } else {
                selectedTagIDs.insert(tag.id)
            }
        } label: {
            HStack(spacing: 3) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
                Text("#\(tag.name)")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(isSelected ? color.opacity(0.18) : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? color.opacity(0.5) : DaybookTheme.rule.opacity(0.6), lineWidth: 0.8)
            )
            .foregroundStyle(isSelected ? color : DaybookTheme.muted)
        }
        .buttonStyle(.plain)
    }

    private var submitButton: some View {
        Button(action: onSubmit) {
            HStack(spacing: 4) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 10, weight: .semibold))
                Text("diary.composer.save")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(canSubmit ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.2))
            )
            .foregroundStyle(canSubmit ? Color.white : DaybookTheme.muted)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .keyboardShortcut(.return, modifiers: .command)
    }
}
