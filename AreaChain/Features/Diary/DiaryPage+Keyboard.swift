import AppKit
import SwiftUI

extension DiaryPage {
    func setupKeyMonitor() {
        keyMonitor = BoardKeyMonitor.install(existing: keyMonitor) { event in
            self.handleListKeyDown(event)
        }
    }

    func tearDownKeyMonitor() {
        BoardKeyMonitor.remove(keyMonitor)
        keyMonitor = nil
    }

    func handleListKeyDown(_ event: NSEvent) -> NSEvent? {
        guard !showsPageHeader else { return event }
        guard event.window === hostWindow || (event.window == nil && NSApp.keyWindow === hostWindow) else { return event }
        let firstResponder = NSApp.keyWindow?.firstResponder
        if (firstResponder as? NSTextView)?.isEditable == true || firstResponder is NSControl {
            return event
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if handleNavigationKey(event, modifiers: modifiers) { return nil }
        if handleActionKey(event, modifiers: modifiers) { return nil }

        return event
    }

    private func handleNavigationKey(_ event: NSEvent, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard modifiers.isEmpty else { return false }
        if event.keyCode == 126 {
            navigateSelection(delta: -1)
            return true
        }
        if event.keyCode == 125 {
            navigateSelection(delta: 1)
            return true
        }
        if event.keyCode == 53, selectedEntryID != nil {
            selectedEntryID = nil
            return true
        }
        return false
    }

    private func handleActionKey(_ event: NSEvent, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let selectedEntryID, let entry = filteredEntries.first(where: { $0.id == selectedEntryID }) else {
            return false
        }
        let isOpen = (event.keyCode == 36 && modifiers.isEmpty) || (modifiers == .command && event.charactersIgnoringModifiers?.lowercased() == "o")
        if isOpen {
            DiaryWindows.shared.open(entry: entry, context: modelContext)
            return true
        }
        let isDelete = (event.keyCode == 51 && modifiers.isEmpty) || (modifiers == .command && event.keyCode == 51)
        if isDelete {
            requestTrash(entry)
            return true
        }
        if modifiers == .command && event.charactersIgnoringModifiers?.lowercased() == "c" {
            copyEntry(entry)
            return true
        }
        return false
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
