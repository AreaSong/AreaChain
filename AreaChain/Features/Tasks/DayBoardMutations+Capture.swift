import Foundation
import SwiftData

extension DayBoardMutations {
    @discardableResult
    static func addCapturedTodo(
        text: String, dayKey: String, context: ModelContext, projectID: UUID? = nil, tagIDs: [UUID] = []
    ) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let saved = ModelChanges.perform(in: context) {
            let ids = try InputTagResolver.merging(parsed.tagNames, into: TagIDList.encode(tagIDs), in: context)
            let params = CreateTodoParams(
                title: parsed.cleanTitle, dayKey: dayKey, notes: parsed.notes,
                remindMinutes: parsed.remindMinutes, isImportant: parsed.isImportant,
                isUrgent: parsed.isUrgent, projectID: projectID, tagIDs: TagIDList.parse(ids),
                sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
            )
            _ = try taskRepo(for: context).addTodo(params)
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    @discardableResult
    static func addCapturedRoutine(text: String, sortOrder: Int, context: ModelContext) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let saved = ModelChanges.perform(in: context) {
            let ids = try InputTagResolver.resolve(parsed.tagNames, in: context)
            _ = try routineRepo(for: context).addRoutine(CreateRoutineParams(
                title: parsed.cleanTitle, sortOrder: sortOrder, remindMinutes: parsed.remindMinutes,
                tagIDs: ids, isImportant: parsed.isImportant, isUrgent: parsed.isUrgent, notes: parsed.notes
            ))
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    @discardableResult
    static func editTodoWithSyntax(_ todo: TodoItem, rawInput: String) -> Bool {
        let text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let repo = taskRepo(for: todo.modelContext)
        let saved = ModelChanges.perform(in: todo.modelContext ?? Persistence.session.container.mainContext) {
            try repo.updateTodo(id: todo.id, title: parsed.cleanTitle, notes: parsed.notes.isEmpty ? nil : parsed.notes)
            if parsed.hasPriorityToken {
                try repo.setPriority(id: todo.id, isImportant: parsed.isImportant, isUrgent: parsed.isUrgent)
            }
            if let minutes = parsed.remindMinutes { try repo.setRemind(id: todo.id, minutes: minutes) }
            let context = todo.modelContext ?? Persistence.session.container.mainContext
            todo.tagIDs = try InputTagResolver.merging(parsed.tagNames, into: todo.tagIDs, in: context)
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    @discardableResult
    static func editRoutineWithSyntax(_ routine: DailyRoutine, rawInput: String) -> Bool {
        let text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let repo = routineRepo(for: routine.modelContext)
        let saved = ModelChanges.perform(in: routine.modelContext ?? Persistence.session.container.mainContext) {
            try repo.updateRoutine(id: routine.id, title: parsed.cleanTitle, notes: parsed.notes.isEmpty ? nil : parsed.notes)
            if parsed.hasPriorityToken {
                try repo.setPriority(id: routine.id, isImportant: parsed.isImportant, isUrgent: parsed.isUrgent)
            }
            if let minutes = parsed.remindMinutes { try repo.setRemind(id: routine.id, minutes: minutes) }
            let context = routine.modelContext ?? Persistence.session.container.mainContext
            routine.tagIDs = try InputTagResolver.merging(parsed.tagNames, into: routine.tagIDs, in: context)
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    static func saveNotes(_ notes: String, for todo: TodoItem) -> Bool {
        let context = todo.modelContext ?? Persistence.session.container.mainContext
        let parsed = NaturalLanguageParser.parseTaskNotes(notes)
        let saved = ModelChanges.perform(in: context) {
            todo.notes = notes
            todo.tagIDs = try InputTagResolver.merging(parsed.tagNames, into: todo.tagIDs, in: context)
            if let time = parsed.remindMinutes { todo.remindMinutes = time }
            if parsed.hasPriorityToken {
                todo.isImportant = parsed.isImportant
                todo.isUrgent = parsed.isUrgent
            }
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    static func saveNotes(_ notes: String, for routine: DailyRoutine) -> Bool {
        let context = routine.modelContext ?? Persistence.session.container.mainContext
        let parsed = NaturalLanguageParser.parseTaskNotes(notes)
        let saved = ModelChanges.perform(in: context) {
            routine.notes = notes
            routine.tagIDs = try InputTagResolver.merging(parsed.tagNames, into: routine.tagIDs, in: context)
            if let time = parsed.remindMinutes { routine.remindMinutes = time }
            if parsed.hasPriorityToken {
                routine.isImportant = parsed.isImportant
                routine.isUrgent = parsed.isUrgent
            }
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }
}
