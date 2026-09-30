import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import AreaChain

@MainActor
final class FakeReminderNotifications: ReminderNotificationServing {
    let attachesSystemCenter = false
    var status: UNAuthorizationStatus = .authorized
    var pending: [ReminderNotificationRecord] = []
    var delivered: Set<String> = []
    var addCount = 0
    var posted: [PostedBanner] = []
    var removePendingCount = 0
    var removeDeliveredCount = 0
    var pendingQueryCount = 0
    var authorizationCount = 0
    var failingIdentifiers: Set<String> = []
    var authorizationError: Error?

    var authorizationStatus: UNAuthorizationStatus {
        get async { status }
    }

    func pendingRecords() async -> [ReminderNotificationRecord] {
        pendingQueryCount += 1
        return pending
    }

    func removePending(identifiers: [String]) {
        removePendingCount += 1
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func removeDelivered(identifiers: [String]) {
        removeDeliveredCount += 1
        identifiers.forEach { delivered.remove($0) }
    }

    func add(_ record: ReminderNotificationRecord) async throws {
        addCount += 1
        if failingIdentifiers.contains(record.identifier) {
            throw CocoaError(.fileWriteUnknown)
        }
        pending.removeAll { $0.identifier == record.identifier }
        pending.append(record)
    }

    func deliverImmediate(identifier: String, title: String, body: String) async throws {
        if failingIdentifiers.contains(identifier) {
            throw CocoaError(.fileWriteUnknown)
        }
        posted.removeAll { $0.identifier == identifier }
        posted.append(PostedBanner(identifier: identifier, title: title, body: body))
    }

    func requestAuthorization() async throws -> Bool {
        authorizationCount += 1
        if let authorizationError { throw authorizationError }
        return status == .authorized || status == .provisional
    }

    func attachDelegateIfNeeded(_ delegate: UNUserNotificationCenterDelegate) {}

    struct PostedBanner: Equatable {
        var identifier: String
        var title: String
        var body: String
    }
}

@MainActor
struct NotificationSchedulerTests {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var utc: Calendar { Self.utc }
    private var now: Date { DayKey.date(dayKey: "2026-09-28", minutes: 8 * 60, calendar: utc)! }
    private let todayKey = "2026-09-28"

    @Test func catalogFetchSkipsSilentAndHistoricalRows() async throws {
        let container = try container()
        let context = container.mainContext
        for index in 0..<8 {
            context.insert(TodoItem(title: "静音\(index)", dayKey: todayKey))
        }
        context.insert(TodoItem(title: "有提醒", dayKey: todayKey, remindMinutes: 9 * 60))
        context.insert(TodoItem(title: "已删提醒", dayKey: todayKey, remindMinutes: 9 * 60, deletedAt: Date(timeIntervalSince1970: 1)))
        let reminded = DailyRoutine(title: "晨会", sortOrder: 0, createdDayKey: "2026-09-01", remindMinutes: 9 * 60)
        let silent = DailyRoutine(title: "无提醒习惯", sortOrder: 1, createdDayKey: "2026-09-01")
        context.insert(reminded)
        context.insert(silent)
        context.insert(RoutineCheck(dayKey: "2026-09-01", isDone: true, routine: reminded))
        context.insert(RoutineCheck(dayKey: todayKey, isDone: true, routine: reminded))
        context.insert(RoutineCheck(dayKey: todayKey, isDone: true, routine: silent))
        try context.save()

        let center = FakeReminderNotifications()
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)

        let load = try #require(scheduler.lastCatalogLoad)
        #expect(load.fetchCalls == 3)
        #expect(load.todoRows == 1)
        #expect(load.routineRows == 1)
        #expect(load.checkRows == 2)
        #expect(Set(load.requests.map(\.title)) == ["晨会", "有提醒"])
        #expect(center.addCount == 2)
        #expect(Set(center.pending.map(\.title)) == ["晨会", "有提醒"])
    }

