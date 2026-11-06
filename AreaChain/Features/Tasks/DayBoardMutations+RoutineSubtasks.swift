import Foundation
import SwiftData

extension DayBoardMutations {
    // MARK: - 待办语义重载与快捷入口

    @discardableResult
    static func setTodoDone(_ todo: TodoItem, isDone: Bool) -> Bool {
        guard todo.isDone != isDone else { return true }
        return toggleTodo(todo)
    }

    @discardableResult
    static func updateTodoTitle(_ todo: TodoItem, title: String) -> Bool {
        editTodo(todo, title: title)
    }

    @discardableResult
    static func applyQuadrant(_ slot: QuadrantSlot?, to todo: TodoItem) -> Bool {
        applyQuadrant(slot ?? .rest, to: todo)
    }

    // MARK: - 子任务

    @discardableResult
    static func addSubtask(to todo: TodoItem, title: String, context: ModelContext? = nil) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let resolvedContext = context ?? todo.modelContext ?? Persistence.session.container.mainContext
        guard let sub = ModelChanges.value(in: resolvedContext, {
            try taskRepo(for: resolvedContext).addSubtask(to: todo.id, title: trimmed)
        }) else { return false }
        if !todo.subtasks.contains(where: { $0.id == sub.id }) { todo.subtasks.append(sub) }
        ActionHistoryUIBridge.recordSubtaskAdd(todo: todo, subtask: sub, context: resolvedContext)
        return true
    }

    @discardableResult
    static func toggleSubtask(_ subtask: SubtaskItem) -> Bool {
        let wasDone = subtask.isDone
        let saved = ModelChanges.attempt(in: subtask.modelContext) {
            try taskRepo(for: subtask.modelContext).toggleSubtask(id: subtask.id)
        }
        if saved {
            CompletionUndo.shared.record(.subtask(subtask.id, wasDone: wasDone))
            ActionHistoryUIBridge.recordSubtaskToggle(subtask, wasDone: wasDone)
        }
        return saved
    }

    @discardableResult
    static func toggleSubtaskDone(_ subtask: SubtaskItem) -> Bool {
        toggleSubtask(subtask)
    }

    @discardableResult
    static func toggleSubtaskTag(_ subtask: SubtaskItem, tagID: UUID) -> Bool {
        ModelChanges.attempt(in: subtask.modelContext) {
            try taskRepo(for: subtask.modelContext).toggleSubtaskTag(id: subtask.id, tagID: tagID)
        }
    }

    @discardableResult
    static func editSubtask(_ subtask: SubtaskItem, title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return ModelChanges.attempt(in: subtask.modelContext) {
            try taskRepo(for: subtask.modelContext).editSubtask(id: subtask.id, title: trimmed)
        }
    }

    @discardableResult
    static func deleteSubtask(_ subtask: SubtaskItem) -> Bool {
        ModelChanges.attempt(in: subtask.modelContext) {
            try taskRepo(for: subtask.modelContext).deleteSubtask(id: subtask.id, soft: true)
        }
    }

    @discardableResult
    static func reorderSubtasks(for todo: TodoItem, orderedIDs: [UUID]) -> Bool {
        ModelChanges.attempt(in: todo.modelContext) {
            try taskRepo(for: todo.modelContext).reorderSubtasks(for: todo.id, orderedIDs: orderedIDs)
        }
    }

    // MARK: - 习惯打卡与状态

    @discardableResult
    static func setRoutineEnabled(
        _ routine: DailyRoutine,
        enabled: Bool,
        todayKey: String = DayKey.today(),
        checks: [RoutineCheck] = [],
        context: ModelContext? = nil
    ) -> Bool {
        let context = context ?? routine.modelContext
        let wasEnabled = routine.isEnabled
        let saved = ModelChanges.attempt(in: context) {
            try routineRepo(for: context).setRoutineEnabled(id: routine.id, enabled: enabled, todayKey: todayKey)
        }
        if saved {
            ActionHistoryUIBridge.recordRoutineEnabled(
                routine, wasEnabled: wasEnabled, enabled: enabled, todayKey: todayKey, context: context
            )
        }
        return saved
    }

    @discardableResult
    static func setWeekdayMask(_ routine: DailyRoutine, mask: Int) -> Bool {
        ModelChanges.attempt(in: routine.modelContext) {
            try routineRepo(for: routine.modelContext).setWeekdayMask(id: routine.id, mask: mask)
        }
    }

    @discardableResult
    static func markRoutineDone(_ routine: DailyRoutine, on dayKey: String) -> Bool {
        let saved = ModelChanges.attempt(in: routine.modelContext) {
            try routineRepo(for: routine.modelContext).markRoutineDone(id: routine.id, dayKey: dayKey)
        }
        if saved {
            CompletionUndo.shared.record(.routine(routine.id, dayKey: dayKey, wasClosed: false))
            ActionHistoryUIBridge.recordRoutineCheck(routine, on: dayKey, wasClosed: false, context: routine.modelContext)
        }
        return saved
    }

    @discardableResult
    static func toggleRoutine(
        _ routine: DailyRoutine,
        on dayKey: String,
        checks: [RoutineCheck] = [],
        context: ModelContext? = nil
    ) -> Bool {
        let context = context ?? routine.modelContext
        let snaps = checks.compactMap(\.snapshot)
        let wasClosed = DayBoardLogic.isRoutineDone(routine.snapshot, checks: snaps, on: dayKey)
        let saved = ModelChanges.attempt(in: context) {
            try routineRepo(for: context).toggleRoutine(id: routine.id, dayKey: dayKey)
        }
        if saved {
            CompletionUndo.shared.record(.routine(routine.id, dayKey: dayKey, wasClosed: wasClosed))
            ActionHistoryUIBridge.recordRoutineCheck(routine, on: dayKey, wasClosed: wasClosed, context: context)
        }
        return saved
    }

    @discardableResult
    static func toggleRoutineCheck(
        _ routine: DailyRoutine,
        on dayKey: String,
        checks: [RoutineCheck] = [],
        context: ModelContext? = nil
    ) -> Bool {
        toggleRoutine(routine, on: dayKey, checks: checks, context: context)
    }

    @discardableResult
    static func skipRoutine(
        _ routine: DailyRoutine,
        on dayKey: String,
        checks: [RoutineCheck] = [],
        context: ModelContext? = nil
    ) -> Bool {
        let context = context ?? routine.modelContext
        return ModelChanges.attempt(in: context) {
            try routineRepo(for: context).skipRoutine(id: routine.id, dayKey: dayKey)
        }
    }

    // MARK: - 习惯子任务模板

    @discardableResult
    static func toggleRoutineSubtask(
        _ routine: DailyRoutine,
        subtaskID: UUID,
        on dayKey: String,
        context: ModelContext? = nil
    ) -> Bool {
        let ctx = context ?? routine.modelContext
        let saved = ModelChanges.attempt(in: ctx) {
            try routineRepo(for: ctx).toggleRoutineSubtask(id: routine.id, subtaskID: subtaskID, dayKey: dayKey)
        }
        if saved {
            ActionHistoryUIBridge.recordRoutineSubtaskToggle(routine, subtaskID: subtaskID, on: dayKey, context: ctx)
        }
        return saved
    }

    @discardableResult
    static func addRoutineSubtask(
        to routine: DailyRoutine,
        title: String,
        context: ModelContext? = nil
    ) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let ctx = context ?? routine.modelContext
        var templates = routine.subtaskTemplates
        let maxOrder = templates.map(\.sortOrder).max() ?? -1
        let newTemplate = RoutineSubtaskTemplate(
            id: UUID(),
            title: trimmed,
            sortOrder: maxOrder + 1,
            tagIDs: ""
        )
        templates.append(newTemplate)
        let saved = ModelChanges.attempt(in: ctx) {
            try routineRepo(for: ctx).updateRoutineSubtaskTemplates(id: routine.id, templates: templates)
        }
        if saved {
            ActionHistoryUIBridge.recordRoutineSubtaskAdd(
                to: routine, templateID: newTemplate.id, title: trimmed, context: ctx
            )
        }
        return saved
    }

    @discardableResult
    static func editRoutineSubtask(
        routine: DailyRoutine,
        subtaskID: UUID,
        title: String,
        context: ModelContext? = nil
    ) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let ctx = context ?? routine.modelContext
        var templates = routine.subtaskTemplates
        guard let index = templates.firstIndex(where: { $0.id == subtaskID }) else { return false }
        templates[index].title = trimmed
        return ModelChanges.attempt(in: ctx) {
            try routineRepo(for: ctx).updateRoutineSubtaskTemplates(id: routine.id, templates: templates)
        }
    }

    @discardableResult
    static func deleteRoutineSubtask(
        routine: DailyRoutine,
        subtaskID: UUID,
        context: ModelContext? = nil
    ) -> Bool {
        let ctx = context ?? routine.modelContext
        var templates = routine.subtaskTemplates
        guard let index = templates.firstIndex(where: { $0.id == subtaskID }) else { return false }
        templates.remove(at: index)
        return ModelChanges.attempt(in: ctx) {
            try routineRepo(for: ctx).updateRoutineSubtaskTemplates(id: routine.id, templates: templates)
        }
    }

    @discardableResult
    static func reorderRoutineSubtasks(
        routine: DailyRoutine,
        orderedIDs: [UUID],
        context: ModelContext? = nil
    ) -> Bool {
        let ctx = context ?? routine.modelContext
        let templates = routine.subtaskTemplates
        let map = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        var reordered: [RoutineSubtaskTemplate] = []
        for (idx, id) in orderedIDs.enumerated() {
            if var t = map[id] {
                t.sortOrder = idx
                reordered.append(t)
            }
        }
        for var t in templates where !orderedIDs.contains(t.id) {
            t.sortOrder = reordered.count
            reordered.append(t)
        }
        return ModelChanges.attempt(in: ctx) {
            try routineRepo(for: ctx).updateRoutineSubtaskTemplates(id: routine.id, templates: reordered)
        }
    }
}
