import EventKit
import Foundation

@MainActor
enum CalendarSync {
    static let calendarTitle = "AreaChain"

    private static let client = EventKitCalendarClient()
    private static var prefsObserver: NSObjectProtocol?
    private static var eventObserver: NSObjectProtocol?
    private static let coordinator = CalendarSyncCoordinator(
        engine: CalendarSyncEngine(
            client: client,
            local: CalendarSyncStorage.local(context: Persistence.session.container.mainContext, didSave: BoardEvents.changedLocally),
            ledger: CalendarSyncStorage.ledger(),
            isHealthy: { !Persistence.session.isFallback && Persistence.session.openError == nil }
        ),
        enabled: { AppPreferences.shared.syncCalendarEvents },
        publish: { CalendarSyncStatus.shared.apply($0) }
    )

    static func start() {
        guard !isTestProcess, prefsObserver == nil else { return }
        prefsObserver = NotificationCenter.default.addObserver(
            forName: .appPreferencesDidChange, object: nil, queue: .main
        ) { _ in Task { @MainActor in applyPreference() } }
        applyPreference()
    }

    static func refreshIfEnabled() {
        guard !isTestProcess, AppPreferences.shared.syncCalendarEvents else { return }
        coordinator.request()
    }

    private static var isTestProcess: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static func applyPreference() {
        guard AppPreferences.shared.syncCalendarEvents else {
            if let eventObserver {
                NotificationCenter.default.removeObserver(eventObserver)
                self.eventObserver = nil
            }
            coordinator.stop()
            return
        }
        if eventObserver == nil {
            eventObserver = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: client.notificationSource, queue: .main
            ) { _ in
                // 自己提交产生的通知也进入合并队列；无变化的下一轮不会重复写入。
                Task { @MainActor in refreshIfEnabled() }
            }
        }
        coordinator.request()
    }
}
