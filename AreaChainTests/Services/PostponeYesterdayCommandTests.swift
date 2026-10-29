import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 昨天清单里全部未完成的待办一次事务延至今天；取法沿今日页，写入沿批量改期的 moveTodo。
@Suite(.serialized) @MainActor struct PostponeYesterdayCommandTests {
    private struct Board {
        let yesterday: TodoItem
        let older: TodoItem
        let done: TodoItem
        let today: TodoItem
        let routine: DailyRoutine
        let trashed: TodoItem
    }

    private func board(_ f: TaskSimpleFixture) throws -> Board {
        try .init(yesterday: f.insert(TodoItem(title: "昨天没做", dayKey: TaskSimpleFixture.yesterday)),
                  older: f.insert(TodoItem(title: "更早没做", dayKey: "2026-10-12")),
                  done: f.insert(TodoItem(title: "昨天做完", isDone: true, dayKey: TaskSimpleFixture.yesterday)),
                  today: f.insert(TodoItem(title: "今天的", dayKey: TaskSimpleFixture.today)),
                  routine: f.insert(DailyRoutine(title: "昨天的习惯", sortOrder: 0, createdDayKey: "2026-10-01")),
                  trashed: f.insert(TodoItem(title: "已删", dayKey: TaskSimpleFixture.yesterday, deletedAt: .now)))
    }

    @Test func targetsFollowTodayPageAndMoveInOneTransaction() throws {
        let f = try TaskSimpleFixture()
        let b = try board(f)
        try f.queue("tasks.postponeYesterday", arguments: [f.day(TaskSimpleFixture.today)])
        let preview = try f.preview()
        // 与今日页同一取法：所有早于今天的未完成待办；不含已完成、已删、今天的待办和习惯。
        let expected = try f.context.fetch(FetchDescriptor<TodoItem>()).map(\.snapshot)
        let pageIDs = DayBoardPageProjection.project(source: .init(routines: [], checks: [], todos: try f.context.fetch(FetchDescriptor<TodoItem>())),
                                                     todayKey: TaskSimpleFixture.today, yesterdayKey: TaskSimpleFixture.yesterday,
                                                     filter: .init(), calendar: TaskSimpleFixture.calendar).overdueTodos.map(\.id)
        #expect(Set(preview.before.rows.map(\.key)) == Set(pageIDs.map(\.uuidString)) && expected.count == 5)
        #expect(Set(preview.before.rows.map(\.title)) == ["昨天没做", "更早没做"])
        #expect(preview.after.rows.allSatisfy { $0.fields == [.init(id: "day", value: TaskSimpleFixture.today, display: .verbatim(TaskSimpleFixture.today))] })
        #expect(f.count("save") == 0 && b.yesterday.dayKey == TaskSimpleFixture.yesterday)
        let facts = try f.submit(f.adapter.accept(preview, expecting: f.handoff.owned().lease))
        #expect(facts.state == .saved && f.count("save") == 1 && f.count("ui") == 1 && f.refreshes == [true])
        #expect(b.yesterday.dayKey == TaskSimpleFixture.today && b.older.dayKey == TaskSimpleFixture.today)
        #expect(b.done.dayKey == TaskSimpleFixture.yesterday && b.trashed.dayKey == TaskSimpleFixture.yesterday)
        #expect(b.today.dayKey == TaskSimpleFixture.today && b.routine.deletedAt == nil)
    }

    @Test func listChangesAfterAcceptanceAreRejectedNotSilentlyExpanded() throws {
        let f = try TaskSimpleFixture()
        let b = try board(f)
        try f.queue("tasks.postponeYesterday", arguments: [f.day(TaskSimpleFixture.today)])
        let accepted = try f.accept()
        try f.insert(TodoItem(title: "后来的逾期", dayKey: TaskSimpleFixture.yesterday))
        #expect(throws: CommandSimpleIssue.invalidTarget(.changed)) { try f.submit(accepted) }
        #expect(f.count("save") == 0 && b.yesterday.dayKey == TaskSimpleFixture.yesterday)
    }

    @Test func emptyListOtherDayAndProtectedTargetsAreRejected() throws {
        let empty = try TaskSimpleFixture()
        try empty.insert(TodoItem(title: "今天的", dayKey: TaskSimpleFixture.today))
        try empty.queue("tasks.postponeYesterday", arguments: [empty.day(TaskSimpleFixture.today)])
        #expect(throws: CommandSimpleIssue.invalidTarget(.nothingToMove)) { try empty.preview() }
        let other = try TaskSimpleFixture()
        _ = try board(other)
        try other.queue("tasks.postponeYesterday", arguments: [other.day("2026-10-20")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.notToday)) { try other.preview() }
        let protected = try TaskSimpleFixture()
        let b = try board(protected)
        protected.protected = [b.older.id]
        try protected.queue("tasks.postponeYesterday", arguments: [protected.day(TaskSimpleFixture.today)])
        #expect(throws: CommandSimpleIssue.invalidTarget(.protectedSource)) { try protected.preview() }
    }

    /// 一次事务：第二个改期失败时第一个也回滚，不发布。
    @Test func failureInsideTransactionRollsBackEveryMove() throws {
        let f = try TaskSimpleFixture()
        let b = try board(f)
        let failing = TaskSimpleCommandFailureRepository(f.context, failOn: 2)
        f.tasks = { _ in failing }
        let (_, facts) = try f.run("tasks.postponeYesterday", arguments: [f.day(TaskSimpleFixture.today)])
        #expect(facts.state == .notSubmitted && failing.calls == 2 && f.count("save") == 0 && f.count("ui") == 0)
        #expect(b.yesterday.dayKey == TaskSimpleFixture.yesterday && b.older.dayKey == "2026-10-12")
    }

    @Test(arguments: [TaskCreateCommandIO.SaveMode.throwBefore, .throwAfter])
    func unknownSaveVerifiesFrozenTargetsOnly(mode: TaskCreateCommandIO.SaveMode) throws {
        let f = try TaskSimpleFixture()
        _ = try board(f)
        f.saveMode = mode
        let (accepted, facts) = try f.run("tasks.postponeYesterday", arguments: [f.day(TaskSimpleFixture.today)])
        #expect(facts.state == .unknown && f.count("ui") == 0)
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(throws: CommandSimpleIssue.verificationRequired) {
            try f.handoff.coordinator.simples.requireResolved(accepted.preview.lockKeys)
        }
        #expect(try f.verify().outcome == (mode == .throwAfter ? .applied : .notApplied) && f.count("save") == 1)
    }

    /// 总量只有一个来源：超过 CommandBatchWriteSet.Counts.entityLimit 的目标数整体拒绝，不截断。
    @Test func targetCountUsesTheBatchEntityLimit() throws {
        let f = try TaskSimpleFixture()
        for index in 0...CommandBatchWriteSet.Counts.entityLimit {
            f.context.insert(TodoItem(title: "逾期 \(index)", dayKey: TaskSimpleFixture.yesterday))
        }
        try f.context.save()
        try f.queue("tasks.postponeYesterday", arguments: [f.day(TaskSimpleFixture.today)])
        #expect(throws: CommandSimpleIssue.invalidTarget(.tooMany)) { try f.preview() }
        #expect(f.count("save") == 0)
    }
}
