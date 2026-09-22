import Foundation
import SwiftData

@MainActor
enum DayBoardMutations {
    // MARK: - 仓储依赖解析与注入 (Repository Resolvers & DI)

    static var taskRepositoryProvider: ((ModelContext?) -> any TaskRepositoryProtocol)?
    static var routineRepositoryProvider: ((ModelContext?) -> any RoutineRepositoryProtocol)?
    static var catalogRepositoryProvider: ((ModelContext?) -> any CatalogRepositoryProtocol)?
    static var diaryRepositoryProvider: ((ModelContext?) -> any DiaryRepositoryProtocol)?

    static func taskRepo(for context: ModelContext? = nil) -> any TaskRepositoryProtocol {
        if let provider = taskRepositoryProvider { return provider(context) }
        let ctx = context ?? Persistence.session.container.mainContext
        return SwiftDataTaskRepository(context: ctx)
    }

    static func routineRepo(for context: ModelContext? = nil) -> any RoutineRepositoryProtocol {
        if let provider = routineRepositoryProvider { return provider(context) }
        let ctx = context ?? Persistence.session.container.mainContext
        return SwiftDataRoutineRepository(context: ctx)
    }

    static func catalogRepo(for context: ModelContext? = nil) -> any CatalogRepositoryProtocol {
        if let provider = catalogRepositoryProvider { return provider(context) }
        let ctx = context ?? Persistence.session.container.mainContext
        return SwiftDataCatalogRepository(context: ctx)
    }

    static func diaryRepo(for context: ModelContext? = nil) -> any DiaryRepositoryProtocol {
        if let provider = diaryRepositoryProvider { return provider(context) }
        let ctx = context ?? Persistence.session.container.mainContext
        return SwiftDataDiaryRepository(context: ctx)
    }

    // MARK: - 保存与错误反馈

    @discardableResult
    static func persist(context: ModelContext? = nil, _ work: () throws -> Void) -> Bool {
        ModelChanges.perform(in: context ?? Persistence.session.container.mainContext, work)
    }

    @discardableResult
    static func trashAttachment(_ item: AttachmentItem) -> Bool {
        persist(context: item.modelContext) { item.deletedAt = .now }
    }

    @discardableResult
    static func trashProject(id: UUID, context: ModelContext) -> Bool {
        ModelChanges.attempt(in: context) { try catalogRepo(for: context).deleteProject(id: id, soft: true) }
    }

    @discardableResult
    static func trashTag(id: UUID, context: ModelContext) -> Bool {
        ModelChanges.attempt(in: context) { try catalogRepo(for: context).deleteTag(id: id, soft: true) }
    }

    @discardableResult
    static func renameProject(id: UUID, name: String, context: ModelContext) -> Bool {
        ModelChanges.attempt(in: context) {
            try catalogRepo(for: context).updateProject(id: id, name: name, parentID: nil, sortOrder: nil)
        }
    }

    @discardableResult
    static func renameTag(id: UUID, name: String, context: ModelContext) -> Bool {
        ModelChanges.attempt(in: context) {
            try catalogRepo(for: context).updateTag(id: id, name: name, sortOrder: nil)
        }
    }

    @discardableResult
    static func setProjectParent(id: UUID, parentID: UUID?, context: ModelContext) -> Bool {
        ModelChanges.attempt(in: context) {
            try catalogRepo(for: context).updateProject(id: id, name: nil, parentID: .some(parentID), sortOrder: nil)
        }
    }

    static func requestReminderAccessIfNeeded(_ minutes: Int?) {
        if minutes != nil { NotificationScheduler.shared.ensureAuthorization() }
    }

    // MARK: - 待办

