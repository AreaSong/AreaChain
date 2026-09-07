import Foundation
import Testing
@testable import AreaChain

struct DayBoardLogicTests {
    private let today = "2026-09-07"
    private let yesterday = "2026-09-06"

    private var morningPages: RoutineSnapshot {
        RoutineSnapshot(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "写日报",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01"
        )
    }

    private var review: RoutineSnapshot {
        RoutineSnapshot(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "复盘",
            sortOrder: 1,
            isEnabled: true,
            createdDayKey: "2026-09-01"
        )
    }

    @Test func badgeCountsOpenRoutinesAndTodos() {
        let todos = [
            TodoSnapshot(id: UUID(), title: "修导出", isDone: false, dayKey: today),
            TodoSnapshot(id: UUID(), title: "已做", isDone: true, dayKey: today)
        ]
        let checks = [
            CheckSnapshot(routineId: morningPages.id, dayKey: today, isDone: true)
        ]
        let count = DayBoardLogic.todayBadgeCount(
            routines: [morningPages, review],
            checks: checks,
            todos: todos,
            dayKey: today
        )
        #expect(count == 2)
    }

    @Test func yesterdayUnfinishedDoesNotMixToday() {
        let todos = [
            TodoSnapshot(id: UUID(), title: "昨天的", isDone: false, dayKey: yesterday),
            TodoSnapshot(id: UUID(), title: "今天的", isDone: false, dayKey: today)
        ]
        let leftover = DayBoardLogic.yesterdayUnfinished(
            routines: [morningPages],
            checks: [],
            todos: todos,
            yesterdayKey: yesterday
        )
        #expect(leftover.map(\.title) == ["写日报", "昨天的"])
        #expect(!leftover.contains { $0.title == "今天的" })
    }

    @Test func futureRoutineDoesNotAppearToday() {
        let later = RoutineSnapshot(
            id: UUID(),
            title: "以后才开始",
            sortOrder: 3,
            isEnabled: true,
            createdDayKey: "2026-09-08"
        )
        let due = DayBoardLogic.routines(for: today, in: [later, morningPages])
        #expect(due.map(\.title) == ["写日报"])
    }

    @Test func openListsHideCompleted() {
        let todos = [
            TodoSnapshot(id: UUID(), title: "开", isDone: false, dayKey: today),
            TodoSnapshot(id: UUID(), title: "完", isDone: true, dayKey: today)
        ]
        #expect(DayBoardLogic.openTodos(todos: todos, dayKey: today).map(\.title) == ["开"])
        #expect(DayBoardLogic.completedTodos(todos: todos, dayKey: today).map(\.title) == ["完"])
    }

