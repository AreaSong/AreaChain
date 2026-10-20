import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-2 A：gantt.shift 沿安排页拖动的同一平移规则与写入入口；一次事务、保留间隔、越出当月整组拒绝。
@Suite(.serialized) @MainActor struct GanttShiftCommandTests {
    private func offset(_ value: Double) -> CommandArgument { .init(parameter: .offset, operation: .assign, value: .number(value)) }
    private func refs(_ todos: [TodoItem]) -> [CommandObjectReference] { todos.map { .init(type: .todo, id: $0.id) } }

    @Test func shiftKeepsGapsAndWritesOnce() throws {
        let f = try TaskSimpleFixture(board: true)
        let a = try f.insert(TodoItem(title: "第一项", dayKey: "2026-10-03"))
        let b = try f.insert(TodoItem(title: "第二项", dayKey: "2026-10-07"))
        try f.queue("gantt.shift", targets: refs([a, b]), single: false, arguments: [offset(5), f.day("2026-10-15")])
        let preview = try f.preview()
        #expect(preview.after.rows.map { $0.fields[0].value } == ["2026-10-08", "2026-10-12"])
        #expect(f.count("save") == 0 && a.dayKey == "2026-10-03")
        let facts = try f.submit(f.adapter.accept(preview, expecting: f.handoff.owned().lease))
        #expect(facts.state == .saved && f.count("save") == 1 && f.count("ui") == 1)
        let stored = try f.stored(TodoItem.self)
        let days = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0.dayKey) })
        // 间隔 4 天保持不变。
        #expect(days[a.id] == "2026-10-08" && days[b.id] == "2026-10-12")
    }

    /// 与拖动同一平移结果：拖动把越界钳到月边，指令不替用户截断，越出当月整组拒绝。
    @Test func matchesDragMovesAndRejectsLeavingTheMonth() throws {
        let f = try TaskSimpleFixture(board: true)
        let a = try f.insert(TodoItem(title: "月初", dayKey: "2026-10-02"))
        let b = try f.insert(TodoItem(title: "月中", dayKey: "2026-10-20"))
        let days = DayKey.daysInMonth(containing: "2026-10-01", calendar: TaskSimpleFixture.calendar)
        let bars = [GanttTodoBar(id: a.id, title: a.title, dayKey: a.dayKey), GanttTodoBar(id: b.id, title: b.title, dayKey: b.dayKey)]
        var drag = try #require(GanttDragState(sourceID: a.id, selectedIDs: [a.id, b.id], bars: bars, days: days))
        drag.update(dayOffset: -1)
        #expect(GanttRescheduleService.shift(bars, by: -1, monthDays: days) == drag.moves)
        #expect(GanttRescheduleService.shift(bars, by: -2, monthDays: days) == nil)
        try f.queue("gantt.shift", targets: refs([a, b]), single: false, arguments: [offset(-2), f.day("2026-10-01")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.outOfRange)) { try f.preview() }
        #expect(a.dayKey == "2026-10-02" && f.count("save") == 0)
    }

    /// 资格与安排页一致：已完成、不在该月、受保护的目标整组拒绝；超过批量上限不截断。
    @Test func ineligibleTargetsAreRejected() throws {
        let done = try TaskSimpleFixture(board: true)
        let finished = try done.insert(TodoItem(title: "已完成", isDone: true, dayKey: "2026-10-05"))
        try done.queue("gantt.shift", targets: refs([finished]), arguments: [offset(1), done.day("2026-10-01")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.notListed)) { try done.preview() }
        let month = try TaskSimpleFixture(board: true)
        let november = try month.insert(TodoItem(title: "下月", dayKey: "2026-11-05"))
        try month.queue("gantt.shift", targets: refs([november]), arguments: [offset(1), month.day("2026-10-01")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.notListed)) { try month.preview() }
        let guarded = try TaskSimpleFixture(board: true)
        let secret = try guarded.insert(TodoItem(title: "受保护", dayKey: "2026-10-05"))
        guarded.protected = [secret.id]
        try guarded.queue("gantt.shift", targets: refs([secret]), arguments: [offset(1), guarded.day("2026-10-01")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.protectedSource)) { try guarded.preview() }
        let many = try TaskSimpleFixture(board: true)
        var todos: [TodoItem] = []
        for index in 0...CommandBatchWriteSet.Counts.entityLimit {
            let todo = TodoItem(title: "第 \(index) 项", dayKey: "2026-10-05")
            many.context.insert(todo)
            todos.append(todo)
        }
        try many.context.save()
        try many.queue("gantt.shift", targets: refs(todos), single: false, arguments: [offset(1), many.day("2026-10-01")])
        #expect(throws: CommandSimpleIssue.invalidTarget(.tooMany)) { try many.preview() }
    }

    /// 一次事务：第二项改期失败时第一项也回滚，不发布。
    @Test func failureRollsBackTheWholeGroup() throws {
        let f = try TaskSimpleFixture(board: true)
        let a = try f.insert(TodoItem(title: "第一项", dayKey: "2026-10-03"))
        let b = try f.insert(TodoItem(title: "第二项", dayKey: "2026-10-07"))
        let failing = TaskTM6FailureRepository(f.context, failOn: 2)
        f.tasks = { _ in failing }
        let (_, facts) = try f.run("gantt.shift", targets: refs([a, b]), single: false, arguments: [offset(3), f.day("2026-10-01")])
        #expect(facts.state == .notSubmitted && failing.calls == 2 && f.count("save") == 0 && f.count("ui") == 0)
        let days = Dictionary(uniqueKeysWithValues: try f.stored(TodoItem.self).map { ($0.id, $0.dayKey) })
        #expect(days[a.id] == "2026-10-03" && days[b.id] == "2026-10-07")
    }

    /// 偏移为 0 时没有变化，按 noChange 结束，不写库。
    @Test func zeroOffsetIsNoChange() throws {
        let f = try TaskSimpleFixture(board: true)
        let a = try f.insert(TodoItem(title: "不动", dayKey: "2026-10-03"))
        let (_, facts) = try f.run("gantt.shift", targets: refs([a]), arguments: [offset(0), f.day("2026-10-01")])
        #expect(facts.state == .noChange && f.count("save") == 0)
    }
}
