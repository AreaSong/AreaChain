import Foundation
import SwiftData

extension DayBoardMutations {
    @discardableResult
    static func addCapturedTodo(
        text: String, dayKey: String, context: ModelContext, tagIDs: [UUID] = []
    ) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let saved = ModelChanges.perform(in: context) {
            let ids = try InputTagResolver.merging(parsed.tagNames, into: TagIDList.encode(tagIDs), in: context)
            let params = CreateTodoParams(
                title: parsed.cleanTitle, dayKey: dayKey, notes: parsed.notes,
                remindMinutes: parsed.remindMinutes, isImportant: parsed.isImportant,
                isUrgent: parsed.isUrgent, tagIDs: TagIDList.parse(ids),
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

    /// 用结构化草稿创建重复事项。失败时不写入，调用方保留草稿。
    @discardableResult
    static func addRecurringItem(_ draft: RecurringCaptureDraft, sortOrder: Int, context: ModelContext) -> Bool {
        guard draft.hasSelectedWeekday else { return false }
        let titleParsed = NaturalLanguageParser.parseTaskCapture(draft.title)
        let noteParsed = NaturalLanguageParser.parseTaskNotes(draft.notes)
        let title = titleParsed.cleanTitle
        let notes = draft.notes
        let isImportant = titleParsed.hasPriorityToken
            ? titleParsed.isImportant
            : (noteParsed.hasPriorityToken ? noteParsed.isImportant : draft.isImportant)
        let isUrgent = titleParsed.hasPriorityToken
            ? titleParsed.isUrgent
            : (noteParsed.hasPriorityToken ? noteParsed.isUrgent : draft.isUrgent)
        let remind = titleParsed.remindMinutes ?? noteParsed.remindMinutes ?? draft.remindMinutes
        let tagNames = titleParsed.tagNames + noteParsed.tagNames
        let hasBody = !title.isEmpty || remind != nil || isImportant || isUrgent
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !tagNames.isEmpty || !draft.tagIDs.isEmpty
        guard hasBody else { return false }
        let saved = ModelChanges.perform(in: context) {
            let parsedIDs = try InputTagResolver.resolve(tagNames, in: context)
            var ids = draft.tagIDs
            for id in parsedIDs where !ids.contains(id) {
                ids.append(id)
            }
            _ = try routineRepo(for: context).addRoutine(CreateRoutineParams(
                title: title,
                sortOrder: sortOrder,
                weekdayMask: draft.weekdayMask,
                remindMinutes: remind,
                tagIDs: ids,
                isImportant: isImportant,
                isUrgent: isUrgent,
                notes: notes,
                isEnabled: draft.isEnabled
            ))
        }
        if saved { requestReminderAccessIfNeeded(remind) }
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
            let merged = try InputTagResolver.merging(parsed.tagNames, into: todo.tagIDs, in: context)
            try repo.replaceTagIDs(id: todo.id, tagIDs: merged)
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
            let merged = try InputTagResolver.merging(parsed.tagNames, into: routine.tagIDs, in: context)
            try repo.replaceTagIDs(id: routine.id, tagIDs: merged)
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    static func saveNotes(_ notes: String, for todo: TodoItem) -> Bool {
        let context = todo.modelContext ?? Persistence.session.container.mainContext
        let parsed = NaturalLanguageParser.parseTaskNotes(notes)
        let saved = ModelChanges.perform(in: context) {
            let merged = try InputTagResolver.merging(parsed.tagNames, into: todo.tagIDs, in: context)
            try taskRepo(for: context).applyParsedNotes(id: todo.id, update: parsedNoteUpdate(notes, parsed, merged))
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    static func saveNotes(_ notes: String, for routine: DailyRoutine) -> Bool {
        let context = routine.modelContext ?? Persistence.session.container.mainContext
        let parsed = NaturalLanguageParser.parseTaskNotes(notes)
        let saved = ModelChanges.perform(in: context) {
            let merged = try InputTagResolver.merging(parsed.tagNames, into: routine.tagIDs, in: context)
            try routineRepo(for: context).applyParsedNotes(id: routine.id, update: parsedNoteUpdate(notes, parsed, merged))
        }
        if saved { requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    private static func parsedNoteUpdate(_ notes: String, _ parsed: ParsedCapture, _ tagIDs: String) -> ParsedNoteUpdate {
        ParsedNoteUpdate(
            notes: notes,
            tagIDs: tagIDs,
            remindMinutes: parsed.remindMinutes,
            isImportant: parsed.hasPriorityToken ? parsed.isImportant : nil,
            isUrgent: parsed.hasPriorityToken ? parsed.isUrgent : nil
        )
    }
}
