import AppKit
import SwiftUI

/// 灵感手记快捷编辑器
struct DiaryQuickComposerView: View {
    @Environment(\.locale) private var locale
    @Environment(\.daybookViewStyle) private var style
    @Binding var text: String
    var focused: Binding<Bool>
    var orderedTags: [TagItem]
    @Binding var selectedTagIDs: Set<UUID>
    var onSubmit: () -> Void
    var isCompact = false
    var status: String? = nil
    var isSensitive: Bool = false
    var onOpenWindow: (() -> Void)? = nil
    @State private var hostWindow: NSWindow?
    @State private var isPopoutHovered = false

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if isCompact { compactInputRow } else { workspaceComposer }
    }

    @ViewBuilder
    private var workspaceComposer: some View {
        if style.isWorkspace {
            composerContent
                .daybookInputChrome(focused: focused.wrappedValue, kind: .composer)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            composerContent
                .padding(10)
                .background(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .fill(DaybookTheme.hoverFill.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var composerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            editorInputView.zIndex(20)
            tagAndActionRow
        }
    }

    private var compactInputRow: some View {
        let focused = focused.wrappedValue
        let strokeColor = focused ? DaybookTheme.stamp.opacity(0.48) : DaybookTheme.rule.opacity(0.45)

        return HStack(alignment: .center, spacing: 8) {
            statusIcon

            DaybookTextField(
                text: $text,
                placeholder: L10n.string("diary.quick.placeholder", locale: locale),
                focus: self.focused,
                availableTags: orderedTags.map(\.name),
                highlightsSyntax: true,
                onSubmit: submitCompact,
                onCommandReturn: submitCompact,
                allowsShiftNewline: false
            )
            .accessibilityLabel("diary.quick.input")

            if let onOpenWindow {
                Button {
                    guard !hasMarkedText else { return }
                    onOpenWindow()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 11.5, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                .fill(isPopoutHovered ? DaybookTheme.ink.opacity(0.08) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(isPopoutHovered ? DaybookTheme.ink : DaybookTheme.muted.opacity(canSubmit ? 0.85 : 0.45))
                .onHover { isPopoutHovered = $0 }
                .help(canSubmit ? "diary.window.continue" : "diary.window.new")
                .accessibilityLabel(canSubmit ? "diary.window.continue" : "diary.window.new")
                .background(SyntaxViewAnchor("syntax.diary.popout"))
            }

            CommandReturnButton(
                enabled: canSubmit,
                label: "diary.quick.save",
                help: "diary.quick.save.help",
                action: submitCompact
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(focused ? DaybookTheme.surface : DaybookTheme.ink.opacity(0.025))
                .shadow(color: focused ? DaybookShadow.cardSubtle : .clear, radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(strokeColor, lineWidth: focused ? 0.9 : 0.6)
        )
        .background(KeyWindowHost { hostWindow = $0 })
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
            if failed { return DaybookTheme.destructive }
            if focused.wrappedValue || saved || isSensitive { return DaybookTheme.stamp }
            return DaybookTheme.muted.opacity(0.8)
        }()

        return Image(systemName: systemName)
            .font(.system(size: 11.5, weight: .semibold))
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

    private func submitCompact() {
        guard canSubmit, !hasMarkedText else { return }
        onSubmit()
    }

    @ViewBuilder
    private var editorInputView: some View {
        let editor = SyntaxTextEditor(
            text: $text, focused: focused,
            placeholder: L10n.string("diary.composer.placeholder", locale: locale),
            onSubmit: onSubmit
        )
        .frame(minHeight: 64, maxHeight: 100)
        if style.isWorkspace {
            editor
        } else {
            editor.daybookInputChrome(focused: focused.wrappedValue, kind: .editor)
        }
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

    @ViewBuilder
    private var submitButton: some View {
        if style.isWorkspace {
            ComposerAddButton(title: "diary.composer.save", enabled: canSubmit, action: onSubmit)
                .keyboardShortcut(.return, modifiers: .command)
        } else {
            standardSubmitButton
        }
    }

    private var standardSubmitButton: some View {
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
