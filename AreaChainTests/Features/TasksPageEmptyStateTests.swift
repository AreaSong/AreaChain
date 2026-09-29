import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct TasksPageEmptyStateTests {
    @Test func todayEmptyStateIgnoresDeletedDoneTodos() {
        let liveDone = TodoItem(title: "还在", isDone: true, dayKey: "2026-09-09")
        let deletedDone = TodoItem(
            title: "已删完", isDone: true, dayKey: "2026-09-09",
            deletedAt: Date(timeIntervalSince1970: 9)
        )
        #expect(
            !snapshot(todayKey: "2026-09-09", todos: [liveDone]).isTodayEmpty
        )
        #expect(
            snapshot(todayKey: "2026-09-09", todos: [deletedDone]).isTodayEmpty
        )
    }

    private func snapshot(
        todayKey: String,
        todos: [TodoItem],
        routines: [DailyRoutine] = [],
        checks: [RoutineCheck] = []
    ) -> DayBoardPageSnapshot {
        DayBoardPageProjection.project(
            source: DayBoardSource(routines: routines, checks: checks, todos: todos),
            todayKey: todayKey,
            yesterdayKey: DayKey.shifted(todayKey, by: -1),
            filter: BoardFilter()
        )
    }
}
