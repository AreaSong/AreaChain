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
        if skipped && routine.weekdaysOnly {
            return L10n.string("note.skipped.weekdays", locale: locale)
        }
        if skipped { return L10n.string("note.skipped", locale: locale) }
        if routine.weekdaysOnly { return L10n.string("note.weekdays", locale: locale) }
        return nil
    }

    func moveTodo(_ todo: TodoItem, to dayKey: String) {
        guard dayKey != todo.dayKey else { return }
        persist { todo.dayKey = dayKey }
    }

    func moveYesterdayTodo(_ item: UnfinishedItem, to dayKey: String) {
        guard item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) else { return }
        moveTodo(todo, to: dayKey)
    }

    func addResident() {
        let title = residentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (routines.map(\.sortOrder).max() ?? -1) + 1
        persist {
            modelContext.insert(DailyRoutine(title: title, sortOrder: order))
            residentDraft = ""
        }
    }

    func deleteRoutine(_ routine: DailyRoutine) {
        persist { modelContext.delete(routine) }
    }

    func disableRoutine(_ routine: DailyRoutine) {
        persist { routine.isEnabled = false }
    }

    func enableRoutine(_ routine: DailyRoutine) {
        persist { routine.isEnabled = true }
    }

    func setWeekdays(_ routine: DailyRoutine, _ weekdaysOnly: Bool) {
        persist { routine.weekdaysOnly = weekdaysOnly }
    }

    func setRemind(_ routine: DailyRoutine, minutes: Int?) {
        persist { routine.remindMinutes = RemindMinutes.clamped(minutes) }
        if minutes != nil {
            NotificationScheduler.shared.ensureAuthorization()
        }
    }

    func setRemind(_ todo: TodoItem, minutes: Int?) {
        persist { todo.remindMinutes = RemindMinutes.clamped(minutes) }
        if minutes != nil {
            NotificationScheduler.shared.ensureAuthorization()
        }
    }

    func editRoutine(_ routine: DailyRoutine, title: String) {
        persist { routine.title = title }
    }

    func editTodo(_ todo: TodoItem, title: String) {
        persist { todo.title = title }
    }

    func deleteTodo(_ todo: TodoItem) {
        persist { modelContext.delete(todo) }
    }

    func toggleTodo(_ todo: TodoItem) {
        persist { todo.isDone.toggle() }
    }
}
