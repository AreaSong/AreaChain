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
}
