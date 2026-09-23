import AppKit
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
    @State private var hostWindow: NSWindow?
    @State private var autocomplete = SyntaxAutocompleteState(context: .diaryCapture, allowsLivePreview: true)

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if isCompact {
            compactInputRow
                .syntaxSuggestions(autocomplete)
                .animation(DaybookMotion.interactive(reduceMotion), value: focused.wrappedValue)
        } else {
            workspaceComposer
        }
    }

    @ViewBuilder
    private var workspaceComposer: some View {
        composerContent
            .padding(10)
            .background(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(DaybookPalette.fill.hover.opacity(0.5))) // token-exempt: 悬停底 50% 没有对应令牌
            .overlay(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.8))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var composerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            editorInputView.zIndex(20)
            tagAndActionRow
        }
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
                    action: submitCompact
                )
            }
        }
        .background(KeyWindowHost { hostWindow = $0 })
        .background(SyntaxViewAnchor("syntax.diary.composer"))
        .onChange(of: text) { _, newText in
            if newText.isEmpty {
                autocomplete.dismiss()
            }
        }
        .onChange(of: orderedTags) { _, tags in
            autocomplete.availableTags = tags.map(\.name)
        }
        .onAppear {
            autocomplete.availableTags = orderedTags.map(\.name)
        }
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

    private func submitCompact() {
        guard canSubmit, !hasMarkedText else { return }
        autocomplete.dismiss()
        onSubmit()
    }

    private var editorInputView: some View {
        DaybookInputShell(kind: .editor, focused: focused.wrappedValue) {
            SyntaxTextEditor(
                text: $text, focused: focused,
                placeholder: L10n.string("diary.composer.placeholder", locale: locale),
                onSubmit: onSubmit
            )
            .frame(minHeight: 64, maxHeight: 100)
        }
    }

    private var tagAndActionRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "tag")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)

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
        Button(action: onSubmit) {
            HStack(spacing: 4) {
                Image(systemName: "square.and.pencil")
                Text("diary.composer.save")
            }
            .font(DaybookType.caption.weight(.semibold))
        }
        .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
        .disabled(!canSubmit)
        .keyboardShortcut(.return, modifiers: .command)
    }
}