    @Test func unchangedCatalogSkipsCancelAndReschedule() async throws {
        let container = try container()
        let todo = TodoItem(title: "核验", dayKey: todayKey, remindMinutes: 9 * 60, notes: "初稿")
        container.mainContext.insert(todo)
        try container.mainContext.save()

        let center = FakeReminderNotifications()
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)
        #expect(center.addCount == 1)
        #expect(scheduler.appliedWriteCount == 1)

        todo.notes = "改备注不改提醒"
        try ModelChanges.transaction(in: container.mainContext) {}
        await scheduler.refreshNow()

        #expect(scheduler.completedRefreshCount == 2)
        #expect(scheduler.skippedWriteCount == 1)
        #expect(center.addCount == 1)
        #expect(center.removePendingCount == 0)
        #expect(center.pending.map(\.title) == ["核验"])
    }

    @Test func consecutiveEditsKeepLastTitleAndCoalesceDebounce() async throws {
        let container = try container()
        let todo = TodoItem(title: "A", dayKey: todayKey, remindMinutes: 9 * 60)
        container.mainContext.insert(todo)
        try container.mainContext.save()

        let center = FakeReminderNotifications()
        let scheduler = makeScheduler(container: container, center: center)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)
        let firstAdds = center.addCount

        let started = ContinuousClock.now
        todo.title = "B"
        scheduler.scheduleRefresh()
        todo.title = "C"
        scheduler.scheduleRefresh()
        try await wait(scheduler, refreshes: 2)
        let elapsed = ContinuousClock.now - started

        #expect(scheduler.completedRefreshCount == 2)
        #expect(center.pending.map(\.title) == ["C"])
        #expect(center.addCount == firstAdds + 1)
        #expect(center.removePendingCount == 1)
        #expect(elapsed >= .milliseconds(80))
        #expect(elapsed < .milliseconds(1000))
    }

    @Test func batchTransactionSchedulesOnceForAllReminders() async throws {
        let container = try container()
        let context = container.mainContext
        let first = TodoItem(title: "一批一", dayKey: todayKey, remindMinutes: 9 * 60)
        let second = TodoItem(title: "一批二", dayKey: todayKey, remindMinutes: 10 * 60)
        let center = FakeReminderNotifications()
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)
        #expect(center.addCount == 0)

        try ModelChanges.transaction(in: context) {
            context.insert(first)
            context.insert(second)
        }
        await scheduler.refreshNow()

        #expect(scheduler.completedRefreshCount == 2)
        #expect(scheduler.appliedWriteCount == 1)
        #expect(Set(center.pending.map(\.title)) == ["一批一", "一批二"])
        #expect(center.addCount == 2)
    }

    @Test func failedSaveDoesNotRefreshNotifications() async throws {
        let container = try container()
        let context = container.mainContext
        let todo = TodoItem(title: "原文", dayKey: todayKey, remindMinutes: 9 * 60)
        context.insert(todo)
        try context.save()
        let tasks = SwiftDataTaskRepository(context: context)
        let center = FakeReminderNotifications()
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)
        #expect(center.pending.map(\.title) == ["原文"])
        let refreshes = scheduler.completedRefreshCount
        let adds = center.addCount
        var posts = 0
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: .main) { _ in
            posts += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        #expect(throws: CocoaError.self) {
            try ModelChanges.transaction(in: context, save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                try tasks.updateTodo(id: todo.id, title: "不该发出", notes: nil)
            }
        }
        #expect(posts == 0)
        #expect(todo.title == "原文")
        #expect(scheduler.completedRefreshCount == refreshes)
        #expect(center.addCount == adds)
        #expect(center.pending.map(\.title) == ["原文"])
    }

    @Test func unauthorizedRefreshCancelsPendingAndDoesNotReschedule() async throws {
        let container = try container()
        let todo = TodoItem(title: "待取消", dayKey: todayKey, remindMinutes: 9 * 60)
        container.mainContext.insert(todo)
        try container.mainContext.save()
        let record = try #require(
            ReminderNotificationRecord.make(
                identifier: ReminderPlanning.notificationID(todo.id),
                title: todo.title,
                fire: DayKey.date(dayKey: todayKey, minutes: 9 * 60, calendar: utc)!,
                calendar: utc
            )
        )
        let center = FakeReminderNotifications()
        center.pending = [record]
        center.status = .denied
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)

        #expect(center.addCount == 0)
        #expect(center.removePendingCount == 1)
        #expect(center.pending.isEmpty)
        #expect(scheduler.lastCatalogLoad == nil)
    }

    @Test func addFailureDoesNotBlockOtherRemindersOrReportThemScheduled() async throws {
        let container = try container()
        let failing = TodoItem(title: "失败项", dayKey: todayKey, remindMinutes: 9 * 60)
        let surviving = TodoItem(title: "成功项", dayKey: todayKey, remindMinutes: 10 * 60)
        container.mainContext.insert(failing)
        container.mainContext.insert(surviving)
        try container.mainContext.save()

        let center = FakeReminderNotifications()
        center.failingIdentifiers = [ReminderPlanning.notificationID(failing.id)]
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)

        #expect(center.addCount == 2)
        #expect(center.pending.map(\.title) == ["成功项"])
        #expect(!center.pending.contains { $0.identifier == ReminderPlanning.notificationID(failing.id) })
    }

    @Test func failedAddIsRetriedOnNextRefresh() async throws {
        let container = try container()
        let failing = TodoItem(title: "失败项", dayKey: todayKey, remindMinutes: 9 * 60)
        let surviving = TodoItem(title: "成功项", dayKey: todayKey, remindMinutes: 10 * 60)
        container.mainContext.insert(failing)
        container.mainContext.insert(surviving)
        try container.mainContext.save()

        let center = FakeReminderNotifications()
        center.failingIdentifiers = [ReminderPlanning.notificationID(failing.id)]
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)
        #expect(center.pending.map(\.title) == ["成功项"])

        center.failingIdentifiers = []
        await scheduler.refreshNow()

        #expect(scheduler.completedRefreshCount == 2)
        #expect(Set(center.pending.map(\.title)) == ["失败项", "成功项"])
        #expect(center.addCount == 3)
        #expect(center.removePendingCount == 0)
    }

    @Test func completingReminderCancelsItsPendingRequest() async throws {
        let container = try container()
        let todo = TodoItem(title: "完成即取消", dayKey: todayKey, remindMinutes: 9 * 60)
        container.mainContext.insert(todo)
        try container.mainContext.save()
        let center = FakeReminderNotifications()
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)
        #expect(center.pending.count == 1)

        todo.isDone = true
        try ModelChanges.transaction(in: container.mainContext) {}
        await scheduler.refreshNow()

        #expect(center.pending.isEmpty)
        #expect(center.removePendingCount == 1)
        #expect(scheduler.appliedWriteCount == 2)
    }

    @Test func authorizationErrorStillRefreshesCatalog() async throws {
        let container = try container()
        let todo = TodoItem(title: "仍排程", dayKey: todayKey, remindMinutes: 9 * 60)
        container.mainContext.insert(todo)
        try container.mainContext.save()
        let center = FakeReminderNotifications()
        center.authorizationError = CocoaError(.fileReadNoPermission)
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)
        scheduler.start()
        try await wait(scheduler, refreshes: 1)
        #expect(center.addCount == 1)
        let refreshes = scheduler.completedRefreshCount
        let adds = center.addCount
        await scheduler.requestAuthorizationAndRefresh()
        #expect(center.authorizationCount == 1)
        #expect(scheduler.completedRefreshCount == refreshes + 1)
        #expect(center.addCount == adds)
        #expect(center.pending.map(\.title) == ["仍排程"])
    }

    @Test func issuedCatchUpStaysDeliveredOnLaterRefresh() async throws {
        let suite = "areachain.tests.followup.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReminderFollowUpStore(defaults: defaults)
        let container = try container()
        let todo = TodoItem(title: "补发", dayKey: todayKey, remindMinutes: 9 * 60)
        container.mainContext.insert(todo)
        try container.mainContext.save()
        let center = FakeReminderNotifications()
        let clock = FollowUpClock(DayKey.date(dayKey: todayKey, minutes: 10 * 60, calendar: utc)!)
        let scheduler = NotificationScheduler(
            center: center,
            context: { container.mainContext },
            now: { clock.date },
            todayKey: { self.todayKey },
            calendar: { self.utc },
            debounce: .zero,
            followUps: store
        )
        scheduler.start()
        try await wait(scheduler, refreshes: 1)
        let identifier = ReminderPlanning.catchUpID(todo.id, dayKey: todayKey)
        #expect(center.pending.contains { $0.identifier == identifier })
        center.pending.removeAll { $0.identifier == identifier }
        center.delivered.insert(identifier)
        let adds = center.addCount
        let removed = center.removeDeliveredCount
        clock.date = DayKey.date(dayKey: todayKey, minutes: 10 * 60 + 1, calendar: utc)!.addingTimeInterval(20)
        await scheduler.refreshNow()
        #expect(center.delivered.contains(identifier))
        #expect(!center.pending.contains { $0.identifier == identifier })
        #expect(center.addCount == adds)
        #expect(center.removeDeliveredCount == removed)
    }

    @Test func testBannerPostsImmediatelyWithoutTouchingReminders() async throws {
        let container = try container()
        let center = FakeReminderNotifications()
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)

        let outcome = await scheduler.deliverTestBanner(title: "AreaChain", body: "这是一条测试通知。")

        let banner = try #require(center.posted.first)
        #expect(outcome == .delivered)
        #expect(center.posted.count == 1)
        #expect(banner.identifier == NotificationScheduler.testBannerIdentifier)
        #expect(banner.title == "AreaChain")
        #expect(banner.body == "这是一条测试通知。")
        #expect(ReminderPlanning.itemID(from: banner.identifier) == nil)
        #expect(center.addCount == 0)
        #expect(scheduler.completedRefreshCount == 1)
    }

    @Test func deniedTestBannerLeavesExistingReminders() async throws {
        let container = try container()
        let center = FakeReminderNotifications()
        center.status = .denied
        let reminder = ReminderNotificationRecord(
            identifier: ReminderPlanning.notificationID(UUID()),
            title: "已有提醒",
            year: 2026,
            month: 9,
            day: 28,
            hour: 9,
            minute: 0
        )
        center.pending = [reminder]
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)

        let outcome = await scheduler.deliverTestBanner(title: "AreaChain", body: "这是一条测试通知。")

        #expect(outcome == .notAuthorized)
        #expect(center.posted.isEmpty)
        #expect(center.pending == [reminder])
        #expect(center.removePendingCount == 0)
        #expect(scheduler.completedRefreshCount == 0)
    }

    @Test func failedTestBannerDoesNotClaimDelivery() async throws {
        let container = try container()
        let center = FakeReminderNotifications()
        center.failingIdentifiers = [NotificationScheduler.testBannerIdentifier]
        let scheduler = makeScheduler(container: container, center: center, debounce: .zero)

        let outcome = await scheduler.deliverTestBanner(title: "AreaChain", body: "这是一条测试通知。")

        #expect(outcome == .failed)
        #expect(center.posted.isEmpty)
        #expect(scheduler.completedRefreshCount == 0)
    }

    private final class FollowUpClock {
        var date: Date
        init(_ date: Date) { self.date = date }
    }

    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeScheduler(
        container: ModelContainer,
        center: FakeReminderNotifications,
        debounce: Duration = .milliseconds(80)
    ) -> NotificationScheduler {
        NotificationScheduler(
            center: center,
            context: { container.mainContext },
            now: { now },
            todayKey: { todayKey },
            calendar: { utc },
            debounce: debounce
        )
    }

    private func wait(_ scheduler: NotificationScheduler, refreshes: Int) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while scheduler.completedRefreshCount < refreshes, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(scheduler.completedRefreshCount >= refreshes)
    }
}
