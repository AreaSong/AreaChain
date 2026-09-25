import Foundation
import Testing
@testable import AreaChain

struct AgendaProjectionTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let today = "2026-09-07"
    private let yesterday = "2026-09-06"
    private let tomorrow = "2026-09-08"
    private let nextYear = "2027-01-02"

    private func todo(
        _ title: String,
        day: String,
        done: Bool = false,
        deleted: Bool = false,
        important: Bool = false,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        subtasks: [SubtaskSnapshot] = []
    ) -> TodoSnapshot {
        TodoSnapshot(
            id: UUID(),
            title: title,
            isDone: done,
            dayKey: day,
            createdAt: createdAt,
            deletedAt: deleted ? Date() : nil,
            isImportant: important,
            subtasks: subtasks
        )
    }

    private func routine(
        _ title: String,
        mask: Int = WeekdayMask.all,
        enabled: Bool = true,
        created: String = "2026-09-01",
        deleted: Bool = false,
        sortOrder: Int = 0
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: UUID(),
            title: title,
            sortOrder: sortOrder,
            isEnabled: enabled,
            createdDayKey: created,
            weekdayMask: mask,
            deletedAt: deleted ? Date() : nil
        )
    }

    @Test func todayRangeStaysOnTheCivilDay() {
        let todayTodo = todo("今天", day: today)
        let yesterdayTodo = todo("昨天", day: yesterday)
        let tomorrowTodo = todo("明天", day: tomorrow)
        let done = todo("完成", day: today, done: true)
        let deleted = todo("删除", day: today, deleted: true)
        let open = DayBoardLogic.openTodos(todos: [todayTodo, yesterdayTodo, tomorrowTodo, done, deleted], dayKey: today)
        let completed = DayBoardLogic.completedTodos(todos: [todayTodo, yesterdayTodo, tomorrowTodo, done, deleted], dayKey: today)
        #expect(open.map(\.title) == ["今天"])
        #expect(completed.map(\.title) == ["完成"])
    }

    @Test func dueRoutineJoinsTodayAndUnscheduledDoesNot() {
        let daily = routine("每天")
        let weekend = routine("周末", mask: 1 | 64)
        let deleted = routine("已删", deleted: true)
        let due = DayBoardLogic.routines(for: today, in: [daily, weekend, deleted])
        #expect(due.map(\.title) == ["每天"])
        let done = CheckSnapshot(routineId: daily.id, dayKey: today, isDone: true)
        let open = DayBoardLogic.openRoutines(routines: [daily], checks: [done], dayKey: today)
        let completed = DayBoardLogic.completedRoutines(routines: [daily], checks: [done], dayKey: today)
        #expect(open.isEmpty)
        #expect(completed.map(\.id) == [daily.id])
    }

    @Test func oneOffProgressIgnoresRoutinesWhileBadgeKeepsThem() {
        let daily = routine("每天")
        let open = todo("待办", day: today)
        let ring = DayBoardLogic.todayOneOffProgress(todos: [open], dayKey: today)
        let badge = DayBoardLogic.todayBadgeCount(
            routines: [daily], checks: [], todos: [open], dayKey: today
        )
        #expect(ring.completed == 0)
        #expect(ring.total == 1)
        #expect(badge == 2)
    }

    @Test func pendingTodosUseDayKeyAndStayStableAcrossYearBoundary() {
        let early = todo("年初", day: "2026-01-01", createdAt: Date(timeIntervalSince1970: 5))
        let late = todo("跨年", day: nextYear, important: true, createdAt: Date(timeIntervalSince1970: 9))
        let nearer = todo("明天普通", day: tomorrow, createdAt: Date(timeIntervalSince1970: 1))
        let todayTodo = todo("今天", day: today)
        let done = todo("完成", day: yesterday, done: true)
        let deleted = todo("删除", day: yesterday, deleted: true)
        let invalid = todo("坏日期", day: "not-a-day")
        let overdue = AgendaProjection.overdueTodos(
            todos: [late, early, todayTodo, done, deleted, invalid], todayKey: today, calendar: calendar
        )
        let upcoming = AgendaProjection.upcomingTodos(
            todos: [late, nearer, todayTodo, done], todayKey: today, calendar: calendar
        )
        #expect(overdue.map(\.title) == ["年初"])
        #expect(upcoming.map(\.title) == ["明天普通", "跨年"])
        #expect(!overdue.contains { $0.dayKey == today })
        #expect(!upcoming.contains { $0.dayKey == today })
    }

    @Test func overdueRoutinesCollapseToTheLatestOpenDay() {
        let daily = routine("每天", mask: WeekdayMask.all)
        let weekends = routine("周末", mask: 1 | 64, created: "2026-09-01")
        let skipped = routine("跳过", created: yesterday)
        let done = routine("完成", created: yesterday)
        let paused = routine("停用", enabled: false)
        let weekdayCreatedSunday = routine("周日才创建", mask: WeekdayMask.workdays, created: yesterday)
        let deleted = routine("删除", deleted: true)
        let checks = [
            CheckSnapshot(routineId: skipped.id, dayKey: yesterday, isDone: true, isSkipped: true),
            CheckSnapshot(routineId: done.id, dayKey: yesterday, isDone: true)
        ]
        let rows = AgendaProjection.overdueRoutines(
            routines: [daily, weekends, skipped, done, paused, deleted, weekdayCreatedSunday],
            checks: checks,
            todayKey: today,
            calendar: calendar
        )
        let dailyRow = rows.first { $0.routineID == daily.id }
        #expect(dailyRow?.displayDayKey == yesterday)
        #expect((dailyRow?.openCount ?? 0) > 1)
        #expect(rows.contains { $0.routineID == skipped.id } == false)
        #expect(rows.contains { $0.routineID == done.id } == false)
        #expect(rows.contains { $0.routineID == paused.id } == false)
        #expect(rows.contains { $0.routineID == deleted.id } == false)
        #expect(rows.contains { $0.routineID == weekdayCreatedSunday.id } == false)
        let projection = AgendaProjection.pending(
            routines: [daily], checks: [], todos: [], todayKey: today, calendar: calendar
        )
        #expect(projection.upcoming.contains { $0.modelID == daily.id } == false || projection.overdue.contains { $0.modelID == daily.id })
        let todayDue = DayBoardLogic.isRoutineDue(daily, on: today)
        #expect(todayDue)
        #expect(projection.upcoming.allSatisfy { $0.dayKey > today })
    }

    @Test func upcomingRoutineUsesTheNextScheduledDay() {
        let workdays = routine("工作日", mask: WeekdayMask.workdays)
        let next = AgendaProjection.nextDay(after: today, routine: workdays, calendar: calendar)
        #expect(next == tomorrow)
        let rows = AgendaProjection.upcomingRoutines(routines: [workdays], todayKey: today, calendar: calendar)
        #expect(rows.map(\.displayDayKey) == [tomorrow])
        let disabled = routine("停", enabled: false)
        #expect(AgendaProjection.upcomingRoutines(routines: [disabled], todayKey: today, calendar: calendar).isEmpty)
    }

    @Test func overdueRoutineCheckDayIsTheDisplayedDay() {
        let daily = routine("每天")
        let projection = AgendaProjection.pending(
            routines: [daily], checks: [], todos: [], todayKey: today, calendar: calendar
        )
        let row = projection.overdue.first { $0.modelID == daily.id }
        #expect(row?.dayKey == yesterday)
    }

    @Test func laneDefaultsToOverdueUntilTheUserChooses() {
        var session = PendingLaneSession(overdueCount: 2)
        #expect(session.lane == .overdue)
        session.refreshDefault(overdueCount: 0)
        #expect(session.lane == .upcoming)
        session.choose(.overdue)
        session.refreshDefault(overdueCount: 0)
        #expect(session.lane == .overdue)
        #expect(PendingLanePolicy.initial(overdueCount: 0) == .upcoming)
    }

    @Test func mixedBatchOnlyKeepsSharedActions() {
        let item = todo("一次", day: yesterday)
        let habit = routine("重复")
        let mixed = AgendaProjection.capability(
            ids: [item.id, habit.id], todos: [item], routines: [habit], todayKey: today
        )
        #expect(mixed.kind == .mixed)
        #expect(!mixed.canReschedule)
        #expect(!mixed.canComplete)
        #expect(mixed.canTag)
        #expect(mixed.canTrash)
        #expect(mixed.noteKey == "items.batch.mixed")
        let onlyTodos = AgendaProjection.capability(ids: [item.id], todos: [item], routines: [habit], todayKey: today)
        #expect(onlyTodos.canReschedule)
        #expect(onlyTodos.canComplete)
    }
}
