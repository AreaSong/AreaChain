import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 服务层：页面指令只读写页面自己的那一份状态；页面不对时拒绝且不切页。
@Suite(.serialized) @MainActor struct WorkspacePageCommandTests {
    @MainActor final class Fixture {
        let io: TaskCaptureFixture
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let filters = BoardFilterSession()
        let drafts = EditDrafts()
        let pending = PendingCompletionManager()
        let router: WorkspaceSearchRouter
        let pages: WorkspacePageCommands
        let todo = TodoItem(title: "页面待办", dayKey: "2026-10-20")
        let child: SubtaskItem
        let routine = DailyRoutine(title: "页面习惯", sortOrder: 0, createdDayKey: "2026-10-01")
        let tag = TagItem(name: "页面标签", sortOrder: 0)
        let other = TagItem(name: "另一标签", sortOrder: 1)
        var context: ModelContext { io.context }

        init(page: WorkspaceTab = .today) throws {
            io = try TaskCaptureFixture()
            child = SubtaskItem(title: "页面子任务", sortOrder: 0)
            child.todo = todo
            [tag, other].forEach(io.context.insert)
            io.context.insert(todo)
            io.context.insert(child)
            io.context.insert(routine)
            try io.context.save()
            router = WorkspaceSearchRouter(navigation: navigation,
                objects: WorkspaceObjectNavigation(context: io.context, calendar: .current, allows: { _ in true }))
            pages = WorkspacePageCommands(router: router, filters: filters, drafts: drafts, context: io.context, pending: pending)
            // 服务层没有窗口；宿主可用性由原生用例覆盖。
            pages.hostAvailable = {}
            navigation.selectedTab = page
        }

        func draft(_ command: String, targets: [CommandObjectReference] = [], _ arguments: [CommandArgument] = []) -> CommandDraft {
            CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
                         targets: .init(targets.count > 1 ? .selected : .single, objects: targets), arguments: arguments)
        }

