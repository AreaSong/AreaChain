import AppKit
import SwiftData
import SwiftUI

struct DiaryWindowView: View {
    @Bindable var session: DiaryEditorSession
    var onPin: () -> Void
    var onStateChange: () -> Void = {}
    @Environment(\.locale) private var locale
    @Query private var attachments: [AttachmentItem]
    @Bindable private var shortcuts = ShortcutStore.shared
    @State private var editorFocused = false
    @State private var confirmsReload = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            if let record = session.record, session.canRevealContent {
                let items = CatalogChoices.attachments(record.id, in: attachments, ownerKind: .diary)
                if !items.isEmpty {
                    ScrollView(.horizontal) { AttachmentThumbnails(items: items) }
                        .frame(height: 30)
                }
            }
            footer
        }
        .padding(16)
        .frame(minWidth: 328, minHeight: 230)
        .background(DaybookPalette.fill.page)
        .syntaxOverlayHost()
        .onAppear { editorFocused = session.canRevealContent }
        .onChange(of: session.canRevealContent) { _, value in editorFocused = value }
        .onChange(of: session.statusKey) { _, _ in onStateChange() }
        .confirmationDialog("diary.window.reload.title", isPresented: $confirmsReload, titleVisibility: .visible) {
            Button("diary.window.reload", role: .destructive) { session.reloadLatest() }
            Button("alert.cancel", role: .cancel) {}
        }
    }

    private var toolbar: some View {
        HStack {
            Text(session.entryID == nil ? "diary.window.new" : "tab.diary")
                .font(DaybookType.title)
                .foregroundStyle(DaybookPalette.text.primary)
            Spacer()
            Button(action: onPin) {
                Label(session.isWindowPinned ? "diary.window.unpin" : "diary.window.pin",
                      systemImage: session.isWindowPinned ? "pin.fill" : "pin")
                    .font(DaybookType.caption)
                    .fixedSize()
            }
            .buttonStyle(DaybookButtonStyle(session.isWindowPinned ? .active : .subtle, size: .compact))
            .accessibilityIdentifier("diary.window.pin")
            .accessibilityAddTraits(session.isWindowPinned ? [.isSelected] : [])
        }
    }

    @ViewBuilder private var content: some View {
        if session.issue == .missing {
            Text("diary.window.save.missing")
                .font(DaybookType.body).foregroundStyle(DaybookPalette.text.secondary)
        } else if !session.canRevealContent {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield").font(.system(size: 26)) // token-exempt: display 令牌是 26pt light，这处是默认字重
                Text("diary.private.title").font(DaybookType.body)
                Button("diary.reveal") {
                    PrivacyAccess.perform(requiresUnlock: session.needsUnlock, vault: session.vault) { session.reveal() }
                }
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
            }
            .foregroundStyle(DaybookPalette.text.secondary)
        } else {
            DaybookInputShell(kind: .editor, focused: editorFocused) {
                SyntaxTextEditor(text: $session.text, focused: $editorFocused,
                                 placeholder: L10n.string("diary.quick.placeholder", locale: locale), onSubmit: save,
                                 commandChord: shortcuts.armedChord(for: .commitDiary))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(session.statusKey))
                .font(DaybookType.caption)
                .foregroundStyle(session.issue == nil ? DaybookPalette.text.secondary : DaybookPalette.status.danger)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if session.isSensitive && session.canRevealContent {
                    Button("diary.mask") { session.mask() }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                }
                if let record = session.record, session.canRevealContent {
                    DaybookIconButton(systemName: "photo", label: "diary.attach", size: .compact) {
                        attach(to: record)
                    }
                    DaybookIconButton(systemName: "doc.on.clipboard", label: "row.attach.paste", size: .compact) {
                        paste(to: record)
                    }
                    .accessibilityIdentifier("diary.paste")
                }
                if session.issue == .conflict {
                    Button("diary.window.reload") { confirmsReload = true }
                        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                }
                Spacer(minLength: 0)
                Button("common.save", action: save)
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                    .appShortcut(.saveDiary)
                    .disabled(!session.canSave || !session.canRevealContent)
                    .help("diary.window.save.help")
            }
            .font(DaybookType.caption)
        }
    }

    private func save() {
        PrivacyAccess.perform(requiresUnlock: session.needsUnlock, vault: session.vault) {
            _ = session.save()
            onStateChange()
        }
    }

    private func attach(to entry: DiaryEntry) {
        AttachmentActions.pickDiaryImage(entry, context: session.context, vault: session.vault)
    }

    private func paste(to entry: DiaryEntry) {
        AttachmentActions.pasteDiaryImage(entry, context: session.context, vault: session.vault)
    }
}
