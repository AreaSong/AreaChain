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
            return
        }
        modelContext.insert(RoutineCheck(dayKey: todayKey, isDone: true, routine: routine))
    }

    func skipRoutine(_ routine: DailyRoutine) {
        if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == todayKey }) {
            check.isDone = true
            check.isSkipped = true
            return
        }
        modelContext.insert(RoutineCheck(dayKey: todayKey, isDone: true, isSkipped: true, routine: routine))
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
    }

    func moveYesterdayTodo(_ item: UnfinishedItem) {
        guard item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) else { return }
        todo.dayKey = todayKey
    }

    func addRoutineFromPopover() {
        let title = routineDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (routines.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(DailyRoutine(title: title, sortOrder: order))
        routineDraft = ""
        addingRoutine = false
    }
}
