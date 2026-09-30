import Foundation
import SwiftData

extension DayBoardMutations {
    @discardableResult
    static func setDue(_ todo: TodoItem, minutes: Int?) -> Bool {
        persist(context: todo.modelContext) {
            todo.dueMinutes = RemindMinutes.clamped(minutes)
        }
    }

    @discardableResult
    static func applyManualOrder(_ entries: [ManualOrderEntry], context: ModelContext) -> Bool {
        let changed = entries
        return ModelChanges.perform(in: context) {
            let todos = try context.fetch(FetchDescriptor<TodoItem>())
            let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
            let todoMap = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
            let routineMap = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
            for entry in changed {
                if let todo = todoMap[entry.id] {
                    todo.sortOrder = entry.sortOrder
                } else if let routine = routineMap[entry.id] {
                    routine.sortOrder = entry.sortOrder
                }
            }
        }
    }

    static func convertTodoToRoutine(_ todo: TodoItem) -> UUID? {
        guard let context = todo.modelContext, todo.deletedAt == nil else { return nil }
        let routineID = UUID()
        let titles = todo.subtasks
            .filter { $0.deletedAt == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.title)
        let notes = ItemConversion.foldedNotes(existing: todo.notes, subtaskTitles: titles)
        let order = (try? nextSharedOrder(in: context)) ?? 0
        let saved = ModelChanges.perform(in: context) {
            let routine = DailyRoutine(
                id: routineID,
                title: todo.title,
                sortOrder: order,
                createdDayKey: DayKey.today(),
                weekdayMask: ItemConversion.weekdayMask(for: todo.dayKey),
                remindMinutes: todo.remindMinutes,
                tagIDs: todo.tagIDs,
                isImportant: todo.isImportant,
                isUrgent: todo.isUrgent,
                notes: notes
            )
            routine.sourceBundleID = todo.sourceBundleID
            context.insert(routine)
            try moveAttachments(from: todo.id, kind: .todo, to: routineID, newKind: .routine, in: context)
            let now = SoftDelete.stamp()
            todo.deletedAt = now
            SoftDelete.stampLiveSubtasks(todo.subtasks, at: now)
        }
        guard saved else { return nil }
        CalendarSync.refreshIfEnabled()
        return routineID
    }

    static func convertRoutineToTodo(_ routine: DailyRoutine) -> UUID? {
        guard let context = routine.modelContext, routine.deletedAt == nil else { return nil }
        let todoID = UUID()
        let today = DayKey.today()
        let order = (try? nextSharedOrder(in: context, dayKey: today)) ?? 0
        let saved = ModelChanges.perform(in: context) {
            let todo = TodoItem(
                id: todoID,
                title: routine.title,
                dayKey: today,
                remindMinutes: routine.remindMinutes,
                tagIDs: routine.tagIDs,
                isImportant: routine.isImportant,
                isUrgent: routine.isUrgent,
                sourceBundleID: routine.sourceBundleID,
                notes: routine.notes,
                sortOrder: order
            )
            context.insert(todo)
            try moveAttachments(from: routine.id, kind: .routine, to: todoID, newKind: .todo, in: context)
            routine.deletedAt = SoftDelete.stamp()
        }
        return saved ? todoID : nil
    }

    private static func nextSharedOrder(in context: ModelContext, dayKey: String? = nil) throws -> Int {
        let todos = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.deletedAt == nil }))
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.deletedAt == nil }))
        let todoOrders = todos.filter { dayKey == nil || $0.dayKey == dayKey }.map(\.sortOrder)
        let orders = todoOrders + routines.map(\.sortOrder)
        return (orders.max() ?? -1) + 1
    }

    private static func moveAttachments(
        from ownerID: UUID,
        kind: AttachmentOwner,
        to newID: UUID,
        newKind: AttachmentOwner,
        in context: ModelContext
    ) throws {
        let items = try context.fetch(FetchDescriptor<AttachmentItem>())
        for item in items where item.deletedAt == nil && item.ownerID == ownerID && item.ownerKind == kind.rawValue {
            item.ownerID = newID
            item.ownerKind = newKind.rawValue
        }
    }
}