        func run(_ draft: CommandDraft) throws -> WorkspacePageReceipt {
            try pages.apply(pages.prepare(draft), draft: draft)
        }
    }

    static func choice(_ id: CommandParameterID, _ value: String) -> CommandArgument {
        .init(parameter: id, operation: .assign, value: .choice(value))
    }

    // MARK: - 页面状态：筛选、种类与状态、展开

    @Test func filterCommandWritesTheSharedTodayFilter() throws {
        let f = try Fixture()
        let draft = f.draft("tasks.filter", [Self.choice(.priority, "p1"), Self.choice(.dateFilter, "overdue"),
                                             .init(parameter: .tags, operation: .assign, value: .tags([f.tag.id]))])
        let preview = try f.pages.prepare(draft)
        #expect(preview.page == .today && preview.before == .filter(BoardFilter()))
        let expected = BoardFilter().withTag(f.tag.id).withPriorityScope(.p1).withDateScope(.overdue)
        #expect(preview.after == .filter(expected))
        #expect(try f.pages.apply(preview, draft: draft).after == .filter(expected))
        #expect(f.filters.filters.tasks == expected)
        #expect(f.navigation.selectedTab == .today)
    }

    /// 页面改 → 指令条件变：页面在预览后改了筛选，旧预览不能执行；重新预览读到页面的新条件。
    @Test func pageChangesInvalidatePreviewAndFeedTheNextOne() throws {
        let f = try Fixture()
        let draft = f.draft("tasks.filter", [Self.choice(.priority, "p2")])
        let preview = try f.pages.prepare(draft)
        // 页面自己的写法：经共享会话写今日筛选（同 WorkspaceTodayView.writeTaskFilter）。
        var next = f.filters.filters
        next.write(BoardFilter().withReminderScope(.set), for: .tasks)
        f.filters.filters = next
        #expect(throws: CommandPageIssue.stale) { try f.pages.apply(preview, draft: draft) }
        #expect(f.filters.filters.tasks == BoardFilter().withReminderScope(.set))
        let fresh = try f.pages.prepare(draft)
        #expect(fresh.before == .filter(BoardFilter().withReminderScope(.set)))
        #expect(fresh.after == .filter(BoardFilter().withReminderScope(.set).withPriorityScope(.p2)))
    }

    @Test(arguments: [WorkspaceTab.pending, .allItems]) func filterAndClearFollowEachPageOwnState(page: WorkspaceTab) throws {
        let f = try Fixture(page: page)
        _ = try f.run(f.draft("tasks.filter", [Self.choice(.reminderFilter, "withoutReminder")]))
        let filter = page == .pending ? f.navigation.pendingFilter : f.navigation.allItemsQuery.filter
        #expect(filter == BoardFilter().withReminderScope(.unset) && f.filters.filters.tasks == BoardFilter())
        _ = try f.run(f.draft("tasks.clearFilter"))
        #expect((page == .pending ? f.navigation.pendingFilter : f.navigation.allItemsQuery.filter) == BoardFilter())
    }

    @Test func filterTakesOneLiveTag() throws {
        let f = try Fixture()
        let two = f.draft("tasks.filter", [.init(parameter: .tags, operation: .assign, value: .tags([f.tag.id, f.other.id]))])
        #expect(throws: CommandPageIssue.oneTag) { try f.pages.prepare(two) }
        f.other.deletedAt = .now
        try f.context.save()
        let deleted = f.draft("tasks.filter", [.init(parameter: .tags, operation: .assign, value: .tags([f.other.id]))])
        #expect(throws: CommandPageIssue.invalidArguments) { try f.pages.prepare(deleted) }
    }

    @Test func kindAndStatusDriveAllItemsQuery() throws {
        let f = try Fixture(page: .allItems)
        _ = try f.run(f.draft("tasks.kind", [Self.choice(.kind, "recurring")]))
        _ = try f.run(f.draft("tasks.status", [Self.choice(.routineStatus, "disabled")]))
        #expect(f.navigation.allItemsQuery.kind == .recurring && f.navigation.allItemsQuery.routineStatus == .disabled)
        #expect(f.navigation.allItemsQuery.todoStatus == .all)
    }

    @Test func sectionsUseTheHostStateAndTodayIsFixed() throws {
        let f = try Fixture()
        _ = try f.run(f.draft("tasks.sections", [Self.choice(.section, "yesterday"),
                                                 .init(parameter: .enabled, operation: .assign, value: .boolean(true))]))
        #expect(f.navigation.todaySections.yesterday && !f.navigation.todaySections.upcoming)
        let today = f.draft("tasks.sections", [Self.choice(.section, "today"),
                                               .init(parameter: .enabled, operation: .assign, value: .boolean(false))])
        #expect(throws: CommandPageIssue.todaySectionFixed) { try f.pages.prepare(today) }
        // 离开今日页即复位，与原页面状态的生命周期一致。
        f.navigation.selectedTab = .pending
        #expect(f.navigation.todaySections == TasksPageSections())
    }

    /// 页面不对时拒绝并说明需要的页面，不替用户切页。
    @Test func wrongPageIsRejectedWithoutSwitching() throws {
        let f = try Fixture(page: .dashboard)
        #expect(throws: CommandPageIssue.wrongPage("allItems")) { try f.pages.prepare(f.draft("tasks.kind", [Self.choice(.kind, "all")])) }
        #expect(throws: CommandPageIssue.wrongPage("today,pending,allItems")) { try f.pages.prepare(f.draft("tasks.clearFilter")) }
        #expect(f.navigation.selectedTab == .dashboard)
        f.pages.hostAvailable = { throw WorkspaceOpenFailure.unavailable }
        #expect(throws: CommandPageIssue.pageUnavailable) { try f.pages.prepare(f.draft("tasks.clearFilter")) }
    }

    // MARK: - 选择

    @Test func selectionFollowsTheRegisteredPageProjection() throws {
        let f = try Fixture(page: .allItems)
        f.navigation.updateInspectorTargets([f.todo.id, f.routine.id])
        let todo = CommandObjectReference(type: .todo, id: f.todo.id)
        let select = f.draft("tasks.select", targets: [todo])
        let preview = try f.pages.prepare(select)
        #expect(preview.revealsPage && preview.after == .selection([f.todo.id]))
        #expect(throws: CommandPageIssue.stale) { try f.pages.apply(preview, draft: select) }
        #expect(try f.pages.applySelection(preview).after == .selection([f.todo.id]))
        #expect(f.navigation.selectedTaskIDs == [f.todo.id])
        let all = try f.pages.prepare(f.draft("selection.all"))
        _ = try f.pages.applySelection(all)
        #expect(f.navigation.selectedTaskIDs == [f.todo.id, f.routine.id])
        _ = try f.run(f.draft("selection.clear"))
        #expect(f.navigation.selectedTaskIDs.isEmpty)
        let outside = f.draft("tasks.select", targets: [.init(type: .todo, id: UUID())])
        #expect(throws: CommandPageIssue.notInList) { try f.pages.applySelection(f.pages.prepare(outside)) }
        #expect(f.navigation.selectedTaskIDs.isEmpty)
    }

    // MARK: - 取消类

    @Test func cancelTitleDiscardsTheRetainedDraftLikeEscape() throws {
        let f = try Fixture()
        let todo = CommandObjectReference(type: .todo, id: f.todo.id)
        let child = CommandObjectReference(type: .subtask, id: f.child.id)
        f.drafts.titles[EditDrafts.key(todo: f.todo.id)] = "改到一半"
        f.drafts.titles[EditDrafts.key(subtask: f.child.id)] = "子项改到一半"
        f.drafts.notes[EditDrafts.key(todo: f.todo.id)] = "备注草稿不受影响"
        #expect(try f.run(f.draft("todo.cancelTitle", targets: [todo])).after == .titleDraft(false))
        _ = try f.run(f.draft("subtask.cancelTitle", targets: [child]))
        #expect(f.drafts.titles.isEmpty && f.drafts.notes.count == 1 && f.todo.title == "页面待办")
        #expect(throws: CommandPageIssue.nothingToCancel) { try f.pages.prepare(f.draft("todo.cancelTitle", targets: [todo])) }
    }

    @Test func cancelCompletionUsesThePendingUndoWindow() async throws {
        let f = try Fixture()
        f.pending.skipDelayOverride = false
        var committed = 0
        f.pending.toggle(id: f.todo.id, currentlyDone: false) { committed += 1 }
        #expect(f.pending.pendingDoneIDs == [f.todo.id])
        let draft = f.draft("todo.cancelCompletion", targets: [.init(type: .todo, id: f.todo.id)])
        #expect(try f.run(draft).after == .pending(false))
        try await Task.sleep(for: .milliseconds(600))
        #expect(committed == 0 && f.pending.pendingDoneIDs.isEmpty)
        #expect(throws: CommandPageIssue.nothingToCancel) { try f.pages.prepare(draft) }
    }

    // MARK: - 查询

    @Test func streakReusesHabitStreakLogic() throws {
        let f = try Fixture(page: .dashboard)
        for day in ["2026-10-18", "2026-10-19", "2026-10-20"] {
            f.context.insert(RoutineCheck(dayKey: day, isDone: true, routine: f.routine))
        }
        try f.context.save()
        let draft = f.draft("routine.streak", targets: [.init(type: .routine, id: f.routine.id)],
                            [Self.choice(.kind, "current"), .init(parameter: .day, operation: .assign, value: .day("2026-10-20"))])
        let expected = HabitStreakLogic.calculate(routine: f.routine.snapshot, checks: f.routine.checks.compactMap(\.snapshot),
                                                  todayKey: "2026-10-20")
        let preview = try f.pages.prepare(draft)
        #expect(preview.page == nil && preview.before == .streak(current: expected.currentStreak, best: expected.bestStreak))
        #expect(expected.currentStreak == 3)
        #expect(f.navigation.selectedTab == .dashboard && f.io.trace.isEmpty)
    }
}
