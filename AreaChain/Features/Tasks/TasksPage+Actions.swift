import SwiftData

extension TasksPage {
    func isSkipped(_ routine: DailyRoutine) -> Bool {
        DayBoardLogic.isRoutineSkipped(routine.snapshot, checks: snapshots.1, on: todayKey)
    }

    func toggleRoutine(_ routine: DailyRoutine) {
        if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == todayKey }) {
            check.isDone.toggle()
            if !check.isDone {
                check.isSkipped = false
            }
            BoardEvents.changed()
            return
        }
        modelContext.insert(RoutineCheck(dayKey: todayKey, isDone: true, routine: routine))
        BoardEvents.changed()
    }

    func skipRoutine(_ routine: DailyRoutine) {
        if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == todayKey }) {
            check.isDone = true
            check.isSkipped = true
            BoardEvents.changed()
            return
        }
        modelContext.insert(RoutineCheck(dayKey: todayKey, isDone: true, isSkipped: true, routine: routine))
        BoardEvents.changed()
    }

    func completeYesterday(_ item: UnfinishedItem) {
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
        BoardEvents.changed()
    }

    func doneRoutineNote(_ routine: DailyRoutine) -> String? {
        let skipped = isSkipped(routine)
        if skipped && routine.weekdaysOnly { return "已跳过 · 仅工作日" }
        if skipped { return "已跳过" }
        if routine.weekdaysOnly { return "仅工作日" }
        return nil
    }

    func moveTodo(_ todo: TodoItem, to dayKey: String) {
        guard dayKey != todo.dayKey else { return }
        todo.dayKey = dayKey
        BoardEvents.changed()
    }

    func moveYesterdayTodo(_ item: UnfinishedItem, to dayKey: String) {
        guard item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) else { return }
        moveTodo(todo, to: dayKey)
    }

    func addRoutineFromPopover() {
        let title = routineDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (routines.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(DailyRoutine(title: title, sortOrder: order))
        routineDraft = ""
        addingRoutine = false
        BoardEvents.changed()
    }
}
