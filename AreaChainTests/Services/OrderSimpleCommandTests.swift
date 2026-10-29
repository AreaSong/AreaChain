import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 三个排序指令经骨架执行，规则沿原仓储 reorderSubtasks／reorderRoutines 与 ManualOrder。
@Suite(.serialized) @MainActor struct OrderSimpleCommandTests {
    private func family(_ f: TaskSimpleFixture) throws -> (TodoItem, [SubtaskItem], SubtaskItem) {
        let todo = try f.insert(TodoItem(title: "父任务", dayKey: TaskSimpleFixture.today))
        let children = [("一", 0), ("二", 5), ("三", 9)].map { SubtaskItem(title: $0.0, sortOrder: $0.1, todo: todo) }
        let gone = SubtaskItem(title: "已删", sortOrder: 7, deletedAt: Date(timeIntervalSince1970: 9), todo: todo)
        for child in children + [gone] { f.context.insert(child) }
        try f.context.save()
        return (todo, children, gone)
    }

    @Test func subtaskMovesWithinParentAndMatchesDetailDrag() throws {
        let f = try TaskSimpleFixture()
        let (todo, children, gone) = try family(f)
        let target = CommandObjectReference(type: .subtask, id: children[2].id)
        try f.queue("subtask.order", targets: [target], arguments: [f.parent(todo), f.position(1)])
        let preview = try f.preview()
        #expect(preview.before.rows.map(\.title) == ["一", "二", "三"] && preview.after.rows.map(\.title) == ["三", "一", "二"])
        #expect(f.count("save") == 0 && children.map(\.sortOrder) == [0, 5, 9])
        let facts = try f.submit(f.adapter.accept(preview, expecting: f.handoff.owned().lease))
        #expect(facts.state == .saved && f.count("save") == 1 && f.count("ui") == 1 && f.refreshes.count == 1)
        #expect(children.map(\.sortOrder) == [1, 2, 0] && gone.sortOrder == 7)
        // 原详情拖动走同一仓储写入：同样的新顺序得到同样的 sortOrder。
        let ui = try TaskSimpleFixture()
        let (uiTodo, uiChildren, uiGone) = try family(ui)
        DayBoardMutations.taskRepositoryProvider = { _ in SwiftDataTaskRepository(context: ui.context) }
        defer { DayBoardMutations.taskRepositoryProvider = nil }
        #expect(DayBoardMutations.reorderSubtasks(for: uiTodo, orderedIDs: [uiChildren[2], uiChildren[0], uiChildren[1]].map(\.id)))
        #expect(uiChildren.map(\.sortOrder) == children.map(\.sortOrder) && uiGone.sortOrder == gone.sortOrder)
    }

    @Test func samePositionIsNoChangeAndBadInputsAreRejected() throws {
        let f = try TaskSimpleFixture()
        let (todo, children, _) = try family(f)
        let (_, facts) = try f.run("subtask.order", targets: [.init(type: .subtask, id: children[1].id)],
                                   arguments: [f.parent(todo), f.position(2)])
        #expect(facts.state == .noChange && f.count("save") == 0 && children.map(\.sortOrder) == [0, 5, 9])
        let cases: [(Double, Bool, CommandSimpleIssue)] = [(4, false, .invalidTarget(.outOfRange)), (0, false, .invalidTarget(.outOfRange)),
                                                           (1.5, false, .invalidArguments), (1, true, .invalidTarget(.parentMismatch))]
        for (position, wrongParent, issue) in cases {
            let g = try TaskSimpleFixture()
            let (gTodo, gChildren, _) = try family(g)
            let parent = wrongParent ? try g.insert(TodoItem(title: "别的父任务", dayKey: TaskSimpleFixture.today)) : gTodo
            try g.queue("subtask.order", targets: [.init(type: .subtask, id: gChildren[0].id)],
                        arguments: [g.parent(parent), g.position(position)])
            #expect(throws: issue) { try g.preview() }
            #expect(g.count("save") == 0)
        }
        let deleted = try TaskSimpleFixture()
        let (dTodo, _, dGone) = try family(deleted)
        try deleted.queue("subtask.order", targets: [.init(type: .subtask, id: dGone.id)], arguments: [deleted.parent(dTodo), deleted.position(1)])
        #expect(throws: CommandSimpleIssue.invalidTarget(.deleted)) { try deleted.preview() }
    }

