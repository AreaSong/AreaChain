import SwiftUI

extension WorkspaceItemsList {
    @ViewBuilder
    func flatSubtaskRows(for entry: WorkspaceItemEntry) -> some View {
        if AppPreferences.shared.expandSubtasksByDefault {
            switch entry {
            case .todo(let todo, _, let subtaskIDs):
                let items = FlatSubtaskItem.build(
                    for: todo,
                    tags: tags,
                    allowedIDs: subtaskIDs,
                    isDone: todo.isDone ? nil : false
                )
                ForEach(items) { subItem in
                    flatSubtaskRow(subItem, parent: todo)
                }
            case .routine(let routine, let day, _, _, _):
                let items = FlatSubtaskItem.build(
                    for: routine,
                    checks: checks,
                    dayKey: day,
                    tags: tags
                )
                ForEach(items) { subItem in
                    flatSubtaskRow(subItem, routine: routine, dayKey: day)
                }
            }
        }
    }

    private func flatSubtaskRow(_ subItem: FlatSubtaskItem, parent: TodoItem, showsParentBadge: Bool = false) -> some View {
        FlatSubtaskRow(
            item: subItem,
            isSelected: false,
            showsParentBadge: showsParentBadge,
            reduceMotion: reduceMotion,
            onToggle: {
                guard let sub = parent.subtasks.first(where: { $0.id == subItem.id && $0.deletedAt == nil }) else { return }
                _ = DayBoardMutations.toggleSubtask(sub)
            },
            onSelect: { selectTask(parent.id) },
            onDelete: {
                guard let sub = parent.subtasks.first(where: { $0.id == subItem.id && $0.deletedAt == nil }) else { return }
                askTrash(title: sub.title) { _ = DayBoardMutations.deleteSubtask(sub) }
            }
        )
    }

    private func flatSubtaskRow(_ subItem: FlatSubtaskItem, routine: DailyRoutine, dayKey: String) -> some View {
        FlatSubtaskRow(
            item: subItem,
            isSelected: false,
            showsParentBadge: false,
            reduceMotion: reduceMotion,
            onToggle: {
                _ = DayBoardMutations.toggleRoutineSubtask(routine, subtaskID: subItem.id, on: dayKey)
            },
            onSelect: { selectTask(routine.id) },
            onDelete: {
                askTrash(title: subItem.subtask.title) {
                    _ = DayBoardMutations.deleteRoutineSubtask(routine: routine, subtaskID: subItem.id)
                }
            }
        )
    }
}
