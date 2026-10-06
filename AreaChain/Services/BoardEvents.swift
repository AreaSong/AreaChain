import Foundation

extension Notification.Name {
    static let toggleBoardPopover = Notification.Name("areachain.toggleBoardPopover")
    static let focusCapture = Notification.Name("areachain.focusCapture")
    static let boardDidChange = Notification.Name("areachain.boardDidChange")
    static let hotKeyDidChange = Notification.Name("areachain.hotKeyDidChange")
    static let localPreferenceDidChange = Notification.Name("areachain.localPreferenceDidChange")
    static let appPreferencesDidChange = Notification.Name("areachain.appPreferencesDidChange")
    static let pasteClipboardCapture = Notification.Name("areachain.pasteClipboardCapture")
    static let revealWorkspace = Notification.Name("areachain.revealWorkspace")
    static let showClipboardHistory = Notification.Name("areachain.showClipboardHistory")
    static let focusTimerDidChange = Notification.Name("areachain.focusTimerDidChange")
}

enum BoardEvents {
    struct Dependencies {
        let center: NotificationCenter
        let requestRefresh: (_ includeCalendar: Bool) -> Void

        static var production: Dependencies {
            Dependencies(center: .default) { includeCalendar in
                guard !NotificationScheduler.isRunningTests else { return }
                Task { @MainActor in
                    NotificationScheduler.shared.scheduleRefresh()
                    if includeCalendar { CalendarSync.refreshIfEnabled() }
                }
            }
        }
    }

    static func changed() { changed(dependencies: .production) }

    static func changedLocally() { changedLocally(dependencies: .production) }

    static func changed(dependencies: Dependencies) {
        dependencies.center.post(name: .boardDidChange, object: nil)
        dependencies.requestRefresh(true)
    }

    static func changedLocally(dependencies: Dependencies) {
        dependencies.center.post(name: .boardDidChange, object: nil)
        dependencies.requestRefresh(false)
    }
}
