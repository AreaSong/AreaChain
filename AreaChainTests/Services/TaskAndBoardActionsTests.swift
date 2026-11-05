import AppKit
import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
private final class MockManagedWindow: BaseWindow {
    private let customID: String
    private let customTitle: String
    var dirty: Bool = false

    init(id: String, title: String, registry: WindowRegistry) {
        self.customID = id
        self.customTitle = title
        super.init(registry: registry)
    }

    override var windowID: String { customID }
    override var windowCategory: String { "diary" }
    override var windowTitle: String { customTitle }
    override func hasUnsavedChanges() -> Bool { dirty }
    override func confirmCloseIfUnsaved() -> Bool { !dirty }
}

@Suite(.serialized)
@MainActor
struct TaskAndBoardActionsTests {
    private func makeRegistry(historyStore: ActionHistoryStore) -> ActionRegistry {
        let registry = ActionRegistry(historyStore: historyStore, registerBuiltins: false)
        registry.register(WindowAndNavActions.all(history: historyStore))
        registry.register(TaskMutationActions.all())
        registry.register(RoutineAndSubtaskActions.all())
        registry.register(PlanningBoardActions.all())
        return registry
    }

    @Test func windowAndNavigationActionsExecution() {
        let store = ActionHistoryStore.inMemory()
        let registry = makeRegistry(historyStore: store)
        let context = ActionContext(todayKey: "2026-11-05", isVaultUnlocked: true)

        #expect(registry.executeCLI("/today", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.selectedTab == .today)

        #expect(registry.executeCLI("/cal", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.selectedTab == .calendar)

        #expect(registry.executeCLI("/quad", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.selectedTab == .quadrant)

        #expect(registry.executeCLI("/gantt", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.selectedTab == .gantt)

        #expect(registry.executeCLI("/settings", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.selectedTab == .settings)

        #expect(registry.executeCLI("/guide", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.selectedTab == .searchGuide)

        WorkspaceNavigation.shared.updateInspectorSpace(available: true)
        #expect(registry.executeCLI("/inspector open", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.isInspectorPresented)
        #expect(registry.executeCLI("/inspector close", context: context).isSuccess)
        #expect(!WorkspaceNavigation.shared.isInspectorPresented)

        let mockWin = MockManagedWindow(id: "win.diary.1", title: "测试手记小窗", registry: .shared)
        defer { _ = mockWin.closeWindow(force: true) }

        #expect(registry.executeCLI("测试手记小窗 > pin", context: context).isSuccess)
        #expect(mockWin.isPinned)
        #expect(registry.executeCLI("测试手记小窗 > unpin", context: context).isSuccess)
        #expect(!mockWin.isPinned)
        #expect(registry.executeCLI("测试手记小窗 > resize 800x600", context: context).isSuccess)

        mockWin.dirty = true
        let blockedClose = registry.executeCLI("测试手记小窗 > close", context: context)
        #expect(blockedClose.message?.contains("未保存") == true)

        mockWin.dirty = false
        #expect(registry.executeCLI("测试手记小窗 > close", context: context).isSuccess)

        let quitUnconfirmed = registry.executeCLI("/quit", context: context)
        if case .requiresConfirmation(let id, _, _) = quitUnconfirmed {
            #expect(id == "app.quit")
        } else {
            Issue.record("预期退出动作触发二次确认")
        }
    }

    @Test func taskMutationActionsAndBidirectionalUndoRedo() throws {
        let container = try AppStartup.memoryContainer()
        let modelContext = container.mainContext
        let store = ActionHistoryStore.inMemory()
        let registry = makeRegistry(historyStore: store)
        let context = ActionContext(
            modelContext: modelContext,
            todayKey: "2026-11-05",
            isVaultUnlocked: true,
            confirmed: true
        )

        #expect(registry.executeCLI("/todo 买牛奶 !p2 @09:30 // 超市促销", context: context).isSuccess)
        let todos = try modelContext.fetch(FetchDescriptor<TodoItem>())
        let todo = try #require(todos.first)
        #expect(todo.title == "买牛奶")
        #expect(todo.isImportant && !todo.isUrgent)
        #expect(todo.remindMinutes == 9 * 60 + 30)
        #expect(todo.notes == "超市促销")

        #expect(registry.executeCLI("买牛奶 > move tomorrow", context: context).isSuccess)
        #expect(todo.dayKey == "2026-11-06")
        _ = try store.undoLast()
        #expect(todo.dayKey == "2026-11-05")
        _ = try store.redoLast()
        #expect(todo.dayKey == "2026-11-06")

        #expect(registry.executeCLI("买牛奶 > done", context: context).isSuccess)
        #expect(todo.isDone)
        #expect(registry.executeCLI("/undo", context: context).isSuccess)
        #expect(!todo.isDone)
        #expect(registry.executeCLI("/redo", context: context).isSuccess)
        #expect(todo.isDone)

        #expect(registry.executeCLI("买牛奶 > reopen", context: context).isSuccess)
        #expect(!todo.isDone)

        #expect(registry.executeCLI("买牛奶 > prio p1", context: context).isSuccess)
        #expect(todo.isImportant && todo.isUrgent)
        _ = try store.undoLast()
        #expect(todo.isImportant && !todo.isUrgent)

        #expect(registry.executeCLI("买牛奶 > due 18:00", context: context).isSuccess)
        #expect(todo.dueMinutes == 18 * 60)
        _ = try store.undoLast()
        #expect(todo.dueMinutes == nil)

        #expect(registry.executeCLI("买牛奶 > title 买两盒有机牛奶", context: context).isSuccess)
        #expect(todo.title == "买两盒有机牛奶")
        _ = try store.undoLast()
        #expect(todo.title == "买牛奶")

        #expect(registry.executeCLI("买牛奶 > rm-todo", context: context).isSuccess)
        #expect(todo.deletedAt != nil)
        _ = try store.undoLast()
        #expect(todo.deletedAt == nil)
        _ = try store.redoLast()
        #expect(todo.deletedAt != nil)
        _ = try store.undoLast()
    }

