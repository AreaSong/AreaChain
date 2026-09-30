import Foundation
import Testing
@testable import AreaChain

struct ReminderPlanningTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ key: String, hour: Int, minute: Int = 0) -> Date {
        DayKey.date(dayKey: key, minutes: hour * 60 + minute, calendar: utc)!
    }

    @Test func onceFiresLaterTodayAndNotAfter() {
        let request = ReminderRequest(
            id: UUID(),
            title: "修角标",
            remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-07", isDone: false)
        )
        #expect(
            ReminderPlanning.nextFireDate(request, now: date("2026-09-07", hour: 8), calendar: utc)
                == date("2026-09-07", hour: 9)
        )
        #expect(ReminderPlanning.nextFireDate(request, now: date("2026-09-07", hour: 10), calendar: utc) == nil)
    }

    @Test func onceSkipsDoneAndPastDays() {
        let done = ReminderRequest(
            id: UUID(),
            title: "修角标",
            remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-07", isDone: true)
        )
        #expect(ReminderPlanning.nextFireDate(done, now: date("2026-09-07", hour: 8), calendar: utc) == nil)

        let past = ReminderRequest(
            id: UUID(),
            title: "昨天的",
            remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-06", isDone: false)
        )
        #expect(ReminderPlanning.nextFireDate(past, now: date("2026-09-07", hour: 8), calendar: utc) == nil)
    }

    @Test func onceKeepsFutureDay() {
        let request = ReminderRequest(
            id: UUID(),
            title: "明天",
            remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-08", isDone: false)
        )
        #expect(
            ReminderPlanning.nextFireDate(request, now: date("2026-09-07", hour: 22), calendar: utc)
                == date("2026-09-08", hour: 9)
        )
    }

    @Test func residentUsesTomorrowWhenTodayClosedOrPassed() {
        let open = ReminderRequest(
            id: UUID(),
            title: "写日报",
            remindMinutes: 9 * 60,
            kind: .resident(days: WeekdayMask.all, closedToday: false)
        )
        #expect(
            ReminderPlanning.nextFireDate(open, now: date("2026-09-07", hour: 8), calendar: utc)
                == date("2026-09-07", hour: 9)
        )
        #expect(
            ReminderPlanning.nextFireDate(open, now: date("2026-09-07", hour: 10), calendar: utc)
                == date("2026-09-08", hour: 9)
        )

        let closed = ReminderRequest(
            id: UUID(),
            title: "写日报",
            remindMinutes: 9 * 60,
            kind: .resident(days: WeekdayMask.all, closedToday: true)
        )
        #expect(
            ReminderPlanning.nextFireDate(closed, now: date("2026-09-07", hour: 8), calendar: utc)
                == date("2026-09-08", hour: 9)
        )
    }

    @Test func residentWeekdaysSkipWeekend() {
        let request = ReminderRequest(
            id: UUID(),
            title: "写日报",
            remindMinutes: 9 * 60,
            kind: .resident(days: WeekdayMask.workdays, closedToday: false)
        )
        #expect(
            ReminderPlanning.nextFireDate(request, now: date("2026-09-05", hour: 8), calendar: utc)
                == date("2026-09-07", hour: 9)
        )

        let fridayClosed = ReminderRequest(
            id: UUID(),
            title: "写日报",
            remindMinutes: 9 * 60,
            kind: .resident(days: WeekdayMask.workdays, closedToday: true)
        )
        #expect(
            ReminderPlanning.nextFireDate(fridayClosed, now: date("2026-09-04", hour: 10), calendar: utc)
                == date("2026-09-07", hour: 9)
        )
    }

    @Test func residentCustomDaysSkipUnselected() {
        let wednesday = 1 << (4 - 1)
        let request = ReminderRequest(
            id: UUID(),
            title: "周会",
            remindMinutes: 9 * 60,
            kind: .resident(days: wednesday, closedToday: false)
        )
        #expect(
            ReminderPlanning.nextFireDate(request, now: date("2026-09-07", hour: 8), calendar: utc)
                == date("2026-09-09", hour: 9)
        )
        #expect(
            ReminderPlanning.nextFireDate(request, now: date("2026-09-09", hour: 10), calendar: utc)
                == date("2026-09-16", hour: 9)
        )
    }

    @Test func catalogDropsDisabledAndMissingMinutes() {
        let standing = RoutineSnapshot(
            id: UUID(),
            title: "复盘",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            remindMinutes: 8 * 60
        )
        let off = RoutineSnapshot(
            id: UUID(),
            title: "关掉",
            sortOrder: 1,
            isEnabled: false,
            createdDayKey: "2026-09-01",
            remindMinutes: 8 * 60
        )
        let silent = RoutineSnapshot(
            id: UUID(),
            title: "不响",
            sortOrder: 2,
            isEnabled: true,
            createdDayKey: "2026-09-01"
        )
        let todo = TodoSnapshot(
            id: UUID(),
            title: "临时",
            isDone: false,
            dayKey: "2026-09-07",
            remindMinutes: 18 * 60
        )
        let catalog = ReminderPlanning.catalog(
            routines: [standing, off, silent],
            checks: [CheckSnapshot(routineId: standing.id, dayKey: "2026-09-07", isDone: true)],
            todos: [todo],
            todayKey: "2026-09-07"
        )
        #expect(catalog.map(\.title) == ["复盘", "临时"])
        #expect(catalog[0].kind == .resident(days: WeekdayMask.all, closedToday: true))
        #expect(catalog[1].kind == .once(dayKey: "2026-09-07", isDone: false))
    }

    @Test func catalogDropsTrashed() {
        let standing = RoutineSnapshot(
            id: UUID(),
            title: "复盘",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            remindMinutes: 8 * 60,
            deletedAt: Date(timeIntervalSince1970: 9)
        )
        let todo = TodoSnapshot(
            id: UUID(),
            title: "临时",
            isDone: false,
            dayKey: "2026-09-07",
            remindMinutes: 18 * 60,
            deletedAt: Date(timeIntervalSince1970: 9)
        )
        #expect(ReminderPlanning.catalog(routines: [standing], checks: [], todos: [todo], todayKey: "2026-09-07").isEmpty)
    }

    @Test func clampedMinutesRejectOutOfRange() {
        #expect(RemindMinutes.clamped(-1) == nil)
        #expect(RemindMinutes.clamped(0) == 0)
        #expect(RemindMinutes.clamped(1439) == 1439)
        #expect(RemindMinutes.clamped(1440) == nil)
        #expect(RemindMinutes.from(date: date("2026-09-07", hour: 9, minute: 30), calendar: utc) == 9 * 60 + 30)
    }

    @Test func notificationIDUsesStablePrefix() {
        let id = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        #expect(ReminderPlanning.notificationID(id) == "areachain.remind.\(id.uuidString)")
    }

    @Test func recordsDropExpiredAndKeepFutureFire() {
        let open = ReminderRequest(
            id: UUID(),
            title: "修角标",
            remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-07", isDone: false)
        )
        let done = ReminderRequest(
            id: UUID(),
            title: "已完成",
            remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-07", isDone: true)
        )
        let records = ReminderPlanning.records(
            catalog: [open, done],
            now: date("2026-09-07", hour: 8),
            calendar: utc
        )
        #expect(records.count == 1)
        #expect(records[0].identifier == ReminderPlanning.notificationID(open.id))
        #expect(records[0].title == "修角标")
        #expect(records[0].hour == 9)
        #expect(records[0].minute == 0)
        #expect(
            ReminderPlanning.records(
                catalog: [open],
                now: date("2026-09-07", hour: 10),
                calendar: utc
            ).isEmpty
        )
    }

    @Test func catchUpOnceAfterFireAndNotAgain() {
        let id = UUID()
        let request = ReminderRequest(
            id: id,
            title: "补发",
            remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-07", isDone: false)
        )
        let now = date("2026-09-07", hour: 10)
        let first = ReminderPlanning.deliveryRecords(
            catalog: [request], followUps: [:], now: now, todayKey: "2026-09-07", calendar: utc
        )
        #expect(first.issuedCatchUps[id] != nil)
        #expect(first.records.contains { $0.identifier == ReminderPlanning.catchUpID(id, dayKey: "2026-09-07") })
        let kept = ReminderFollowUp(catchUpDayKey: "2026-09-07", catchUpFire: first.issuedCatchUps[id])
        let second = ReminderPlanning.deliveryRecords(
            catalog: [request], followUps: [id: kept], now: now, todayKey: "2026-09-07", calendar: utc
        )
        #expect(second.issuedCatchUps.isEmpty)
        #expect(second.records.contains { $0.identifier == ReminderPlanning.catchUpID(id, dayKey: "2026-09-07") })
    }

    @Test func catchUpSkipsDonePastDayAndSnooze() {
        let done = ReminderRequest(
            id: UUID(), title: "完成", remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-07", isDone: true)
        )
        let past = ReminderRequest(
            id: UUID(), title: "昨天", remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-06", isDone: false)
        )
        let snoozed = ReminderRequest(
            id: UUID(), title: "稍后", remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-07", isDone: false)
        )
        let now = date("2026-09-07", hour: 10)
        #expect(!ReminderPlanning.shouldCatchUp(done, now: now, todayKey: "2026-09-07", calendar: utc))
        #expect(!ReminderPlanning.shouldCatchUp(past, now: now, todayKey: "2026-09-07", calendar: utc))
        let plan = ReminderPlanning.deliveryRecords(
            catalog: [snoozed],
            followUps: [snoozed.id: ReminderFollowUp(snoozeFire: date("2026-09-07", hour: 11))],
            now: now,
            todayKey: "2026-09-07",
            calendar: utc
        )
        #expect(plan.issuedCatchUps.isEmpty)
        #expect(plan.records.contains { $0.identifier == ReminderPlanning.snoozeID(snoozed.id) })
    }

    @Test func catchUpIsNotReissuedAfterItsMinute() throws {
        let id = UUID()
        let request = ReminderRequest(
            id: id, title: "补发", remindMinutes: 9 * 60,
            kind: .once(dayKey: "2026-09-07", isDone: false)
        )
        let first = ReminderPlanning.deliveryRecords(
            catalog: [request], followUps: [:], now: date("2026-09-07", hour: 10),
            todayKey: "2026-09-07", calendar: utc
        )
        let fire = try #require(first.issuedCatchUps[id])
        #expect(fire == date("2026-09-07", hour: 10, minute: 1))
        let identifier = ReminderPlanning.catchUpID(id, dayKey: "2026-09-07")
        let during = ReminderPlanning.deliveryRecords(
            catalog: [request],
            followUps: [id: ReminderFollowUp(catchUpDayKey: "2026-09-07", catchUpFire: fire)],
            now: date("2026-09-07", hour: 10, minute: 1).addingTimeInterval(20),
            todayKey: "2026-09-07",
            calendar: utc
        )
        #expect(during.issuedCatchUps.isEmpty)
        #expect(!during.records.contains { $0.identifier == identifier })
        #expect(during.retainedIDs.contains(identifier))
        let after = ReminderPlanning.deliveryRecords(
            catalog: [request],
            followUps: [id: ReminderFollowUp(catchUpDayKey: "2026-09-07", catchUpFire: fire)],
            now: date("2026-09-07", hour: 10, minute: 2),
            todayKey: "2026-09-07",
            calendar: utc
        )
        #expect(after.issuedCatchUps.isEmpty)
        #expect(!after.retainedIDs.contains(identifier))
    }
}
