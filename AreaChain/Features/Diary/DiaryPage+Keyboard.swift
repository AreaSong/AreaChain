import AppKit
import SwiftUI

extension DiaryPage {
    func setupKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleListKeyDown(event)
        }
    }

    func tearDownKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    func handleListKeyDown(_ event: NSEvent) -> NSEvent? {
        guard !showsPageHeader else { return event }
        guard event.window === hostWindow || (event.window == nil && NSApp.keyWindow === hostWindow) else { return event }
        let firstResponder = NSApp.keyWindow?.firstResponder
        let isEditing = (firstResponder as? NSTextView)?.isEditable == true
        if isEditing { return event }
        if firstResponder is NSControl { return event }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])

        // 126: Up Arrow
        if event.keyCode == 126 && modifiers.isEmpty {
            navigateSelection(delta: -1)
            return nil
        }
        // 125: Down Arrow
        if event.keyCode == 125 && modifiers.isEmpty {
            navigateSelection(delta: 1)
            return nil
        }
        // 36: Return or ⌘O: 打开选中手记
        if (event.keyCode == 36 && modifiers.isEmpty) || (modifiers == .command && event.charactersIgnoringModifiers?.lowercased() == "o") {
            if let selectedEntryID, let entry = filteredEntries.first(where: { $0.id == selectedEntryID }) {
                DiaryWindows.shared.open(entry: entry, context: modelContext)
                return nil
            }
        }
        // 51: Delete (⌫) or ⌘⌫: 删除
        if (event.keyCode == 51 && modifiers.isEmpty) || (modifiers == .command && event.keyCode == 51) {
            if let selectedEntryID, let entry = filteredEntries.first(where: { $0.id == selectedEntryID }) {
                requestTrash(entry)
                return nil
            }
        }
        // 53: Escape: 清空选中
        if event.keyCode == 53 && modifiers.isEmpty {
            if selectedEntryID != nil {
                selectedEntryID = nil
                return nil
            }
        }
        // ⌘C: 复制选中手记正文
        if modifiers == .command && event.charactersIgnoringModifiers?.lowercased() == "c" {
            if let selectedEntryID, let entry = filteredEntries.first(where: { $0.id == selectedEntryID }) {
                copyEntry(entry)
                return nil
            }
        }

        return event
    }

    private func navigateSelection(delta: Int) {
        let entries = filteredEntries
        guard !entries.isEmpty else { return }
        guard let currentID = selectedEntryID,
              let currentIndex = entries.firstIndex(where: { $0.id == currentID }) else {
            selectedEntryID = entries.first?.id
            return
        }
        let targetIndex = currentIndex + delta
        if entries.indices.contains(targetIndex) {
            selectedEntryID = entries[targetIndex].id
        }
    }

    private func copyEntry(_ entry: DiaryEntry) {
        let isSensitive = DiaryPrivacy.isSensitive(entry.snapshot, tags: Array(allTags))
        PrivacyAccess.withDiary(entry) { current in
            let text = try DiaryContent.read(current)
            _ = PrivateClipboard.copy(text, sensitive: current.hasProtectedContent || isSensitive)
        }
    }
}