    @Test func siblingAddedAfterAcceptanceIsRejectedAndWriteFailureRollsBack() throws {
        let f = try TaskSimpleFixture()
        let (todo, children, _) = try family(f)
        try f.queue("subtask.order", targets: [.init(type: .subtask, id: children[0].id)], arguments: [f.parent(todo), f.position(3)])
        let accepted = try f.accept()
        f.context.insert(SubtaskItem(title: "新来的", sortOrder: 3, todo: todo))
        try f.context.save()
        #expect(throws: CommandSimpleIssue.invalidTarget(.changed)) { try f.submit(accepted) }
        #expect(f.count("save") == 0 && children.map(\.sortOrder) == [0, 5, 9])
        let g = try TaskSimpleFixture()
        let (gTodo, gChildren, _) = try family(g)
        let failing = TaskSimpleCommandFailureRepository(g.context, failOn: 1)
        g.tasks = { _ in failing }
        let (_, facts) = try g.run("subtask.order", targets: [.init(type: .subtask, id: gChildren[0].id)],
                                   arguments: [g.parent(gTodo), g.position(3)])
        #expect(facts.state == .notSubmitted && failing.calls == 1 && g.count("save") == 0 && g.count("ui") == 0)
        #expect(gChildren.map(\.sortOrder) == [0, 5, 9])
    }

    @Test func routineMovesAmongAllLiveRoutinesIncludingPaused() throws {
        let f = try TaskSimpleFixture()
        let routines = [("晨跑", 0, true), ("读书", 3, false), ("冥想", 6, true)].map {
            DailyRoutine(title: $0.0, sortOrder: $0.1, isEnabled: $0.2, createdDayKey: "2026-10-01")
        }
        let gone = DailyRoutine(title: "已删", sortOrder: 4, createdDayKey: "2026-10-01", deletedAt: Date(timeIntervalSince1970: 1))
        for routine in routines + [gone] { f.context.insert(routine) }
        try f.context.save()
        let (_, facts) = try f.run("routine.order", targets: [.init(type: .routine, id: routines[0].id)], arguments: [f.position(3)])
        #expect(facts.state == .saved && routines.map(\.sortOrder) == [2, 0, 1] && gone.sortOrder == 4 && f.count("save") == 1)
        #expect(facts.after.rows.map(\.title) == ["读书", "冥想", "晨跑"])
        let protected = try TaskSimpleFixture()
        let routine = try protected.insert(DailyRoutine(title: "受保护", sortOrder: 0, createdDayKey: "2026-10-01"))
        protected.protected = [routine.id]
        try protected.queue("routine.order", targets: [.init(type: .routine, id: routine.id)], arguments: [protected.position(1)])
        #expect(throws: CommandSimpleIssue.invalidTarget(.protectedSource)) { try protected.preview() }
    }

