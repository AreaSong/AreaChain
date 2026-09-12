import Foundation
import Testing
@testable import AreaChain

struct MenuBarStatusTests {
    private let today = "2026-09-12"

    @Test func emptyDayAndCompletedDayHaveDifferentStates() {
        #expect(MenuBarStatus.forDay(routines: [], checks: [], todos: [], dayKey: today) == .empty)
        let done = TodoSnapshot(id: UUID(), title: "已处理", isDone: true, dayKey: today)
        #expect(MenuBarStatus.forDay(routines: [], checks: [], todos: [done], dayKey: today) == .completed)
    }

    @Test func remainingCountUsesTheSameTodoAndHabitScopeAsTheBoard() {
        let routine = RoutineSnapshot(id: UUID(), title: "阅读", sortOrder: 0, isEnabled: true, createdDayKey: today)
        let todo = TodoSnapshot(id: UUID(), title: "整理材料", isDone: false, dayKey: today)
        #expect(MenuBarStatus.forDay(routines: [routine], checks: [], todos: [todo], dayKey: today) == .remaining(2))
        let checks = [CheckSnapshot(routineId: routine.id, dayKey: today, isDone: true)]
        #expect(MenuBarStatus.forDay(routines: [routine], checks: checks, todos: [todo], dayKey: today) == .remaining(1))
        var done = todo
        done.isDone = true
        #expect(MenuBarStatus.forDay(routines: [routine], checks: checks, todos: [done], dayKey: today) == .completed)
    }

    @Test func skippedHabitIsHandledButAnUnscheduledHabitDoesNotCount() {
        let routine = RoutineSnapshot(id: UUID(), title: "阅读", sortOrder: 0, isEnabled: true, createdDayKey: today)
        let checks = [CheckSnapshot(routineId: routine.id, dayKey: today, isDone: true, isSkipped: true)]
        #expect(MenuBarStatus.forDay(routines: [routine], checks: checks, todos: [], dayKey: today) == .completed)
        var weekdays = routine
        weekdays.weekdayMask = WeekdayMask.workdays
        #expect(MenuBarStatus.forDay(routines: [weekdays], checks: [], todos: [], dayKey: today) == .empty)
        var paused = routine
        paused.isEnabled = false
        #expect(MenuBarStatus.forDay(routines: [paused], checks: [], todos: [], dayKey: today) == .empty)
    }

    @Test func otherDatesAndDeletedItemsCannotImplyCompletionToday() {
        let todos = [
            TodoSnapshot(id: UUID(), title: "昨天", isDone: true, dayKey: "2026-09-11"),
            TodoSnapshot(id: UUID(), title: "明天", isDone: false, dayKey: "2026-09-13"),
            TodoSnapshot(id: UUID(), title: "已删", isDone: true, dayKey: today, deletedAt: .now)
        ]
        let routine = RoutineSnapshot(
            id: UUID(), title: "已删习惯", sortOrder: 0, isEnabled: true, createdDayKey: today, deletedAt: .now
        )
        #expect(MenuBarStatus.forDay(routines: [routine], checks: [], todos: todos, dayKey: today) == .empty)
    }

    @Test func largeCountsRemainExactInTheStateAndDescriptions() {
        let todos = (0..<125).map { _ in TodoSnapshot(id: UUID(), title: "待办", isDone: false, dayKey: today) }
        #expect(MenuBarStatus.forDay(routines: [], checks: [], todos: todos, dayKey: today) == .remaining(125))
        #expect(MenuBarStatus.remaining(125).accessibilityLabel(locale: Locale(identifier: "zh-Hans")) == "AreaChain，今天还剩 125 条")
        #expect(MenuBarStatus.remaining(125).accessibilityLabel(locale: Locale(identifier: "en")) == "AreaChain, 125 left today")
    }

    @Test func zeroStatesHaveDistinctLocalizedDescriptions() {
        let zh = Locale(identifier: "zh-Hans")
        let en = Locale(identifier: "en")
        #expect(MenuBarStatus.empty.accessibilityLabel(locale: zh) == "AreaChain，今天暂无安排")
        #expect(MenuBarStatus.completed.accessibilityLabel(locale: zh) == "AreaChain，今日事项已全部处理")
        #expect(MenuBarStatus.empty.accessibilityLabel(locale: en) == "AreaChain, nothing scheduled for today")
        #expect(MenuBarStatus.completed.accessibilityLabel(locale: en) == "AreaChain, everything for today is handled")
    }
}