    @Test func skippedRoutineCountsAsClosed() {
        let checks = [
            CheckSnapshot(routineId: morningPages.id, dayKey: today, isDone: true, isSkipped: true)
        ]
        #expect(DayBoardLogic.isRoutineSkipped(morningPages, checks: checks, on: today))
        #expect(
            DayBoardLogic.todayBadgeCount(
                routines: [morningPages],
                checks: checks,
                todos: [],
                dayKey: today
            ) == 0
        )
    }

    @Test func moveTodoLeavesYesterdayAndJoinsToday() {
        let id = UUID()
        let original = TodoSnapshot(
            id: id,
            title: "昨天的",
            isDone: false,
            dayKey: yesterday,
            createdAt: Date(timeIntervalSince1970: 10),
            remindMinutes: 8 * 60
        )
        let moved = DayBoardLogic.moveTodo(original, to: today)
        let leftover = DayBoardLogic.yesterdayUnfinished(
            routines: [],
            checks: [],
            todos: [moved],
            yesterdayKey: yesterday
        )
        #expect(leftover.isEmpty)
        #expect(DayBoardLogic.todos(for: today, in: [moved]).map(\.id) == [id])
        #expect(moved.remindMinutes == 8 * 60)
        #expect(moved.createdAt == original.createdAt)
    }

    @Test func weekdaysOnlyRoutineSkipsWeekend() {
        let weekdayPages = RoutineSnapshot(
            id: morningPages.id,
            title: morningPages.title,
            sortOrder: morningPages.sortOrder,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.workdays
        )
        #expect(DayBoardLogic.routines(for: "2026-09-07", in: [weekdayPages]).map(\.title) == ["写日报"])
        #expect(DayBoardLogic.routines(for: "2026-09-06", in: [weekdayPages]).isEmpty)
        #expect(DayBoardLogic.todayBadgeCount(
            routines: [weekdayPages],
            checks: [],
            todos: [],
            dayKey: "2026-09-06"
        ) == 0)
        #expect(DayBoardLogic.yesterdayUnfinished(
            routines: [weekdayPages],
            checks: [],
            todos: [],
            yesterdayKey: "2026-09-06"
        ).isEmpty)
    }

    @Test func customWeekdaysAppearOnlyOnSelectedDays() {
        let wednesdayOnly = RoutineSnapshot(
            id: morningPages.id,
            title: morningPages.title,
            sortOrder: morningPages.sortOrder,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            weekdayMask: 1 << (4 - 1)
        )
        #expect(DayBoardLogic.routines(for: "2026-09-09", in: [wednesdayOnly]).map(\.title) == ["写日报"])
        #expect(DayBoardLogic.routines(for: "2026-09-07", in: [wednesdayOnly]).isEmpty)
        #expect(DayBoardLogic.routines(for: "2026-09-06", in: [wednesdayOnly]).isEmpty)
        #expect(
            DayBoardLogic.todayBadgeCount(
                routines: [wednesdayOnly],
                checks: [],
                todos: [],
                dayKey: "2026-09-07"
            ) == 0
        )
    }

    @Test func moveTodoCanLandOnAnyDay() {
        let original = TodoSnapshot(id: UUID(), title: "预约", isDone: false, dayKey: today)
        let moved = DayBoardLogic.moveTodo(original, to: "2026-09-10")
        #expect(DayBoardLogic.todos(for: today, in: [moved]).isEmpty)
        #expect(DayBoardLogic.todos(for: "2026-09-10", in: [moved]).map(\.title) == ["预约"])
    }

    @Test func upcomingTodosSkipTodayAndDoneAndSortByDay() {
        let todos = [
            TodoSnapshot(id: UUID(), title: "今天的", isDone: false, dayKey: today),
            TodoSnapshot(id: UUID(), title: "后天", isDone: false, dayKey: "2026-09-09"),
            TodoSnapshot(id: UUID(), title: "明天", isDone: false, dayKey: "2026-09-08"),
            TodoSnapshot(id: UUID(), title: "已勾的明天", isDone: true, dayKey: "2026-09-08"),
            TodoSnapshot(id: UUID(), title: "昨天的", isDone: false, dayKey: yesterday)
        ]
        #expect(DayBoardLogic.upcomingTodos(todos: todos, todayKey: today).map(\.title) == ["明天", "后天"])
        #expect(
            DayBoardLogic.todayBadgeCount(
                routines: [],
                checks: [],
                todos: todos,
                dayKey: today
            ) == 1
        )
    }

    @Test func diariesNewestFirstAndOnlyThatDay() {
        let older = DiarySnapshot(id: UUID(), text: "早", dayKey: today, createdAt: Date(timeIntervalSince1970: 1))
        let newer = DiarySnapshot(id: UUID(), text: "晚", dayKey: today, createdAt: Date(timeIntervalSince1970: 20))
        let other = DiarySnapshot(id: UUID(), text: "昨天", dayKey: yesterday, createdAt: Date(timeIntervalSince1970: 30))
        let result = DayBoardLogic.diaries(for: today, in: [older, newer, other])
        #expect(result.map(\.text) == ["晚", "早"])
    }

    @Test func trashedItemsLeaveTheBoard() {
        let trashedStanding = RoutineSnapshot(
            id: UUID(),
            title: "旧常驻",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            deletedAt: Date(timeIntervalSince1970: 9)
        )
        let trashedTodo = TodoSnapshot(
            id: UUID(),
            title: "旧临时",
            isDone: false,
            dayKey: today,
            deletedAt: Date(timeIntervalSince1970: 9)
        )
        #expect(DayBoardLogic.routines(for: today, in: [trashedStanding, morningPages]).map(\.title) == ["写日报"])
        #expect(DayBoardLogic.openTodos(todos: [trashedTodo], dayKey: today).isEmpty)
        #expect(
            DayBoardLogic.todayBadgeCount(
                routines: [trashedStanding],
                checks: [],
                todos: [trashedTodo],
                dayKey: today
            ) == 0
        )
        let trashedDiary = DiarySnapshot(
            id: UUID(),
            text: "扔了",
            dayKey: today,
            createdAt: Date(timeIntervalSince1970: 4),
            deletedAt: Date(timeIntervalSince1970: 9)
        )
        #expect(DayBoardLogic.diaries(for: today, in: [trashedDiary]).isEmpty)
        #expect(
            DayBoardLogic.yesterdayUnfinished(
                routines: [trashedStanding],
                checks: [],
                todos: [trashedTodo],
                yesterdayKey: today
            ).isEmpty
        )
    }

    @Test func monthUnfinishedUsesWeekdaysAndTodoDayKey() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let weekdayPages = RoutineSnapshot(
            id: morningPages.id,
            title: morningPages.title,
            sortOrder: morningPages.sortOrder,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.workdays
        )
        let later = TodoSnapshot(
            id: UUID(),
            title: "预约",
            isDone: false,
            dayKey: "2026-09-10"
        )
        let counts = DayBoardLogic.monthUnfinished(
            routines: [weekdayPages],
            checks: [],
            todos: [later],
            containing: "2026-09-07",
            calendar: calendar
        )
        #expect(counts["2026-09-07"] == 1)
        #expect(counts["2026-09-06"] == 0)
        #expect(counts["2026-09-05"] == 0)
        #expect(counts["2026-09-10"] == 2)
        #expect(counts["2026-08-31"] == nil)
        #expect(counts["2026-10-01"] == nil)
    }
}
