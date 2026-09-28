import Foundation
import SwiftData
import UserNotifications

@MainActor
protocol ReminderNotificationServing: AnyObject {
    var attachesSystemCenter: Bool { get }
    var authorizationStatus: UNAuthorizationStatus { get async }
    func pendingRecords() async -> [ReminderNotificationRecord]
    func removePending(identifiers: [String])
    func removeDelivered(identifiers: [String])
    func add(_ record: ReminderNotificationRecord) async throws
    func requestAuthorization() async throws -> Bool
    func attachDelegateIfNeeded(_ delegate: UNUserNotificationCenterDelegate)
}

@MainActor
final class SystemReminderNotifications: ReminderNotificationServing {
    let attachesSystemCenter = true
    private let center = UNUserNotificationCenter.current()

    var authorizationStatus: UNAuthorizationStatus {
        get async { await center.notificationSettings().authorizationStatus }
    }

    func pendingRecords() async -> [ReminderNotificationRecord] {
        await center.pendingNotificationRequests().compactMap { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return nil }
            return ReminderNotificationRecord.make(
                identifier: request.identifier,
                title: request.content.title,
                components: trigger.dateComponents
            )
        }
    }

    func removePending(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDelivered(identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func add(_ record: ReminderNotificationRecord) async throws {
        let content = UNMutableNotificationContent()
        content.title = record.title
        content.body = L10n.string("notify.body", locale: AppPreferences.shared.resolvedLocale)
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: record.dateComponents, repeats: false)
        try await center.add(
            UNNotificationRequest(identifier: record.identifier, content: content, trigger: trigger)
        )
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func attachDelegateIfNeeded(_ delegate: UNUserNotificationCenterDelegate) {
        center.delegate = delegate
    }
}

@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    private var started = false
    private var generation = 0
    private let center: any ReminderNotificationServing
    private let contextProvider: () -> ModelContext
    private let now: () -> Date
    private let todayKey: () -> String
    private let calendar: () -> Calendar
    private let debounce: Duration

    private(set) var lastCatalogLoad: ReminderCatalogLoad?
    private(set) var completedRefreshCount = 0
    private(set) var skippedWriteCount = 0
    private(set) var appliedWriteCount = 0

    nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    override convenience init() {
        self.init(center: SystemReminderNotifications())
    }

    init(
        center: any ReminderNotificationServing,
        context: (() -> ModelContext)? = nil,
        now: (() -> Date)? = nil,
        todayKey: (() -> String)? = nil,
        calendar: (() -> Calendar)? = nil,
        debounce: Duration = .milliseconds(80)
    ) {
        self.center = center
        self.contextProvider = context ?? { Persistence.session.container.mainContext }
        self.now = now ?? Date.init
        self.todayKey = todayKey ?? { DayClock.shared.todayKey }
        self.calendar = calendar ?? { Calendar.current }
        self.debounce = debounce
        super.init()
    }

    func start() {
        guard !started else { return }
        if center.attachesSystemCenter, Self.isRunningTests { return }
        started = true
        center.attachDelegateIfNeeded(self)
        if center.attachesSystemCenter {
            NotificationCenter.default.addObserver(
                forName: .NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    DayClock.shared.refresh()
                    self?.scheduleRefresh()
                }
            }
        }
        scheduleRefresh()
    }

    func scheduleRefresh() {
        guard started else { return }
        generation += 1
        let token = generation
        Task {
            try? await Task.sleep(for: debounce)
            guard token == self.generation else { return }
            await self.refresh()
        }
    }

    func refreshNow() async {
        guard started else { return }
        await refresh()
    }

    func ensureAuthorization() {
        guard !(center.attachesSystemCenter && Self.isRunningTests) else { return }
        if !started { start() }
        Task { await requestAuthorizationAndRefresh() }
    }

    func currentStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus
    }

    func requestAuthorizationAndRefresh() async {
        guard !(center.attachesSystemCenter && Self.isRunningTests) else { return }
        do {
            let granted = try await center.requestAuthorization()
            NSLog("[NotificationScheduler] requestAuthorization granted: %d", granted ? 1 : 0)
        } catch {
            let failure = error as NSError
            NSLog(
                "[NotificationScheduler] requestAuthorization FAILED domain=%@ code=%ld",
                failure.domain,
                failure.code
            )
        }
        await refresh()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    private func refresh() async {
        let pending = await center.pendingRecords()
        let ours = pending.filter { $0.identifier.hasPrefix(ReminderPlanning.identifierPrefix) }
        let status = await center.authorizationStatus
        NSLog("[NotificationScheduler] refresh() authorization status: %ld", status.rawValue)
        guard status == .authorized || status == .provisional else {
            NSLog("[NotificationScheduler] refresh() skipped: not authorized (status=%ld)", status.rawValue)
            if ours.isEmpty {
                skippedWriteCount += 1
            } else {
                cancelOurs(ours)
                appliedWriteCount += 1
            }
            completedRefreshCount += 1
            return
        }

        let load = ReminderCatalogStore.load(from: contextProvider(), todayKey: todayKey())
        lastCatalogLoad = load
        NSLog(
            "[NotificationScheduler] found %ld routines, %ld todos, %ld requests in catalog",
            load.routineRows,
            load.todoRows,
            load.requests.count
        )
        let planned = ReminderPlanning.records(catalog: load.requests, now: now(), calendar: calendar())
        if Set(ours) == Set(planned) {
            skippedWriteCount += 1
            completedRefreshCount += 1
            return
        }
        cancelOurs(ours)
        await schedule(planned)
        appliedWriteCount += 1
        completedRefreshCount += 1
    }

    private func cancelOurs(_ ours: [ReminderNotificationRecord]) {
        let identifiers = ours.map(\.identifier)
        guard !identifiers.isEmpty else { return }
        center.removePending(identifiers: identifiers)
        center.removeDelivered(identifiers: identifiers)
    }

    private func schedule(_ planned: [ReminderNotificationRecord]) async {
        for record in planned {
            do {
                try await center.add(record)
                NSLog("[NotificationScheduler] scheduled request id=%@", record.identifier)
            } catch {
                let failure = error as NSError
                NSLog(
                    "[NotificationScheduler] center.add FAILED for id=%@ domain=%@ code=%ld",
                    record.identifier,
                    failure.domain,
                    failure.code
                )
            }
        }
    }
}
