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
        let original = TodoSnapshot(id: id, title: "昨天的", isDone: false, dayKey: yesterday)
        let moved = DayBoardLogic.moveTodo(original, to: today)
        let leftover = DayBoardLogic.yesterdayUnfinished(
            routines: [],
            checks: [],
            todos: [moved],
            yesterdayKey: yesterday
        )
        #expect(leftover.isEmpty)
        #expect(DayBoardLogic.todos(for: today, in: [moved]).map(\.id) == [id])
    }

    @Test func diariesNewestFirstAndOnlyThatDay() {
        let older = DiarySnapshot(id: UUID(), text: "早", dayKey: today, createdAt: Date(timeIntervalSince1970: 1))
        let newer = DiarySnapshot(id: UUID(), text: "晚", dayKey: today, createdAt: Date(timeIntervalSince1970: 20))
        let other = DiarySnapshot(id: UUID(), text: "昨天", dayKey: yesterday, createdAt: Date(timeIntervalSince1970: 30))
        let result = DayBoardLogic.diaries(for: today, in: [older, newer, other])
        #expect(result.map(\.text) == ["晚", "早"])
    }
}