    @discardableResult
    static func addTodo(title: String, notes: String = "", dayKey: String, context: ModelContext) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let params = CreateTodoParams(
            title: trimmed, dayKey: dayKey, notes: notes,
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
        )
        return ModelChanges.value(in: context) { try taskRepo(for: context).addTodo(params) } != nil
    }

    @discardableResult
    static func completeTodo(_ todo: TodoItem) -> Bool {
        ModelChanges.attempt(in: todo.modelContext) { try taskRepo(for: todo.modelContext).completeTodo(id: todo.id) }
    }

    @discardableResult
    static func toggleTodo(_ todo: TodoItem) -> Bool {
        ModelChanges.attempt(in: todo.modelContext) { try taskRepo(for: todo.modelContext).toggleTodo(id: todo.id) }
    }

    @discardableResult
    static func editTodo(_ todo: TodoItem, title: String) -> Bool {
        editTodoWithSyntax(todo, rawInput: title)
    }

    @discardableResult
    static func updateNotes(for todo: TodoItem, notes: String) -> Bool {
        saveNotes(notes, for: todo)
    }

    @discardableResult
    static func moveTodo(_ todo: TodoItem, to dayKey: String) -> Bool {
        guard dayKey != todo.dayKey else { return true }
        return ModelChanges.attempt(in: todo.modelContext) { try taskRepo(for: todo.modelContext).moveTodo(id: todo.id, to: dayKey) }
    }

    @discardableResult
    static func setRemind(_ todo: TodoItem, minutes: Int?) -> Bool {
        let saved = ModelChanges.attempt(in: todo.modelContext) {
            try taskRepo(for: todo.modelContext).setRemind(id: todo.id, minutes: minutes)
        }
        if saved { requestReminderAccessIfNeeded(minutes) }
        return saved
    }

    @discardableResult
    static func applyQuadrant(_ slot: QuadrantSlot, to todo: TodoItem) -> Bool {
        ModelChanges.attempt(in: todo.modelContext) {
            try taskRepo(for: todo.modelContext).setPriority(id: todo.id, isImportant: slot.isImportant, isUrgent: slot.isUrgent)
        }
    }

    @discardableResult
    static func trashTodo(_ todo: TodoItem) -> Bool {
        ModelChanges.attempt(in: todo.modelContext) { try taskRepo(for: todo.modelContext).deleteTodo(id: todo.id, soft: true) }
    }

    @discardableResult
    static func restoreTodo(_ todo: TodoItem) -> Bool {
        ModelChanges.attempt(in: todo.modelContext) { try taskRepo(for: todo.modelContext).restoreTodo(id: todo.id) }
    }

    @discardableResult
    static func setProject(for todo: TodoItem, projectID: UUID?) -> Bool {
        ModelChanges.attempt(in: todo.modelContext) { try taskRepo(for: todo.modelContext).setProject(id: todo.id, projectID: projectID) }
    }

    @discardableResult
    static func toggleTag(for todo: TodoItem, tagID: UUID) -> Bool {
        ModelChanges.attempt(in: todo.modelContext) { try taskRepo(for: todo.modelContext).toggleTag(id: todo.id, tagID: tagID) }
    }

    // MARK: - 子任务

    @discardableResult
    static func addSubtask(to todo: TodoItem, title: String, context: ModelContext) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let sub = ModelChanges.value(in: context, {
            try taskRepo(for: context).addSubtask(to: todo.id, title: trimmed)
        }) else { return false }
        if !todo.subtasks.contains(where: { $0.id == sub.id }) { todo.subtasks.append(sub) }
        return true
    }

    @discardableResult
    static func toggleSubtask(_ subtask: SubtaskItem) -> Bool {
        ModelChanges.attempt(in: subtask.modelContext) { try taskRepo(for: subtask.modelContext).toggleSubtask(id: subtask.id) }
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
        ModelChanges.attempt(in: subtask.modelContext) { try taskRepo(for: subtask.modelContext).deleteSubtask(id: subtask.id, soft: true) }
    }

    @discardableResult
    static func reorderSubtasks(for todo: TodoItem, orderedIDs: [UUID]) -> Bool {
        ModelChanges.attempt(in: todo.modelContext) {
            try taskRepo(for: todo.modelContext).reorderSubtasks(for: todo.id, orderedIDs: orderedIDs)
        }
    }

    // MARK: - 习惯

    @discardableResult
    static func setRoutineEnabled(
        _ routine: DailyRoutine, enabled: Bool, todayKey: String,
        checks: [RoutineCheck] = [], context: ModelContext? = nil
    ) -> Bool {
        let context = context ?? routine.modelContext
        return ModelChanges.attempt(in: context) {
            try routineRepo(for: context).setRoutineEnabled(id: routine.id, enabled: enabled, todayKey: todayKey)
        }
    }

    @discardableResult
    static func setWeekdayMask(_ routine: DailyRoutine, mask: Int) -> Bool {
        ModelChanges.attempt(in: routine.modelContext) {
            try routineRepo(for: routine.modelContext).setWeekdayMask(id: routine.id, mask: mask)
        }
    }

    @discardableResult
    static func markRoutineDone(_ routine: DailyRoutine, on dayKey: String) -> Bool {
        ModelChanges.attempt(in: routine.modelContext) {
            try routineRepo(for: routine.modelContext).markRoutineDone(id: routine.id, dayKey: dayKey)
        }
    }

    @discardableResult
    static func toggleRoutine(
        _ routine: DailyRoutine, on dayKey: String,
        checks: [RoutineCheck] = [], context: ModelContext? = nil
    ) -> Bool {
        let context = context ?? routine.modelContext
        return ModelChanges.attempt(in: context) { try routineRepo(for: context).toggleRoutine(id: routine.id, dayKey: dayKey) }
    }

    @discardableResult
    static func skipRoutine(
        _ routine: DailyRoutine, on dayKey: String,
        checks: [RoutineCheck] = [], context: ModelContext? = nil
    ) -> Bool {
        let context = context ?? routine.modelContext
        return ModelChanges.attempt(in: context) { try routineRepo(for: context).skipRoutine(id: routine.id, dayKey: dayKey) }
    }

    @discardableResult
    static func editRoutine(_ routine: DailyRoutine, title: String) -> Bool {
        editRoutineWithSyntax(routine, rawInput: title)
    }

    @discardableResult
    static func updateNotes(for routine: DailyRoutine, notes: String) -> Bool {
        saveNotes(notes, for: routine)
    }

    @discardableResult
    static func setRemind(_ routine: DailyRoutine, minutes: Int?) -> Bool {
        let saved = ModelChanges.attempt(in: routine.modelContext) {
            try routineRepo(for: routine.modelContext).setRemind(id: routine.id, minutes: minutes)
        }
        if saved { requestReminderAccessIfNeeded(minutes) }
        return saved
    }

    @discardableResult
    static func applyQuadrant(_ slot: QuadrantSlot, to routine: DailyRoutine) -> Bool {
        ModelChanges.attempt(in: routine.modelContext) {
            try routineRepo(for: routine.modelContext).setPriority(id: routine.id, isImportant: slot.isImportant, isUrgent: slot.isUrgent)
        }
    }

    @discardableResult
    static func trashRoutine(_ routine: DailyRoutine) -> Bool {
        ModelChanges.attempt(in: routine.modelContext) { try routineRepo(for: routine.modelContext).deleteRoutine(id: routine.id, soft: true) }
    }

    @discardableResult
    static func setProject(for routine: DailyRoutine, projectID: UUID?) -> Bool {
        ModelChanges.attempt(in: routine.modelContext) { try routineRepo(for: routine.modelContext).setProject(id: routine.id, projectID: projectID) }
    }

    @discardableResult
    static func toggleTag(for routine: DailyRoutine, tagID: UUID) -> Bool {
        ModelChanges.attempt(in: routine.modelContext) { try routineRepo(for: routine.modelContext).toggleTag(id: routine.id, tagID: tagID) }
    }

    // MARK: - 标签与手记

    @discardableResult
    static func addTag(
        named name: String, existing: [TagItem] = [], context: ModelContext,
        ontoTodo todo: TodoItem? = nil, ontoRoutine routine: DailyRoutine? = nil
    ) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !DiaryMemoTags.isPresetName(trimmed) else { return false }
        guard let tag = resolveTaskTag(named: trimmed, context: context) else { return false }
        return ModelChanges.attempt(in: context) {
            if let todo, !TagIDList.contains(todo.tagIDs, tag.id) {
                try taskRepo(for: context).toggleTag(id: todo.id, tagID: tag.id)
            }
            if let routine, !TagIDList.contains(routine.tagIDs, tag.id) {
                try routineRepo(for: context).toggleTag(id: routine.id, tagID: tag.id)
            }
        }
    }

    static func resolveTaskTag(named name: String, among existing: [TagItem] = [], context: ModelContext) -> TagItem? {
        ModelChanges.value(in: context) { try catalogRepo(for: context).resolveTaskTag(name: name) } ?? nil
    }

    static func resolveTag(named name: String, among existing: [TagItem] = [], context: ModelContext) -> TagItem? {
        ModelChanges.value(in: context) { try catalogRepo(for: context).resolveOrCreateTag(name: name) }
    }

    @discardableResult
    static func ensureDiaryPresetTags(among tags: [TagItem] = [], context: ModelContext) -> Bool {
        // 仓储负责实际变更的事务；只读检查不应顺带提交上下文中的其他编辑。
        ModelChanges.attempt { try catalogRepo(for: context).ensurePresetTags() }
    }

    @discardableResult
    static func addDiary(
        text: String, dayKey: String, selectedTagIDs: Set<UUID> = [],
        tags: [TagItem] = [], context: ModelContext
    ) -> Bool {
        ModelChanges.value(in: context) {
            try diaryRepo(for: context).addDiary(text: text, dayKey: dayKey, tagIDs: selectedTagIDs)
        } != nil
    }

    @discardableResult
    static func editDiary(_ entry: DiaryEntry, text: String) -> Bool {
        ModelChanges.attempt(in: entry.modelContext) { try diaryRepo(for: entry.modelContext).editDiary(id: entry.id, text: text) }
    }

    @discardableResult
    static func togglePinDiary(_ entry: DiaryEntry) -> Bool {
        ModelChanges.attempt(in: entry.modelContext) { try diaryRepo(for: entry.modelContext).togglePin(id: entry.id) }
    }

    @discardableResult
    static func toggleDiaryTag(_ entry: DiaryEntry, tagID: UUID) -> Bool {
        ModelChanges.attempt(in: entry.modelContext) { try diaryRepo(for: entry.modelContext).toggleTag(id: entry.id, tagID: tagID) }
    }

    @discardableResult
    static func deleteDiary(_ entry: DiaryEntry) -> Bool {
        ModelChanges.attempt(in: entry.modelContext) { try diaryRepo(for: entry.modelContext).deleteDiary(id: entry.id, soft: true) }
    }

    @discardableResult
    static func convertDiaryToTodo(_ entry: DiaryEntry, context: ModelContext) -> Bool {
        let raw = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return false }
        let (title, notes): (String, String) = {
            if let newlineIndex = raw.firstIndex(of: "\n") {
                let firstLine = String(raw[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let rest = String(raw[raw.index(after: newlineIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (firstLine.isEmpty ? rest : firstLine, rest.isEmpty ? "" : rest)
            }
            return (raw, "")
        }()
        return addTodo(title: title, notes: notes, dayKey: DayKey.today(), context: context)
    }

    @discardableResult
    static func moveDiary(_ entry: DiaryEntry, to dayKey: String) -> Bool {
        guard let ctx = entry.modelContext else { return false }
        return ModelChanges.attempt(in: ctx) {
            entry.dayKey = dayKey
        }
    }

    @discardableResult
    static func togglePrivateDiary(_ entry: DiaryEntry) -> Bool {
        guard let ctx = entry.modelContext else { return false }
        return ModelChanges.attempt(in: ctx) {
            entry.isPrivate.toggle()
        }
    }

    static func ownedAttachments(_ context: ModelContext?) -> [AttachmentItem] {
        guard let context else { return [] }
        return ModelChanges.value { try context.fetch(FetchDescriptor<AttachmentItem>()) } ?? []
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
