import Foundation
import SwiftData

extension DayBoardMutations {
    @discardableResult
    static func toggleRoutineSubtask(
        _ routine: DailyRoutine,
        subtaskID: UUID,
        on dayKey: String,
        context: ModelContext? = nil
    ) -> Bool {
        let ctx = context ?? routine.modelContext
        return ModelChanges.attempt(in: ctx) {
            try routineRepo(for: ctx).toggleRoutineSubtask(id: routine.id, subtaskID: subtaskID, dayKey: dayKey)
        }
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
        return ModelChanges.attempt(in: ctx) {
            try routineRepo(for: ctx).updateRoutineSubtaskTemplates(id: routine.id, templates: templates)
        }
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