    @Test func routineAndSubtaskActionsAndBidirectionalUndoRedo() throws {
        let container = try AppStartup.memoryContainer()
        let modelContext = container.mainContext
        let store = ActionHistoryStore.inMemory()
        let registry = makeRegistry(historyStore: store)
        let context = ActionContext(
            modelContext: modelContext,
            todayKey: "2026-11-05",
            isVaultUnlocked: true,
            confirmed: true
        )

        #expect(registry.executeCLI("/habit 晨跑", context: context).isSuccess)
        let routine = try #require(modelContext.fetch(FetchDescriptor<DailyRoutine>()).first)
        #expect(routine.title == "晨跑")

        #expect(registry.executeCLI("晨跑 > check", context: context).isSuccess)
        #expect(routine.checks.contains { $0.dayKey == "2026-11-05" && $0.isDone })
        _ = try store.undoLast()
        #expect(!routine.checks.contains { $0.dayKey == "2026-11-05" && $0.isDone })
        _ = try store.redoLast()
        #expect(routine.checks.contains { $0.dayKey == "2026-11-05" && $0.isDone })

        #expect(registry.executeCLI("晨跑 > weekdays workdays", context: context).isSuccess)
        #expect(routine.resolvedWeekdayMask == WeekdayMask.workdays)
        _ = try store.undoLast()
        #expect(routine.resolvedWeekdayMask == WeekdayMask.all)

        #expect(registry.executeCLI("晨跑 > pause-habit", context: context).isSuccess)
        #expect(!routine.isEnabled)
        _ = try store.undoLast()
        #expect(routine.isEnabled)

        #expect(registry.executeCLI("/todo 准备周报", context: context).isSuccess)
        let todo = try #require(modelContext.fetch(FetchDescriptor<TodoItem>()).first)

        #expect(registry.executeCLI("准备周报 > sub 整理数据", context: context).isSuccess)
        let subtask = try #require(todo.subtasks.first)
        #expect(subtask.title == "整理数据")

        #expect(registry.executeCLI("整理数据 > done-sub", context: context).isSuccess)
        #expect(subtask.isDone)
        _ = try store.undoLast()
        #expect(!subtask.isDone)

        #expect(registry.executeCLI("整理数据 > rename-sub 核对季度数据", context: context).isSuccess)
        #expect(subtask.title == "核对季度数据")
        _ = try store.undoLast()
        #expect(subtask.title == "整理数据")

        #expect(registry.executeCLI("整理数据 > rm-sub", context: context).isSuccess)
        #expect(subtask.deletedAt != nil)
        _ = try store.undoLast()
        #expect(subtask.deletedAt == nil)
    }

    @Test func planningBoardActionsAndBidirectionalUndoRedo() throws {
        let container = try AppStartup.memoryContainer()
        let modelContext = container.mainContext
        let store = ActionHistoryStore.inMemory()
        let registry = makeRegistry(historyStore: store)
        let context = ActionContext(
            modelContext: modelContext,
            todayKey: "2026-11-05",
            isVaultUnlocked: true,
            confirmed: true
        )

        let originalLayout = AppPreferences.shared.calendarMonthLayoutMode
        defer { AppPreferences.shared.calendarMonthLayoutMode = originalLayout }

        let targetLayout: CalendarMonthLayoutMode = (originalLayout == .split) ? .full : .split
        #expect(registry.executeCLI("/cal-layout \(targetLayout.rawValue)", context: context).isSuccess)
        #expect(AppPreferences.shared.calendarMonthLayoutMode == targetLayout)
        _ = try store.undoLast()
        #expect(AppPreferences.shared.calendarMonthLayoutMode == originalLayout)

        #expect(registry.executeCLI("/day 2026-11-10", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.inspectingDayKey == "2026-11-10")
        #expect(registry.executeCLI("/cal-next", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.inspectingDayKey == "2026-11-11")
        #expect(registry.executeCLI("/cal-prev", context: context).isSuccess)
        #expect(WorkspaceNavigation.shared.inspectingDayKey == "2026-11-10")

        #expect(registry.executeCLI("/todo 架构评审", context: context).isSuccess)
        let todo = try #require(modelContext.fetch(FetchDescriptor<TodoItem>()).first)

        #expect(registry.executeCLI("架构评审 > quad-move p1", context: context).isSuccess)
        #expect(todo.isImportant && todo.isUrgent)
        _ = try store.undoLast()
        #expect(!todo.isImportant && !todo.isUrgent)
        _ = try store.redoLast()
        #expect(todo.isImportant && todo.isUrgent)

        #expect(registry.executeCLI("架构评审 > gantt-shift +3", context: context).isSuccess)
        #expect(todo.dayKey == "2026-11-08")
        _ = try store.undoLast()
        #expect(todo.dayKey == "2026-11-05")
        _ = try store.redoLast()
        #expect(todo.dayKey == "2026-11-08")
    }
}
