import Foundation
import SwiftData

/// 界面直接操作与持久化历史引擎的自动桥接层：非注册表命令触发的界面变更统一记入 `ActionHistoryStore.shared`。
@MainActor
enum ActionHistoryUIBridge {
    private static var isReplayingUndoRedo = false

    static func record(
        actionID: ActionID,
        actionTitle: String,
        targetTitle: String,
        field: String,
        before: String,
        after: String,
        isSensitive: Bool = false,
        undo: @escaping @MainActor () throws -> Void,
        redo: @escaping @MainActor () throws -> Void
    ) {
        guard !ActionRegistry.shared.isExecutingAction, !isReplayingUndoRedo else {
            return
        }
        let diff = ActionDiff(
            actionID: actionID,
            actionTitle: actionTitle,
            targetTitle: targetTitle,
            changes: [ActionFieldChange(field: field, before: before, after: after)],
            isSensitive: isSensitive
        )
        ActionHistoryStore.shared.record(
            diff: diff,
            message: diff.formattedSummary(isVaultUnlocked: !isSensitive),
            undoClosure: { try runSuppressed(undo) },
            redoClosure: { try runSuppressed(redo) }
        )
    }

    private static func runSuppressed(_ body: @MainActor () throws -> Void) throws {
        let wasReplaying = isReplayingUndoRedo
        isReplayingUndoRedo = true
        defer { isReplayingUndoRedo = wasReplaying }
        try body()
    }

    // MARK: - DayBoardMutations 紧凑记录辅助

    static func recordTodoDone(
        _ todo: TodoItem,
        wasDone: Bool,
        isDone: Bool,
        reopenSubtaskIDs: [UUID] = []
    ) {
        guard wasDone != isDone else { return }
        record(
            actionID: isDone ? "todo.done" : "todo.reopen",
            actionTitle: isDone ? "完成待办" : "重开待办",
            targetTitle: todo.title,
            field: "完成状态",
            before: wasDone ? "已完成" : "未完成",
            after: isDone ? "已完成" : "未完成",
            undo: {
                _ = DayBoardMutations.setTodoDone(todo, isDone: wasDone)
                for sub in todo.subtasks where reopenSubtaskIDs.contains(sub.id) && sub.deletedAt == nil && sub.isDone {
                    _ = DayBoardMutations.toggleSubtask(sub)
                }
            },
            redo: {
                _ = DayBoardMutations.setTodoDone(todo, isDone: isDone)
            }
        )
    }

    static func recordTodoRename(_ todo: TodoItem, oldTitle: String, newTitle: String) {
        guard oldTitle != newTitle else { return }
        record(
            actionID: "todo.rename",
            actionTitle: "修改待办标题",
            targetTitle: newTitle,
            field: "标题",
            before: oldTitle,
            after: newTitle,
            undo: { _ = DayBoardMutations.editTodo(todo, title: oldTitle) },
            redo: { _ = DayBoardMutations.editTodo(todo, title: newTitle) }
        )
    }

    static func recordTodoMove(_ todo: TodoItem, oldDayKey: String, newDayKey: String) {
        guard oldDayKey != newDayKey else { return }
        record(
            actionID: "todo.move",
            actionTitle: "移动待办日期",
            targetTitle: todo.title,
            field: "日期",
            before: oldDayKey,
            after: newDayKey,
            undo: { _ = DayBoardMutations.moveTodo(todo, to: oldDayKey) },
            redo: { _ = DayBoardMutations.moveTodo(todo, to: newDayKey) }
        )
    }

    static func recordTodoPriority(_ todo: TodoItem, oldSlot: QuadrantSlot, newSlot: QuadrantSlot) {
        guard oldSlot != newSlot else { return }
        record(
            actionID: "todo.priority",
            actionTitle: "设置待办优先级",
            targetTitle: todo.title,
            field: "优先级",
            before: oldSlot.badgeText,
            after: newSlot.badgeText,
            undo: { _ = DayBoardMutations.applyQuadrant(oldSlot, to: todo) },
            redo: { _ = DayBoardMutations.applyQuadrant(newSlot, to: todo) }
        )
    }

