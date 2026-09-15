import AppKit
import SwiftData
import SwiftUI

struct DiaryWindowView: View {
    @Bindable var session: DiaryEditorSession
    var onPin: () -> Void
    var onStateChange: () -> Void = {}
    @Environment(\.locale) private var locale
    @Query private var attachments: [AttachmentItem]
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
        .background(DaybookTheme.paper)
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
                .foregroundStyle(DaybookTheme.ink)
            Spacer()
            Button(action: onPin) {
                Label(session.isWindowPinned ? "diary.window.unpin" : "diary.window.pin",
                      systemImage: session.isWindowPinned ? "pin.fill" : "pin")
                    .font(DaybookType.caption)
                    .fixedSize()
            }
            .buttonStyle(.bordered)
            .tint(session.isWindowPinned ? DaybookTheme.stamp : DaybookTheme.muted)
            .accessibilityIdentifier("diary.window.pin")
            .accessibilityAddTraits(session.isWindowPinned ? [.isSelected] : [])
        }
    }

    @ViewBuilder private var content: some View {
        if session.issue == .missing {
            Text("diary.window.save.missing")
                .font(DaybookType.body).foregroundStyle(DaybookTheme.muted)
        } else if !session.canRevealContent {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield").font(.system(size: 26))
                Text("diary.private.title").font(DaybookType.body)
                Button("diary.reveal") {
                    PrivacyAccess.perform(requiresUnlock: session.needsUnlock, vault: session.vault) { session.reveal() }
                }
                    .buttonStyle(.bordered)
                    .foregroundStyle(DaybookTheme.stamp)
            }
            .foregroundStyle(DaybookTheme.muted)
        } else {
            SyntaxTextEditor(text: $session.text, focused: $editorFocused,
                             placeholder: L10n.string("diary.quick.placeholder", locale: locale), onSubmit: save)
                .padding(8)
                .background(DaybookTheme.surface, in: RoundedRectangle(cornerRadius: DaybookRadius.small))
                .overlay(RoundedRectangle(cornerRadius: DaybookRadius.small)
                    .strokeBorder(editorFocused ? DaybookTheme.focusRing : DaybookTheme.rule, lineWidth: 1))
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(session.statusKey))
                .font(DaybookType.caption)
                .foregroundStyle(session.issue == nil ? DaybookTheme.muted : DaybookTheme.destructive)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if session.isSensitive && session.canRevealContent {
                    Button("diary.mask") { session.mask() }
                    .buttonStyle(.plain)
                }
                if let record = session.record, session.canRevealContent {
                    Button { attach(to: record) } label: { Image(systemName: "photo") }
                        .buttonStyle(.plain).accessibilityLabel("diary.attach").help("diary.attach")
                }
                if session.issue == .conflict {
                    Button("diary.window.reload") { confirmsReload = true }
                        .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                Button("common.save", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!session.canSave || !session.canRevealContent)
                    .help("diary.window.save.help")
            }
            .font(DaybookType.caption)
            .foregroundStyle(DaybookTheme.stamp)
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
}