    /// 同一天待办与习惯混排：写入沿 ManualOrder 重写这一天的顺序，与原拖放（逐字副本）一致。
    @Test func dayOrderMixesTodosAndRoutinesLikeBoardDrag() throws {
        let f = try TaskSimpleFixture()
        let day = TaskSimpleFixture.today
        let first = try f.insert(TodoItem(title: "待办一", dayKey: day, sortOrder: 0))
        let second = try f.insert(TodoItem(title: "待办二", dayKey: day, sortOrder: 4))
        let routine = try f.insert(DailyRoutine(title: "习惯", sortOrder: 2, createdDayKey: "2026-10-01"))
        let elsewhere = try f.insert(TodoItem(title: "别的日子", dayKey: TaskSimpleFixture.yesterday, sortOrder: 1))
        try f.queue("tasks.order", targets: [.init(type: .routine, id: routine.id)], arguments: [f.day(day), f.position(1)])
        let preview = try f.preview()
        #expect(preview.before.rows.map(\.title) == ["待办一", "习惯", "待办二"])
        #expect(preview.after.rows.map(\.title) == ["习惯", "待办一", "待办二"])
        let facts = try f.submit(f.adapter.accept(preview, expecting: f.handoff.owned().lease))
        let orders: [Int] = [routine.sortOrder, first.sortOrder, second.sortOrder]
        #expect(facts.state == .saved && orders == [0, 1, 2])
        #expect(elsewhere.sortOrder == 1 && f.count("save") == 1)
        let legacy = try TaskSimpleFixture()
        let a = try legacy.insert(TodoItem(id: first.id, title: "待办一", dayKey: day, sortOrder: 0))
        let b = try legacy.insert(TodoItem(id: second.id, title: "待办二", dayKey: day, sortOrder: 4))
        let r = try legacy.insert(DailyRoutine(id: routine.id, title: "习惯", sortOrder: 2, createdDayKey: "2026-10-01"))
        let entries = [ManualOrderEntry(id: a.id, dayKey: day, sortOrder: 0), .init(id: r.id, dayKey: day, sortOrder: 2),
                       .init(id: b.id, dayKey: day, sortOrder: 4)]
        let moved = try #require(ManualOrder.reordered(entries, moving: r.id, before: a.id))
        #expect(TaskSimpleCommandLegacyRules.applyManualOrder(moved, context: legacy.context, boundary: legacy.io.boundary))
        let legacyOrders: [Int] = [r.sortOrder, a.sortOrder, b.sortOrder]
        let commandOrders: [Int] = [routine.sortOrder, first.sortOrder, second.sortOrder]
        #expect(legacyOrders == commandOrders)
    }

    @Test func dayOrderRejectsCrossingSubtaskGroupAndItemsNotListed() throws {
        let f = try TaskSimpleFixture()
        let day = TaskSimpleFixture.today
        let big = try f.insert(TodoItem(title: "大任务", dayKey: day, sortOrder: 5))
        try f.insert(SubtaskItem(title: "子项", todo: big))
        let small = try f.insert(TodoItem(title: "小任务", dayKey: day, sortOrder: 0))
        let other = try f.insert(TodoItem(title: "昨天的", dayKey: TaskSimpleFixture.yesterday))
        try f.queue("tasks.order", targets: [.init(type: .todo, id: small.id)], arguments: [f.day(day), f.position(1)])
        #expect(throws: CommandSimpleIssue.invalidTarget(.crossesGroup)) { try f.preview() }
        let g = try TaskSimpleFixture()
        let moved = try g.insert(TodoItem(id: other.id, title: "昨天的", dayKey: TaskSimpleFixture.yesterday))
        try g.queue("tasks.order", targets: [.init(type: .todo, id: moved.id)], arguments: [g.day(day), g.position(1)])
        #expect(throws: CommandSimpleIssue.invalidTarget(.notListed)) { try g.preview() }
        #expect(f.count("save") + g.count("save") == 0 && small.sortOrder == 0 && big.sortOrder == 5)
    }

    /// 排序指令只用 position 数字，不读选择顺序；目录上 tasks.order 是单目标并带 position。
    @Test func catalogDeclaresPositionForEveryOrderCommand() throws {
        for id in ["subtask.order", "routine.order", "tasks.order"] {
            let command = try #require(CommandCatalog.standard.command(id: .init(rawValue: id)))
            #expect(command.parameters.contains { $0.id == .position } && command.batch == .singleOnly)
        }
        let postpone = try #require(CommandCatalog.standard.command(id: .init(rawValue: "tasks.postponeYesterday")))
        #expect(postpone.targetTypes.isEmpty && postpone.parameters.map(\.id) == [.day])
    }
}
