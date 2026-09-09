import SwiftData
import SwiftUI

@MainActor
enum TaskRowFactory {
    static func todo(
        _ todo: TodoItem,
        isDone: Bool,
        todayKey: String,
        projects: [ProjectItem],
        tags: [TagItem],
        attachments: [AttachmentItem],
        context: ModelContext,
        isSelected: Bool,
        isExternalEditing: Bool = false,
        dragPayload: String? = nil,
        note: String? = nil,
        includeSubtasks: Bool = true,
        onSelect: @escaping () -> Void,
        onEndEditing: (() -> Void)? = nil,
        onDelete: @escaping () -> Void
    ) -> TaskRow {
        let liveSubtasks = includeSubtasks
            ? todo.subtasks
                .filter { $0.deletedAt == nil }
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .compactMap(\.snapshot)
            : []
        let state = TaskRowState(
            id: todo.id,
            title: todo.title,
            isDone: isDone,
            note: note,
            remindMinutes: todo.remindMinutes,
            todayKey: todayKey,
            currentDayKey: todo.dayKey,
            isImportant: todo.isImportant,
            isUrgent: todo.isUrgent,
            classify: CatalogChoices.classify(for: todo, projects: projects, tags: tags),
            attachments: CatalogChoices.attachments(
                ownerKind: .todo,
                ownerID: todo.id,
                items: attachments,
                context: context
            ),
            notes: todo.notes,
            subtasks: liveSubtasks,
            dragPayload: dragPayload,
            isSelected: isSelected,
            isExternalEditing: isExternalEditing,
            canSetRemind: true
        )
        return TaskRow(state: state) { action in
            switch action {
            case .toggleDone: DayBoardMutations.toggleTodo(todo)
            case .select: onSelect()
            case .editTitle(let title): DayBoardMutations.editTodo(todo, title: title)
            case .endEditing: onEndEditing?()
            case .delete: onDelete()
            case .skip: break
            case .moveToDay(let day): DayBoardMutations.moveTodo(todo, to: day)
            case .setRemindMinutes(let minutes): DayBoardMutations.setRemind(todo, minutes: minutes)
            case .setWeekdaysOnly, .setEnabled: break
            case .toggleSubtask(let subID):
                if let sub = todo.subtasks.first(where: { $0.id == subID }) {
                    DayBoardMutations.toggleSubtask(sub)
                }
            }
        }
    }

    static func routine(
        _ routine: DailyRoutine,
        isDone: Bool,
        todayKey: String,
        checkDayKey: String,
        checks: [RoutineCheck],
        context: ModelContext,
        locale: Locale,
        projects: [ProjectItem],
        tags: [TagItem],
        attachments: [AttachmentItem],
        isSelected: Bool,
        isExternalEditing: Bool = false,
        note: String? = nil,
        usesDefaultNote: Bool = true,
        onToggle: (() -> Void)? = nil,
        onSelect: @escaping () -> Void,
        onEndEditing: (() -> Void)? = nil,
        onDelete: @escaping () -> Void,
        onSkip: (() -> Void)? = nil
    ) -> TaskRow {
        let resolvedNote: String?
        if let note {
            resolvedNote = note
        } else if usesDefaultNote {
            let skipped = DayBoardLogic.isRoutineSkipped(
                routine.snapshot,
                checks: checks.compactMap(\.snapshot),
                on: checkDayKey
            )
            resolvedNote = isDone
                ? ResidentNote.done(routine, skipped: skipped, locale: locale)
                : ResidentNote.days(routine, locale: locale)
        } else {
            resolvedNote = nil
        }
        let streak = HabitStreakLogic.calculate(
            routine: routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            todayKey: todayKey
        )
        let canSkip = onSkip != nil
        let state = TaskRowState(
            id: routine.id,
            title: routine.title,
            isDone: isDone,
            isResident: true,
            note: resolvedNote,
            streak: streak.currentStreak,
            remindMinutes: routine.remindMinutes,
            isImportant: routine.isImportant,
            isUrgent: routine.isUrgent,
            classify: CatalogChoices.classify(for: routine, projects: projects, tags: tags),
            attachments: CatalogChoices.attachments(
                ownerKind: .routine,
                ownerID: routine.id,
                items: attachments,
                context: context
            ),
            notes: routine.notes,
            isSelected: isSelected,
            isExternalEditing: isExternalEditing,
            canSetRemind: true,
            canSkip: canSkip,
            isEnabled: routine.isEnabled
        )
        return TaskRow(state: state) { action in
            switch action {
            case .toggleDone:
                if let onToggle {
                    onToggle()
                } else {
                    DayBoardMutations.toggleRoutine(
                        routine,
                        on: checkDayKey,
                        checks: checks,
                        context: context
                    )
                }
            case .select: onSelect()
            case .editTitle(let title): DayBoardMutations.editRoutine(routine, title: title)
            case .endEditing: onEndEditing?()
            case .delete: onDelete()
            case .skip: onSkip?()
            case .moveToDay: break
            case .setRemindMinutes(let minutes): DayBoardMutations.setRemind(routine, minutes: minutes)
            case .setWeekdaysOnly: break
            case .setEnabled(let enabled):
                DayBoardMutations.setRoutineEnabled(
                    routine,
                    enabled: enabled,
                    todayKey: todayKey,
                    checks: checks,
                    context: context
                )
            case .toggleSubtask: break
            }
        }
    }

    static func leftoverFallback(
        item: UnfinishedItem,
        todayKey: String,
        yesterdayKey: String,
        isSelected: Bool,
        onToggle: @escaping () -> Void,
        onSelect: @escaping () -> Void,
        onMoveToDay: ((String) -> Void)?
    ) -> TaskRow {
        let state = TaskRowState(
            id: item.id,
            title: item.title,
            isDone: false,
            todayKey: todayKey,
            currentDayKey: yesterdayKey,
            isSelected: isSelected
        )
        return TaskRow(state: state) { action in
            switch action {
            case .toggleDone: onToggle()
            case .select: onSelect()
            case .moveToDay(let day): onMoveToDay?(day)
            default: break
            }
        }
    }
}
