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

    // MARK: - 基础持久化与通知协调 (Coordination)

    static func persist(_ work: () -> Void) {
        work()
        BoardEvents.changed()
    }

    static func requestReminderAccessIfNeeded(_ minutes: Int?) {
        if minutes != nil {
            NotificationScheduler.shared.ensureAuthorization()
        }
    }

    // MARK: - 待办操作委托 (Todo Operations)

    @discardableResult
    static func addTodo(title: String, notes: String = "", dayKey: String, context: ModelContext) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let params = CreateTodoParams(
            title: trimmed,
            dayKey: dayKey,
            notes: notes,
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
        )
        return (try? taskRepo(for: context).addTodo(params)) != nil
    }

    static func completeTodo(_ todo: TodoItem) {
        try? taskRepo(for: todo.modelContext).completeTodo(id: todo.id)
    }

    static func toggleTodo(_ todo: TodoItem) {
        try? taskRepo(for: todo.modelContext).toggleTodo(id: todo.id)
    }

    static func editTodo(_ todo: TodoItem, title: String) {
        try? taskRepo(for: todo.modelContext).updateTodo(id: todo.id, title: title, notes: nil)
    }

    static func updateNotes(for todo: TodoItem, notes: String) {
        try? taskRepo(for: todo.modelContext).updateTodo(id: todo.id, title: nil, notes: notes)
    }

    static func moveTodo(_ todo: TodoItem, to dayKey: String) {
        guard dayKey != todo.dayKey else { return }
        try? taskRepo(for: todo.modelContext).moveTodo(id: todo.id, to: dayKey)
    }

    static func setRemind(_ todo: TodoItem, minutes: Int?) {
        try? taskRepo(for: todo.modelContext).setRemind(id: todo.id, minutes: minutes)
        requestReminderAccessIfNeeded(minutes)
    }

    static func applyQuadrant(_ slot: QuadrantSlot, to todo: TodoItem) {
        try? taskRepo(for: todo.modelContext).setPriority(
            id: todo.id,
            isImportant: slot.isImportant,
            isUrgent: slot.isUrgent
        )
    }

    static func trashTodo(_ todo: TodoItem) {
        try? taskRepo(for: todo.modelContext).deleteTodo(id: todo.id, soft: true)
    }

    static func restoreTodo(_ todo: TodoItem) {
        try? taskRepo(for: todo.modelContext).restoreTodo(id: todo.id)
    }

    static func setProject(for todo: TodoItem, projectID: UUID?) {
        try? taskRepo(for: todo.modelContext).setProject(id: todo.id, projectID: projectID)
    }

    static func toggleTag(for todo: TodoItem, tagID: UUID) {
        try? taskRepo(for: todo.modelContext).toggleTag(id: todo.id, tagID: tagID)
    }

    // MARK: - 子任务操作委托 (Subtask Operations)

    @discardableResult
    static func addSubtask(to todo: TodoItem, title: String, context: ModelContext) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let sub = try? taskRepo(for: context).addSubtask(to: todo.id, title: trimmed) else {
            return false
        }
        if !todo.subtasks.contains(where: { $0.id == sub.id }) {
            todo.subtasks.append(sub)
        }
        return true
    }

    static func toggleSubtask(_ subtask: SubtaskItem) {
        try? taskRepo(for: subtask.modelContext).toggleSubtask(id: subtask.id)
    }

    static func editSubtask(_ subtask: SubtaskItem, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? taskRepo(for: subtask.modelContext).editSubtask(id: subtask.id, title: trimmed)
    }

    static func deleteSubtask(_ subtask: SubtaskItem) {
        try? taskRepo(for: subtask.modelContext).deleteSubtask(id: subtask.id, soft: true)
    }

    static func reorderSubtasks(for todo: TodoItem, orderedIDs: [UUID]) {
        try? taskRepo(for: todo.modelContext).reorderSubtasks(for: todo.id, orderedIDs: orderedIDs)
    }

    // MARK: - 习惯操作委托 (Routine Operations)

    static func setRoutineEnabled(
        _ routine: DailyRoutine,
        enabled: Bool,
        todayKey: String,
        checks: [RoutineCheck] = [],
        context: ModelContext? = nil
    ) {
        let repo = routineRepo(for: context ?? routine.modelContext)
        try? repo.setRoutineEnabled(id: routine.id, enabled: enabled, todayKey: todayKey)
    }

    static func toggleRoutine(
        _ routine: DailyRoutine,
        on dayKey: String,
        checks: [RoutineCheck] = [],
        context: ModelContext? = nil
    ) {
        let repo = routineRepo(for: context ?? routine.modelContext)
        try? repo.toggleRoutine(id: routine.id, dayKey: dayKey)
    }

    static func skipRoutine(
        _ routine: DailyRoutine,
        on dayKey: String,
        checks: [RoutineCheck] = [],
        context: ModelContext? = nil
    ) {
        let repo = routineRepo(for: context ?? routine.modelContext)
        try? repo.skipRoutine(id: routine.id, dayKey: dayKey)
    }

    static func editRoutine(_ routine: DailyRoutine, title: String) {
        try? routineRepo(for: routine.modelContext).updateRoutine(id: routine.id, title: title, notes: nil)
    }

    static func updateNotes(for routine: DailyRoutine, notes: String) {
        try? routineRepo(for: routine.modelContext).updateRoutine(id: routine.id, title: nil, notes: notes)
    }

    static func setRemind(_ routine: DailyRoutine, minutes: Int?) {
        try? routineRepo(for: routine.modelContext).setRemind(id: routine.id, minutes: minutes)
        requestReminderAccessIfNeeded(minutes)
    }

    static func applyQuadrant(_ slot: QuadrantSlot, to routine: DailyRoutine) {
        try? routineRepo(for: routine.modelContext).setPriority(
            id: routine.id,
            isImportant: slot.isImportant,
            isUrgent: slot.isUrgent
        )
    }

    static func trashRoutine(_ routine: DailyRoutine) {
        try? routineRepo(for: routine.modelContext).deleteRoutine(id: routine.id, soft: true)
    }

    static func setProject(for routine: DailyRoutine, projectID: UUID?) {
        try? routineRepo(for: routine.modelContext).setProject(id: routine.id, projectID: projectID)
    }

    static func toggleTag(for routine: DailyRoutine, tagID: UUID) {
        try? routineRepo(for: routine.modelContext).toggleTag(id: routine.id, tagID: tagID)
    }

    // MARK: - 标签与目录操作委托 (Catalog Operations)

    @discardableResult
    static func addTag(
        named name: String,
        existing: [TagItem] = [],
        context: ModelContext,
        ontoTodo todo: TodoItem? = nil,
        ontoRoutine routine: DailyRoutine? = nil
    ) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !DiaryMemoTags.isPresetName(trimmed) else { return false }
        guard let tag = try? catalogRepo(for: context).resolveTaskTag(name: trimmed) else { return false }
        if let todo, !TagIDList.contains(todo.tagIDs, tag.id) {
            try? taskRepo(for: context).toggleTag(id: todo.id, tagID: tag.id)
        }
        if let routine, !TagIDList.contains(routine.tagIDs, tag.id) {
            try? routineRepo(for: context).toggleTag(id: routine.id, tagID: tag.id)
        }
        return true
    }

    static func resolveTaskTag(
        named name: String,
        among existing: [TagItem] = [],
        context: ModelContext
    ) -> TagItem? {
        try? catalogRepo(for: context).resolveTaskTag(name: name)
    }

    static func resolveTag(
        named name: String,
        among existing: [TagItem] = [],
        context: ModelContext
    ) -> TagItem? {
        try? catalogRepo(for: context).resolveOrCreateTag(name: name)
    }

    static func ensureDiaryPresetTags(among tags: [TagItem] = [], context: ModelContext) {
        try? catalogRepo(for: context).ensurePresetTags()
    }

    // MARK: - 灵感手记操作委托 (Diary Operations)

    static func addDiary(
        text: String,
        dayKey: String,
        selectedTagIDs: Set<UUID> = [],
        tags: [TagItem] = [],
        context: ModelContext
    ) {
        _ = try? diaryRepo(for: context).addDiary(text: text, dayKey: dayKey, tagIDs: selectedTagIDs)
    }

    static func editDiary(_ entry: DiaryEntry, text: String) {
        try? diaryRepo(for: entry.modelContext).editDiary(id: entry.id, text: text)
    }

    static func togglePinDiary(_ entry: DiaryEntry) {
        try? diaryRepo(for: entry.modelContext).togglePin(id: entry.id)
    }

    static func toggleDiaryTag(_ entry: DiaryEntry, tagID: UUID) {
        try? diaryRepo(for: entry.modelContext).toggleTag(id: entry.id, tagID: tagID)
    }

    static func deleteDiary(_ entry: DiaryEntry) {
        try? diaryRepo(for: entry.modelContext).deleteDiary(id: entry.id, soft: true)
    }

    static func ownedAttachments(_ context: ModelContext?) -> [AttachmentItem] {
        guard let context else { return [] }
        return (try? context.fetch(FetchDescriptor<AttachmentItem>())) ?? []
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
