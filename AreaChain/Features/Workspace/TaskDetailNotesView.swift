import AppKit
import SwiftUI

struct TaskDetailNotesView: View {
    @WorkspaceDraftContext private var drafts
    @WorkspaceBoardContext private var boardSelection
    @Environment(\.workspaceHostContext) private var hostContext
    @Environment(\.locale) private var locale
    @Environment(\.workspaceInspectorFocus) private var inspectorFocus
    let draftKey: String
    let notes: String
    let onUpdate: (String) -> Bool

    @State private var draft: String = ""
    @State private var isFocused = false
    @State private var lastSaveAttempt: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            notesHeaderView
            notesEditorBox.zIndex(20)
            notesLinksView
        }
        .onAppear {
            draft = drafts.notes[draftKey] ?? notes
        }
        .onChange(of: notes) { _, newValue in
            if !isFocused && drafts.notes[draftKey] == nil && newValue != draft {
                draft = newValue
            }
        }
        .onDisappear {
            flushLifecycleSave()
        }
    }

    private var notesHeaderView: some View {
        HStack {
            Label("drawer.notes.title", systemImage: "note.text")
                .font(DaybookType.label)
                .foregroundStyle(DaybookPalette.text.secondary)
            Spacer()
            if drafts.notes[draftKey] != nil {
                Text("editor.unsaved")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.status.danger)
                Button("common.save", action: flushSave)
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                    .font(DaybookType.caption)
                    .help("syntax.notes.save.help")
            }
            if !draft.isEmpty {
                Text("drawer.notes.count \(draft.count)")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary.opacity(0.6)) // token-exempt: 60% 次要色没有对应令牌
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
                if lastSaveAttempt != newValue { lastSaveAttempt = nil }
                if newValue != notes { drafts.notes[draftKey] = newValue }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    _ = boardSelection.consumeEscapeCancelsEdits()
                    flushLifecycleSave()
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
                    .font(DaybookType.micro.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.secondary.opacity(0.7)) // token-exempt: 70% 次要色没有对应令牌
                ForEach(links, id: \.self) { url in
                    linkButton(for: url)
                }
            }
            .padding(.top, 2)
        }
    }

    private func linkButton(for url: URL) -> some View {
        DaybookChip(tint: DaybookPalette.accent.base, isSelected: true, action: {
            NSWorkspace.shared.open(url)
        }) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                Text(url.absoluteString)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "arrow.up.right")
            }
        }
    }

    private func flushSave() {
        lastSaveAttempt = draft
        if draft != notes {
            drafts.notes[draftKey] = draft
            if onUpdate(draft) { drafts.notes.removeValue(forKey: draftKey) }
        } else {
            drafts.notes.removeValue(forKey: draftKey)
        }
    }

    private func flushLifecycleSave() {
        if inspectorFocus?.retainsMarkedDraft == true || inspectorFocus?.retainsNavigationDraft == true || hostContext != nil {
            if draft != notes { drafts.notes[draftKey] = draft }
            return
        }
        // 详情收起会先失焦再卸载；同一草稿只尝试一次，失败留待用户显式重试或继续编辑。
        guard lastSaveAttempt != draft else { return }
        flushSave()
    }

    private func extractURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { $0.url }
    }
}
