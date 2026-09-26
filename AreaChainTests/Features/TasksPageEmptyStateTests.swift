import Foundation
import SwiftData
import SwiftUI
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
            !TasksPage(
                todayKey: "2026-09-09", routines: [], checks: [], todos: [liveDone]
            ).isTodayEmpty
        )
        #expect(
            TasksPage(
                todayKey: "2026-09-09", routines: [], checks: [], todos: [deletedDone]
            ).isTodayEmpty
        )
    }
}
