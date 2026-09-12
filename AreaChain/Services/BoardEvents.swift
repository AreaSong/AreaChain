import Foundation

extension Notification.Name {
    static let toggleBoardPopover = Notification.Name("areachain.toggleBoardPopover")
    static let focusCapture = Notification.Name("areachain.focusCapture")
    static let boardDidChange = Notification.Name("areachain.boardDidChange")
    static let hotKeyDidChange = Notification.Name("areachain.hotKeyDidChange")
    static let appPreferencesDidChange = Notification.Name("areachain.appPreferencesDidChange")
    static let pasteClipboardCapture = Notification.Name("areachain.pasteClipboardCapture")
    static let focusTimerDidChange = Notification.Name("areachain.focusTimerDidChange")
}

enum BoardEvents {
    static func changed() {
        notifyUI()
        guard !NotificationScheduler.isRunningTests else { return }
        Task { @MainActor in
            NotificationScheduler.shared.scheduleRefresh()
            CalendarSync.refreshIfEnabled()
        }
    }

    static func changedLocally() {
        notifyUI()
        guard !NotificationScheduler.isRunningTests else { return }
        Task { @MainActor in
            NotificationScheduler.shared.scheduleRefresh()
        }
    }

    private static func notifyUI() {
        NotificationCenter.default.post(name: .boardDidChange, object: nil)
    }
}
