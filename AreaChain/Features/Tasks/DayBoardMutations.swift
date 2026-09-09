import Foundation
import SwiftData

@MainActor
enum DayBoardMutations {
    static func persist(_ work: () -> Void) {
        work()
        BoardEvents.changed()
    }

    static func toggleRoutine(
        _ routine: DailyRoutine,
        on dayKey: String,
        checks: [RoutineCheck],
        context: ModelContext
    ) {
        persist {
            if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == dayKey }) {
                check.isDone.toggle()
                if !check.isDone {
                    check.isSkipped = false
                }
                return
            }
            context.insert(RoutineCheck(dayKey: dayKey, isDone: true, routine: routine))
        }
    }

    static func skipRoutine(
        _ routine: DailyRoutine,
        on dayKey: String,
        checks: [RoutineCheck],
        context: ModelContext
    ) {
        persist {
            if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == dayKey }) {
                check.isDone = true
                check.isSkipped = true
                return
            }
            context.insert(RoutineCheck(dayKey: dayKey, isDone: true, isSkipped: true, routine: routine))
        }
    }

    static func toggleTodo(_ todo: TodoItem) {
        persist {
            todo.isDone.toggle()
            if todo.isDone {
                for sub in todo.subtasks where sub.deletedAt == nil && !sub.isDone {
                    sub.isDone = true
                }
            }
        }
    }

    static func editTodo(_ todo: TodoItem, title: String) {
        persist { todo.title = title }
    }

    static func editRoutine(_ routine: DailyRoutine, title: String) {
        persist { routine.title = title }
    }

    static func trashTodo(_ todo: TodoItem) {
        persist {
            let now = SoftDelete.stamp()
            todo.deletedAt = now
            for sub in todo.subtasks where sub.deletedAt == nil {
                sub.deletedAt = now
            }
        }
    }

    static func restoreTodo(_ todo: TodoItem) {
        persist {
            let stamp = todo.deletedAt
            todo.deletedAt = nil
            SoftDelete.restoreCascadedSubtasks(parentDeletedAt: stamp, subtasks: todo.subtasks)
        }
    }

    static func trashRoutine(_ routine: DailyRoutine) {
        persist { routine.deletedAt = SoftDelete.stamp() }
    }

    static func addTag(
        named name: String,
        existing: [TagItem],
        context: ModelContext,
        ontoTodo todo: TodoItem? = nil,
        ontoRoutine routine: DailyRoutine? = nil
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        persist {
            let tag = existing.first { $0.name == trimmed && $0.deletedAt == nil } ?? {
                let created = TagItem(name: trimmed, sortOrder: existing.count)
                context.insert(created)
                return created
            }()
            if let todo, !TagIDList.contains(todo.tagIDs, tag.id) {
                todo.tagIDs = TagIDList.toggling(todo.tagIDs, tag.id)
            }
            if let routine, !TagIDList.contains(routine.tagIDs, tag.id) {
                routine.tagIDs = TagIDList.toggling(routine.tagIDs, tag.id)
            }
        }
    }

    static func moveTodo(_ todo: TodoItem, to dayKey: String) {
        guard dayKey != todo.dayKey else { return }
        persist { todo.dayKey = dayKey }
    }

    static func setRemind(_ todo: TodoItem, minutes: Int?) {
        persist { todo.remindMinutes = RemindMinutes.clamped(minutes) }
        if minutes != nil {
            NotificationScheduler.shared.ensureAuthorization()
        }
    }

    static func applyQuadrant(_ slot: QuadrantSlot, to todo: TodoItem) {
        persist {
            todo.isImportant = slot.isImportant
            todo.isUrgent = slot.isUrgent
        }
    }

    static func applyQuadrant(_ slot: QuadrantSlot, to routine: DailyRoutine) {
        persist {
            routine.isImportant = slot.isImportant
            routine.isUrgent = slot.isUrgent
        }
    }

    static func addTodo(title: String, notes: String = "", dayKey: String, context: ModelContext) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        persist {
            context.insert(TodoItem(title: trimmed, dayKey: dayKey, notes: notes))
        }
        return true
    }

    static func addSubtask(to todo: TodoItem, title: String, context: ModelContext) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let currentActive = todo.subtasks.filter { $0.deletedAt == nil }
        let nextOrder = (currentActive.map(\.sortOrder).max() ?? -1) + 1
        let item = SubtaskItem(title: trimmed, sortOrder: nextOrder, todo: todo)
        persist {
            context.insert(item)
            todo.subtasks.append(item)
        }
        return true
    }

    static func toggleSubtask(_ subtask: SubtaskItem) {
        persist { subtask.isDone.toggle() }
    }

    static func editSubtask(_ subtask: SubtaskItem, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        persist { subtask.title = trimmed }
    }

    static func deleteSubtask(_ subtask: SubtaskItem) {
        persist { subtask.deletedAt = .now }
    }

    static func reorderSubtasks(for todo: TodoItem, orderedIDs: [UUID]) {
        persist {
            for (idx, id) in orderedIDs.enumerated() {
                if let item = todo.subtasks.first(where: { $0.id == id }) {
                    item.sortOrder = idx
                }
            }
        }
    }

    static func updateNotes(for todo: TodoItem, notes: String) {
        persist { todo.notes = notes }
    }

    static func updateNotes(for routine: DailyRoutine, notes: String) {
        persist { routine.notes = notes }
    }

    static func addDiary(
        text: String,
        dayKey: String,
        selectedTagIDs: Set<UUID> = [],
        tags: [TagItem],
        context: ModelContext
    ) {
        persist {
            var available = tags
            var ids = selectedTagIDs
            let parsed = NaturalLanguageParser.parse(text)
            if let tagName = parsed.tagName {
                ids.insert(ensureTag(named: tagName, among: &available, context: context).id)
            }
            for name in DiaryMemoTags.autoTagNames(in: text) {
                ids.insert(ensureTag(named: name, among: &available, context: context).id)
            }
            context.insert(
                DiaryEntry(
                    text: text,
                    dayKey: dayKey,
                    tagIDs: TagIDList.encode(Array(ids))
                )
            )
        }
    }

    static func ensureDiaryPresetTags(among tags: [TagItem], context: ModelContext) {
        let needsInsert = DiaryMemoTags.presets.contains { name in
            !tags.contains { $0.name == name }
        }
        let needsRestore = tags.contains {
            DiaryMemoTags.isPresetName($0.name) && $0.deletedAt != nil
        }
        guard needsInsert || needsRestore else { return }
        persist {
            var available = tags
            for name in DiaryMemoTags.presets {
                _ = ensureTag(named: name, among: &available, context: context)
            }
        }
    }

    static func editDiary(_ entry: DiaryEntry, text: String) {
        persist { entry.text = text }
    }

    static func togglePinDiary(_ entry: DiaryEntry) {
        persist { entry.isPinned.toggle() }
    }

    static func toggleDiaryTag(_ entry: DiaryEntry, tagID: UUID) {
        persist {
            entry.tagIDs = TagIDList.toggling(entry.tagIDs, tagID)
        }
    }

    static func deleteDiary(_ entry: DiaryEntry) {
        persist { entry.deletedAt = .now }
    }

    private static func ensureTag(
        named name: String,
        among tags: inout [TagItem],
        context: ModelContext
    ) -> TagItem {
        if let found = tags.first(where: { $0.name == name }) {
            found.deletedAt = nil
            return found
        }
        let tag = TagItem(name: name, sortOrder: tags.count)
        context.insert(tag)
        tags.append(tag)
        return tag
    }
}

enum ResidentNote {
    static func days(_ routine: DailyRoutine, locale: Locale) -> String? {
        let mask = routine.resolvedWeekdayMask
        if WeekdayMask.isAll(mask) { return nil }
        if WeekdayMask.isWorkdays(mask) { return L10n.string("note.weekdays", locale: locale) }
        return WeekdayMask.selectedLabels(mask, locale: locale)
    }

    static func done(_ routine: DailyRoutine, skipped: Bool, locale: Locale) -> String? {
        let days = days(routine, locale: locale)
        if skipped {
            if let days {
                return L10n.string("note.skipped", locale: locale) + " · " + days
            }
            return L10n.string("note.skipped", locale: locale)
        }
        return days
    }
}
