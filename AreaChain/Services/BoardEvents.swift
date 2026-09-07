import Foundation

extension Notification.Name {
    static let toggleBoardPopover = Notification.Name("areachain.toggleBoardPopover")
    static let focusCapture = Notification.Name("areachain.focusCapture")
    static let boardDidChange = Notification.Name("areachain.boardDidChange")
    static let hotKeyDidChange = Notification.Name("areachain.hotKeyDidChange")
    static let appPreferencesDidChange = Notification.Name("areachain.appPreferencesDidChange")
}

enum BoardEvents {
    static func changed() {
        NotificationCenter.default.post(name: .boardDidChange, object: nil)
        Task { @MainActor in
            NotificationScheduler.shared.scheduleRefresh()
        }
    }
}
