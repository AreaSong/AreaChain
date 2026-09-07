import Foundation
import SwiftData

extension TasksPage {
    func persist(_ work: () -> Void) {
        work()
        BoardEvents.changed()
    }

    func isSkipped(_ routine: DailyRoutine) -> Bool {
        DayBoardLogic.isRoutineSkipped(routine.snapshot, checks: snapshots.1, on: todayKey)
    }

    func toggleRoutine(_ routine: DailyRoutine) {
        persist {
            if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == todayKey }) {
                check.isDone.toggle()
                if !check.isDone {
                    check.isSkipped = false
                }
                return
            }
            modelContext.insert(RoutineCheck(dayKey: todayKey, isDone: true, routine: routine))
        }
    }

    func skipRoutine(_ routine: DailyRoutine) {
        persist {
            if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == todayKey }) {
                check.isDone = true
                check.isSkipped = true
                return
            }
            modelContext.insert(RoutineCheck(dayKey: todayKey, isDone: true, isSkipped: true, routine: routine))
        }
    }

    func completeYesterday(_ item: UnfinishedItem) {
        persist {
            switch item.kind {
            case .todo:
                todos.first { $0.id == item.id }?.isDone = true
            case .routine:
                guard let routine = routines.first(where: { $0.id == item.id }) else { return }
                if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == yesterdayKey }) {
                    check.isDone = true
                } else {
                    modelContext.insert(RoutineCheck(dayKey: yesterdayKey, isDone: true, routine: routine))
                }
            }
        }
    }

    func doneRoutineNote(_ routine: DailyRoutine) -> String? {
        let skipped = isSkipped(routine)
        let locale = AppPreferences.shared.resolvedLocale
        let days = daysNote(routine, locale: locale)
        if skipped {
            if let days {
                return L10n.string("note.skipped", locale: locale) + " · " + days
            }
            return L10n.string("note.skipped", locale: locale)
        }
        return days
    }

    func daysNote(_ routine: DailyRoutine, locale: Locale) -> String? {
        let mask = routine.resolvedWeekdayMask
        if WeekdayMask.isAll(mask) { return nil }
        if WeekdayMask.isWorkdays(mask) { return L10n.string("note.weekdays", locale: locale) }
        return WeekdayMask.selectedLabels(mask, locale: locale)
    }

    func moveTodo(_ todo: TodoItem, to dayKey: String) {
        guard dayKey != todo.dayKey else { return }
        persist { todo.dayKey = dayKey }
    }

    func moveYesterdayTodo(_ item: UnfinishedItem, to dayKey: String) {
        guard item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) else { return }
        moveTodo(todo, to: dayKey)
    }

    func setRemind(_ todo: TodoItem, minutes: Int?) {
        persist { todo.remindMinutes = RemindMinutes.clamped(minutes) }
        if minutes != nil {
            NotificationScheduler.shared.ensureAuthorization()
        }
    }

    func editTodo(_ todo: TodoItem, title: String) {
        persist { todo.title = title }
    }

    func deleteTodo(_ todo: TodoItem) {
        pendingTrash = PendingTrash(title: todo.title) {
            persist { todo.deletedAt = .now }
        }
    }

    func toggleTodo(_ todo: TodoItem) {
        persist { todo.isDone.toggle() }
    }
}
