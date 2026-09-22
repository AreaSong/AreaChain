import AppKit
import SwiftUI

struct TaskDetailNotesView: View {
    @Environment(\.locale) private var locale
    let draftKey: String
    let notes: String
    let onUpdate: (String) -> Bool

    @State private var draft: String = ""
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            notesHeaderView
            notesEditorBox.zIndex(20)
            notesLinksView
        }
        .onAppear {
            draft = EditDrafts.shared.notes[draftKey] ?? notes
        }
        .onChange(of: notes) { _, newValue in
            if !isFocused && EditDrafts.shared.notes[draftKey] == nil && newValue != draft {
                draft = newValue
            }
        }
        .onDisappear {
            flushSave()
        }
    }

    private var notesHeaderView: some View {
        HStack {
            Label("drawer.notes.title", systemImage: "note.text")
                .font(DaybookType.label)
                .foregroundStyle(DaybookTheme.muted)
            Spacer()
            if EditDrafts.shared.notes[draftKey] != nil {
                Text("editor.unsaved")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookTheme.destructive)
                Button("common.save", action: flushSave)
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                    .font(DaybookType.caption)
                    .help("syntax.notes.save.help")
            }
            if !draft.isEmpty {
                Text("drawer.notes.count \(draft.count)")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.6))
            }
        }
    }

    private var notesEditorBox: some View {
        DaybookInputShell(kind: .editor, focused: isFocused) {
            SyntaxTextEditor(
                text: $draft, focused: $isFocused, placeholder: L10n.string("drawer.notes.placeholder", locale: locale),
                fontSize: 11, context: .capture, onSubmit: flushSave
            )
            .frame(minHeight: 56, maxHeight: 150)
            .onChange(of: draft) { _, newValue in
                if newValue != notes { EditDrafts.shared.notes[draftKey] = newValue }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    _ = BoardSelection.shared.consumeEscapeCancelsEdits()
                    flushSave()
                }
            }
        }
    }

    @ViewBuilder
    private var notesLinksView: some View {
        let links = extractURLs(from: draft)
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("drawer.notes.links")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7))
                ForEach(links, id: \.self) { url in
                    linkButton(for: url)
                }
            }
            .padding(.top, 2)
        }
    }

    private func linkButton(for url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 9))
                Text(url.absoluteString)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
            }
            .foregroundStyle(DaybookTheme.stamp)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DaybookTheme.stamp.opacity(0.08))
            )
        }
        .buttonStyle(.plain) // control: 备注链接芯片，P5 迁 DaybookChip
    }

    private func flushSave() {
        if draft != notes {
            EditDrafts.shared.notes[draftKey] = draft
            if onUpdate(draft) { EditDrafts.shared.notes.removeValue(forKey: draftKey) }
        } else {
            EditDrafts.shared.notes.removeValue(forKey: draftKey)
        }
    }

    private func extractURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { $0.url }
    }
}
