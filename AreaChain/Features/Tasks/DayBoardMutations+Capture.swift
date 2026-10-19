import Foundation
import SwiftData

extension DayBoardMutations {
    @discardableResult
    static func addCapturedTodo(
        text: String, dayKey: String, context: ModelContext, tagIDs: [UUID] = [],
        fallbackQuadrant: QuadrantSlot? = nil,
        dependencies: TaskMutationService.Dependencies? = nil
    ) -> Bool {
        var resolved = dependencies ?? .production
        if dependencies == nil {
            resolved.repository = { taskRepo(for: $0) }
            resolved.requestReminderAccessIfNeeded = { requestReminderAccessIfNeeded($0) }
        }
        return TaskMutationService.createCaptured(
            .init(text: text, dayKey: dayKey, tagIDs: tagIDs, fallbackQuadrant: fallbackQuadrant),
            in: context, dependencies: resolved
        ).saved
    }

    /// 快速新增规则只在 RoutineCaptureService 一处；这里保留原签名供重复事项面板调用。
    @discardableResult
    static func addCapturedRoutine(text: String, sortOrder: Int, context: ModelContext) -> Bool {
        RoutineCaptureService.capture(.init(text: text, sortOrder: sortOrder), in: context,
                                      repository: routineRepo(for: context),
                                      requestReminderAccess: requestReminderAccessIfNeeded)
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
            let routine = try routineRepo(for: context).addRoutine(CreateRoutineParams(
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
            InputAttachmentResolver.linkIfPresent(
                in: draft.title + "\n" + draft.notes,
                ownerKind: .routine,
                ownerID: routine.id,
                context: context
            )
        }
        if saved { requestReminderAccessIfNeeded(remind) }
        return saved
    }

    @discardableResult
    static func editTodoWithSyntax(_ todo: TodoItem, rawInput: String,
                                   dependencies: TaskMutationService.TitleDependencies? = nil) -> Bool {
        guard !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let context = todo.modelContext ?? Persistence.session.container.mainContext
        var resolved = dependencies ?? .production
        if dependencies == nil {
            resolved.repository = { taskRepo(for: $0) }
            resolved.requestReminderAccessIfNeeded = { requestReminderAccessIfNeeded($0) }
        }
        return TaskMutationService.editTitle(todo, rawInput: rawInput, in: context, dependencies: resolved).saved
    }

    @discardableResult
    static func editRoutineWithSyntax(_ routine: DailyRoutine, rawInput: String,
                                      dependencies: RoutineMutationService.Dependencies? = nil) -> Bool {
        guard !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let context = routine.modelContext ?? Persistence.session.container.mainContext
        let resolved = dependencies ?? .init(repository: { routineRepo(for: $0) }, transaction: .init(),
            registerLocalModification: { _ in }, requestReminderAccessIfNeeded: { requestReminderAccessIfNeeded($0) })
        let ok = RoutineMutationService.editTitle(routine, rawInput: rawInput, in: context, dependencies: resolved).callSucceeded
        if ok, !AttachmentSyntax.names(in: rawInput).isEmpty {
            _ = ModelChanges.perform(in: context) {
                InputAttachmentResolver.linkIfPresent(in: rawInput, ownerKind: .routine, ownerID: routine.id, context: context)
            }
        }
        return ok
    }

    /// 备注规则只在 TaskNotesService 一处；这里保留原签名与原上下文回退供详情页调用。
    static func saveNotes(_ notes: String, for todo: TodoItem) -> Bool {
        let context = todo.modelContext ?? Persistence.session.container.mainContext
        return TaskNotesService.save(notes, for: todo, in: context, repository: taskRepo(for: context),
                                     requestReminderAccess: requestReminderAccessIfNeeded)
    }

    static func saveNotes(_ notes: String, for routine: DailyRoutine) -> Bool {
        let context = routine.modelContext ?? Persistence.session.container.mainContext
        return TaskNotesService.save(notes, for: routine, in: context, repository: routineRepo(for: context),
                                     requestReminderAccess: requestReminderAccessIfNeeded)
    }
}
