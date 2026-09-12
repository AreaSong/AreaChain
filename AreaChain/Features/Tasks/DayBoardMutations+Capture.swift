import Foundation
import SwiftData

extension DayBoardMutations {
    @discardableResult
    static func addCapturedTodo(text: String, dayKey: String, context: ModelContext) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let saved = ModelChanges.perform(in: context) {
            let tag = try parsed.tagName.flatMap { try catalogRepo(for: context).resolveTaskTag(name: $0) }
            let params = CreateTodoParams(
                title: parsed.cleanTitle, dayKey: dayKey, notes: parsed.notes,
                remindMinutes: parsed.remindMinutes, isImportant: parsed.isImportant,
                isUrgent: parsed.isUrgent, tagIDs: tag.map { [$0.id] } ?? [],
                sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
            )
            _ = try taskRepo(for: context).addTodo(params)
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
            if let name = parsed.tagName {
                guard let tag = try catalogRepo(for: todo.modelContext).resolveTaskTag(name: name) else {
                    throw RepositoryError.invalidArgument("无效标签")
                }
                if !TagIDList.contains(todo.tagIDs, tag.id) { try repo.toggleTag(id: todo.id, tagID: tag.id) }
            }
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
            if let name = parsed.tagName {
                guard let tag = try catalogRepo(for: routine.modelContext).resolveTaskTag(name: name) else {
                    throw RepositoryError.invalidArgument("无效标签")
                }
                if !TagIDList.contains(routine.tagIDs, tag.id) { try repo.toggleTag(id: routine.id, tagID: tag.id) }
            }
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }
}