    static func recordTodoTrash(_ todo: TodoItem) {
        record(
            actionID: "todo.delete",
            actionTitle: "删除待办",
            targetTitle: todo.title,
            field: "状态",
            before: "正常",
            after: "回收站",
            undo: { _ = DayBoardMutations.restoreTodo(todo) },
            redo: { _ = DayBoardMutations.trashTodo(todo) }
        )
    }

    static func recordRoutineCheck(
        _ routine: DailyRoutine,
        on dayKey: String,
        wasClosed: Bool,
        context: ModelContext?
    ) {
        record(
            actionID: "routine.check",
            actionTitle: "习惯打卡",
            targetTitle: routine.title,
            field: "打卡(\(dayKey))",
            before: wasClosed ? "已打卡" : "未打卡",
            after: wasClosed ? "未打卡" : "已打卡",
            undo: { _ = DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: routine.checks, context: context) },
            redo: { _ = DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: routine.checks, context: context) }
        )
    }

    static func recordRoutineEnabled(
        _ routine: DailyRoutine,
        wasEnabled: Bool,
        enabled: Bool,
        todayKey: String,
        context: ModelContext?
    ) {
        guard wasEnabled != enabled else { return }
        record(
            actionID: enabled ? "routine.resume" : "routine.pause",
            actionTitle: enabled ? "恢复习惯" : "暂停习惯",
            targetTitle: routine.title,
            field: "状态",
            before: wasEnabled ? "启用" : "暂停",
            after: enabled ? "启用" : "暂停",
            undo: {
                _ = DayBoardMutations.setRoutineEnabled(
                    routine, enabled: wasEnabled, todayKey: todayKey, checks: routine.checks, context: context
                )
            },
            redo: {
                _ = DayBoardMutations.setRoutineEnabled(
                    routine, enabled: enabled, todayKey: todayKey, checks: routine.checks, context: context
                )
            }
        )
    }

    static func recordSubtaskAdd(todo: TodoItem, subtask: SubtaskItem, context: ModelContext) {
        record(
            actionID: "subtask.add",
            actionTitle: "新增子任务",
            targetTitle: todo.title,
            field: "新增子任务",
            before: "",
            after: subtask.title,
            undo: { _ = DayBoardMutations.deleteSubtask(subtask) },
            redo: { _ = DayBoardMutations.persist(context: context) { subtask.deletedAt = nil } }
        )
    }

    static func recordSubtaskToggle(_ subtask: SubtaskItem, wasDone: Bool) {
        record(
            actionID: "subtask.toggle",
            actionTitle: "切换子任务完成状态",
            targetTitle: subtask.title,
            field: "完成状态",
            before: wasDone ? "已完成" : "未完成",
            after: wasDone ? "未完成" : "已完成",
            undo: { _ = DayBoardMutations.toggleSubtask(subtask) },
            redo: { _ = DayBoardMutations.toggleSubtask(subtask) }
        )
    }

    static func recordRoutineSubtaskToggle(
        _ routine: DailyRoutine,
        subtaskID: UUID,
        on dayKey: String,
        context: ModelContext?
    ) {
        let title = routine.subtaskTemplates.first(where: { $0.id == subtaskID })?.title ?? routine.title
        record(
            actionID: "subtask.toggle",
            actionTitle: "切换子任务完成状态",
            targetTitle: title,
            field: "完成状态",
            before: "变更前",
            after: "已切换",
            undo: { _ = DayBoardMutations.toggleRoutineSubtask(routine, subtaskID: subtaskID, on: dayKey, context: context) },
            redo: { _ = DayBoardMutations.toggleRoutineSubtask(routine, subtaskID: subtaskID, on: dayKey, context: context) }
        )
    }

    static func recordRoutineSubtaskAdd(
        to routine: DailyRoutine,
        templateID: UUID,
        title: String,
        context: ModelContext?
    ) {
        record(
            actionID: "subtask.add",
            actionTitle: "新增子任务",
            targetTitle: routine.title,
            field: "新增子任务",
            before: "",
            after: title,
            undo: { _ = DayBoardMutations.deleteRoutineSubtask(routine: routine, subtaskID: templateID, context: context) },
            redo: { _ = DayBoardMutations.addRoutineSubtask(to: routine, title: title, context: context) }
        )
    }
}
