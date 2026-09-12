import SwiftData
import SwiftUI

@MainActor
enum TaskRowFactory {
    static func todo(_ context: TodoRowContext) -> TaskRow {
        let state = makeTodoState(context)
        return TaskRow(state: state, onSaveTitle: { DayBoardMutations.editTodoWithSyntax(context.todo, rawInput: $0) }) { action in
            handleTodoAction(action, context: context)
        }
    }

    static func routine(_ context: RoutineRowContext) -> TaskRow {
        let state = makeRoutineState(context: context)
        return TaskRow(state: state, onSaveTitle: { DayBoardMutations.editRoutineWithSyntax(context.routine, rawInput: $0) }) { action in
            handleRoutineAction(action, context: context)
        }
    }

    static func leftoverFallback(_ context: LeftoverRowContext) -> TaskRow {
        let state = TaskRowState(
            identity: TaskRowIdentityState(
                id: context.item.id,
                title: context.item.title
            ),
            schedule: TaskRowScheduleState(
                todayKey: context.todayKey,
                currentDayKey: context.yesterdayKey
            ),
            interaction: TaskRowInteractionState(
                selection: TaskRowSelectionState(isSelected: context.isSelected)
            )
        )
        return TaskRow(state: state) { action in
            switch action {
            case .toggleDone: context.actions.onToggle()
            case .select: context.actions.onSelect()
            case .moveToDay(let day): context.actions.onMoveToDay?(day)
            default: break
            }
        }
    }

    // MARK: - Private Helpers

    private static func makeTodoState(_ context: TodoRowContext) -> TaskRowState {
        let liveSubtasks = context.display.includeSubtasks
            ? context.todo.subtasks
                .filter { $0.deletedAt == nil }
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .compactMap(\.snapshot)
            : []
        let identity = TaskRowIdentityState(
            id: context.todo.id,
            title: context.todo.title,
            isDone: context.display.isDone,
            priority: TaskPriorityFlags(
                isImportant: context.todo.isImportant,
                isUrgent: context.todo.isUrgent
            )
        )
        let schedule = TaskRowScheduleState(
            todayKey: context.todayKey,
            currentDayKey: context.todo.dayKey,
            remindMinutes: context.todo.remindMinutes
        )
        let content = TaskRowContentState(
            note: context.display.note,
            notes: context.todo.notes,
            subtasks: liveSubtasks,
            attachments: context.catalogs.attachments(ownerKind: .todo, ownerID: context.todo.id),
            classify: context.catalogs.classify(for: context.todo)
        )
        let interaction = TaskRowInteractionState(
            selection: context.display.selection,
            dragPayload: context.display.dragPayload,
            canSetRemind: true
        )
        return TaskRowState(
            identity: identity,
            schedule: schedule,
            content: content,
            interaction: interaction
        )
    }

    private static func handleTodoAction(_ action: TaskRowAction, context: TodoRowContext) {
        let todo = context.todo
        switch action {
        case .toggleDone: DayBoardMutations.toggleTodo(todo)
        case .select: context.actions.onSelect()
        case .editTitle(let title): DayBoardMutations.editTodoWithSyntax(todo, rawInput: title)
        case .endEditing: context.actions.onEndEditing?()
        case .delete: context.actions.onDelete()
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

    private static func resolveResidentNote(context: RoutineRowContext) -> String? {
        if let note = context.display.note {
            return note
        }
        guard context.display.usesDefaultNote else { return nil }
        let skipped = DayBoardLogic.isRoutineSkipped(
            context.routine.snapshot,
            checks: context.schedule.checks.compactMap(\.snapshot),
            on: context.schedule.checkDayKey
        )
        return context.display.isDone
            ? ResidentNote.done(context.routine, skipped: skipped, locale: context.schedule.locale)
            : ResidentNote.days(context.routine, locale: context.schedule.locale)
    }

    private static func makeRoutineState(context: RoutineRowContext) -> TaskRowState {
        let streak = HabitStreakLogic.calculate(
            routine: context.routine.snapshot,
            checks: context.schedule.checks.compactMap(\.snapshot),
            todayKey: context.schedule.todayKey
        )
        let identity = TaskRowIdentityState(
            id: context.routine.id,
            title: context.routine.title,
            isDone: context.display.isDone,
            isResident: true,
            priority: TaskPriorityFlags(
                isImportant: context.routine.isImportant,
                isUrgent: context.routine.isUrgent
            )
        )
        let schedule = TaskRowScheduleState(
            remindMinutes: context.routine.remindMinutes,
            streak: streak.currentStreak
        )
        let content = TaskRowContentState(
            note: resolveResidentNote(context: context),
            notes: context.routine.notes,
            attachments: context.catalogs.attachments(ownerKind: .routine, ownerID: context.routine.id),
            classify: context.catalogs.classify(for: context.routine)
        )
        let interaction = TaskRowInteractionState(
            selection: context.display.selection,
            canSetRemind: true,
            canSkip: context.actions.onSkip != nil,
            isEnabled: context.routine.isEnabled
        )
        return TaskRowState(
            identity: identity,
            schedule: schedule,
            content: content,
            interaction: interaction
        )
    }

    private static func handleRoutineAction(_ action: TaskRowAction, context: RoutineRowContext) {
        let routine = context.routine
        switch action {
        case .toggleDone:
            if let onToggle = context.actions.onToggle {
                onToggle()
            } else {
                DayBoardMutations.toggleRoutine(
                    routine,
                    on: context.schedule.checkDayKey,
                    checks: context.schedule.checks,
                    context: context.catalogs.context
                )
            }
        case .select: context.actions.onSelect()
        case .editTitle(let title): DayBoardMutations.editRoutineWithSyntax(routine, rawInput: title)
        case .endEditing: context.actions.onEndEditing?()
        case .delete: context.actions.onDelete()
        case .skip: context.actions.onSkip?()
        case .moveToDay: break
        case .setRemindMinutes(let minutes): DayBoardMutations.setRemind(routine, minutes: minutes)
        case .setWeekdaysOnly: break
        case .setEnabled(let enabled):
            DayBoardMutations.setRoutineEnabled(
                routine,
                enabled: enabled,
                todayKey: context.schedule.todayKey,
                checks: context.schedule.checks,
                context: context.catalogs.context
            )
        case .toggleSubtask: break
        }
    }
}
