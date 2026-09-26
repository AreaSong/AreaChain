import Foundation
import SwiftData

extension DayBoardMutations {
    @discardableResult
    static func batchMoveTodos(_ ids: Set<UUID>, to dayKey: String, todos: [TodoItem] = []) -> Bool {
        ModelChanges.attempt(in: todos.first?.modelContext) {
            try taskRepo(for: todos.first?.modelContext).batchMoveTodos(ids: ids, to: dayKey)
        }
    }

    @discardableResult
    static func batchToggleDone(_ ids: Set<UUID>, markDone: Bool, todos: [TodoItem] = []) -> Bool {
        ModelChanges.attempt(in: todos.first?.modelContext) {
            try taskRepo(for: todos.first?.modelContext).batchToggleDone(ids: ids, markDone: markDone)
        }
    }

    /// 今日清单的多选会同时改一次性事项和重复事项。必须放进同一次事务，
    /// 任一部分不能打卡时整批不写，避免待办已完成而打卡失败。
    @discardableResult
    static func batchToggleListed(
        todoIDs: Set<UUID>,
        routineChecks: [String: Set<UUID>],
        markDone: Bool,
        todos: [TodoItem] = [],
        routines: [DailyRoutine] = [],
        context: ModelContext? = nil
    ) -> Bool {
        if markDone, !routineChecks.allSatisfy({ day, ids in
            !day.isEmpty && allowsBatchCheck(ids, on: day, routines: routines)
        }) {
            return false
        }
        let groups = routineChecks.filter { !$0.key.isEmpty && !$0.value.isEmpty }
        guard !todoIDs.isEmpty || !groups.isEmpty else { return false }
        guard let context = context ?? todos.first?.modelContext ?? routines.first?.modelContext else {
            return false
        }
        return ModelChanges.perform(in: context) {
            if !todoIDs.isEmpty {
                try taskRepo(for: context).batchToggleDone(ids: todoIDs, markDone: markDone)
            }
            let repo = routineRepo(for: context)
            for (day, ids) in groups {
                try repo.batchSetRoutineChecks(ids: ids, markDone: markDone, on: day)
            }
        }
    }

    @discardableResult
    static func batchSetRoutineChecks(
        _ ids: Set<UUID>, markDone: Bool, on dayKey: String,
        routines: [DailyRoutine] = [], context: ModelContext? = nil
    ) -> Bool {
        batchSetRoutineChecks(groupedByDay: [dayKey: ids], markDone: markDone, routines: routines, context: context)
    }

    /// 不同检查日分组后放进同一事务，避免只写成今天或中途失败留下一部分。
    static func batchSetRoutineChecks(
        groupedByDay: [String: Set<UUID>],
        markDone: Bool,
        routines: [DailyRoutine] = [],
        context: ModelContext? = nil
    ) -> Bool {
        guard let context = context ?? routines.first?.modelContext else { return false }
        let groups = groupedByDay.filter { !$0.key.isEmpty && !$0.value.isEmpty }
        guard !groups.isEmpty else { return false }
        if markDone, !groups.allSatisfy({ day, ids in allowsBatchCheck(ids, on: day, routines: routines) }) {
            return false
        }
        return ModelChanges.perform(in: context) {
            let repo = routineRepo(for: context)
            for (day, ids) in groups {
                try repo.batchSetRoutineChecks(ids: ids, markDone: markDone, on: day)
            }
        }
    }

    /// 批量打卡只接受这一天真实排定、且已启用的重复事项。取消打卡不走这道限制，避免无法撤回已有记录。
    private static func allowsBatchCheck(_ ids: Set<UUID>, on dayKey: String, routines: [DailyRoutine]) -> Bool {
        let byID = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0.snapshot) })
        return ids.allSatisfy { id in
            guard let routine = byID[id] else { return false }
            return DayBoardLogic.isRoutineDue(routine, on: dayKey)
        }
    }

    @discardableResult
    static func reorderRoutines(_ items: [DailyRoutine], from source: IndexSet, to destination: Int) -> Bool {
        ModelChanges.attempt(in: items.first?.modelContext) {
            try routineRepo(for: items.first?.modelContext).reorderRoutines(from: source, to: destination)
        }
    }

    @discardableResult
    static func batchApplyTag(
        _ ids: Set<UUID>, tagID: UUID, present: Bool, todos: [TodoItem] = [], routines: [DailyRoutine] = []
    ) -> Bool {
        let context = todos.first?.modelContext ?? routines.first?.modelContext ?? Persistence.session.container.mainContext
        return ModelChanges.perform(in: context) {
            try taskRepo(for: context).batchApplyTag(ids: ids, tagID: tagID, present: present)
            try routineRepo(for: context).batchApplyTag(ids: ids, tagID: tagID, present: present)
        }
    }

    @discardableResult
    static func batchToggleTag(
        _ ids: Set<UUID>, tagID: UUID, todos: [TodoItem] = [], routines: [DailyRoutine] = []
    ) -> Bool {
        let context = todos.first?.modelContext ?? routines.first?.modelContext ?? Persistence.session.container.mainContext
        return ModelChanges.perform(in: context) {
            try taskRepo(for: context).batchToggleTag(ids: ids, tagID: tagID)
            try routineRepo(for: context).batchToggleTag(ids: ids, tagID: tagID)
        }
    }

    @discardableResult
    static func batchSetRoutineEnabled(
        _ ids: Set<UUID>, enabled: Bool, todayKey: String, routines: [DailyRoutine] = []
    ) -> Bool {
        let context = routines.first?.modelContext ?? Persistence.session.container.mainContext
        let targets = routines.filter { ids.contains($0.id) && $0.deletedAt == nil }
        guard !targets.isEmpty else { return false }
        return ModelChanges.perform(in: context) {
            for routine in targets {
                try routineRepo(for: context).setRoutineEnabled(id: routine.id, enabled: enabled, todayKey: todayKey)
            }
        }
    }

    static func batchTrash(_ ids: Set<UUID>, todos: [TodoItem] = [], routines: [DailyRoutine] = []) -> Bool {
        let context = todos.first?.modelContext ?? routines.first?.modelContext ?? Persistence.session.container.mainContext
        return ModelChanges.perform(in: context) {
            try taskRepo(for: context).batchTrashTodos(ids: ids)
            try routineRepo(for: context).batchTrashRoutines(ids: ids)
        }
    }

    @discardableResult
    static func batchTrashTags(ids: [UUID], context: ModelContext) -> Bool {
        guard !ids.isEmpty else { return true }
        return ModelChanges.perform(in: context) {
            let repo = catalogRepo(for: context)
            for id in ids {
                try repo.deleteTag(id: id, soft: true)
            }
        }
    }

    @discardableResult
    static func batchRestoreTags(_ tags: [TagItem]) -> Bool {
        guard let context = tags.first?.modelContext, !tags.isEmpty else { return tags.isEmpty }
        return ModelChanges.perform(in: context) {
            let repo = catalogRepo(for: context)
            for tag in tags {
                try repo.restoreTag(id: tag.id)
            }
        }
    }

    @discardableResult
    static func batchPurgeTags(_ tags: [TagItem]) -> Bool {
        guard let context = tags.first?.modelContext, !tags.isEmpty else { return tags.isEmpty }
        return ModelChanges.perform(in: context) {
            let repo = catalogRepo(for: context)
            for tag in tags {
                try repo.purgeTag(id: tag.id)
            }
        }
    }
}
