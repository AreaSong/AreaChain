import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    private var started = false
    private var generation = 0
    private let center = UNUserNotificationCenter.current()

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func start() {
        guard !Self.isRunningTests, !started else { return }
        started = true
        center.delegate = self
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
        scheduleRefresh()
    }

    func scheduleRefresh() {
        guard started else { return }
        generation += 1
        let token = generation
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard token == self.generation else { return }
            await self.refresh()
        }
    }

    func ensureAuthorization() {
        guard !Self.isRunningTests else { return }
        if !started { start() }
        Task { await requestAuthorizationAndRefresh() }
    }

    func currentStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorizationAndRefresh() async {
        guard !Self.isRunningTests else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await refresh()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    private func refresh() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(ReminderPlanning.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        center.removeDeliveredNotifications(withIdentifiers: ours)

        let status = await currentStatus()
        guard status == .authorized || status == .provisional else { return }

        let context = ModelContext(Persistence.session.container)
        let routines = (try? context.fetch(FetchDescriptor<DailyRoutine>())) ?? []
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let checks = (try? context.fetch(FetchDescriptor<RoutineCheck>())) ?? []
        let todayKey = DayClock.shared.todayKey
        let catalog = ReminderPlanning.catalog(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            todayKey: todayKey
        )
        let now = Date()
        for request in catalog {
            guard let fire = ReminderPlanning.nextFireDate(request, now: now) else { continue }
            do {
                try await center.add(notificationRequest(request, fire: fire))
            } catch {
                continue
            }
        }
    }

    private func notificationRequest(_ request: ReminderRequest, fire: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = L10n.string("notify.body", locale: AppPreferences.shared.resolvedLocale)
        content.sound = .default
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fire
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: ReminderPlanning.notificationID(request.id),
            content: content,
            trigger: trigger
        )
    }
}
