import Foundation
import SwiftData

/// 待办与习惯互转的唯一业务入口：详情页按钮（经 DayBoardMutations）与 T8 指令共用。
/// 总是新建新 UUID 的对象并软删原对象，不就地改类型；保存与发布由所在的 ModelChanges 决定。
@MainActor
enum ItemConversionService {
    /// 时刻、日期键与星期日历可注入；默认值与原实现一致。
    struct Clock {
        var now: () -> Date = { SoftDelete.stamp() }
        var today: () -> String = { DayKey.today() }
        var calendar: Calendar = .current
    }

    @MainActor
    struct Dependencies {
        var clock = Clock()
        var makeID: () -> UUID = { UUID() }
        var transaction = ModelChanges.Boundary()
        /// 原实现只在待办转习惯保存成功后额外请求一次日历刷新；两个方向的发布本身都会请求刷新，
        /// 这里保持原有的不对称，不擅自改变生产行为（结论见 docs/unified-search-commands.md 的“待办与重复事项互转”）。
        var refreshCalendar: @MainActor () -> Void = { CalendarSync.refreshIfEnabled() }

        static var production: Dependencies { Dependencies() }
    }

    static func convertTodoToRoutine(_ todo: TodoItem) -> UUID? {
        convertTodoToRoutine(todo, dependencies: .production)
    }

    static func convertRoutineToTodo(_ routine: DailyRoutine) -> UUID? {
        convertRoutineToTodo(routine, dependencies: .production)
    }

    /// 界面入口：原对象须仍存活且有 context；一次 ModelChanges，成功才返回新 ID。
    static func convertTodoToRoutine(_ todo: TodoItem, dependencies: Dependencies) -> UUID? {
        guard let context = todo.modelContext, todo.deletedAt == nil else { return nil }
        let routineID = dependencies.makeID()
        let saved = ModelChanges.perform(in: context, boundary: dependencies.transaction) {
            _ = try applyTodoToRoutine(todo, routineID: routineID, in: context, clock: dependencies.clock)
        }
        guard saved else { return nil }
        dependencies.refreshCalendar()
        return routineID
    }

    static func convertRoutineToTodo(_ routine: DailyRoutine, dependencies: Dependencies) -> UUID? {
        guard let context = routine.modelContext, routine.deletedAt == nil else { return nil }
        let todoID = dependencies.makeID()
        let saved = ModelChanges.perform(in: context, boundary: dependencies.transaction) {
            _ = try applyRoutineToTodo(routine, todoID: todoID, in: context, clock: dependencies.clock)
        }
        return saved ? todoID : nil
    }

    /// 只在调用方事务内写入，不保存、不发布。活子任务按顺序变成模板（新 UUID，不保留完成态），
    /// 活附件改挂到新习惯，原待办与活子任务用同一时间戳软删。
    static func applyTodoToRoutine(_ todo: TodoItem, routineID: UUID, in context: ModelContext,
                                   clock: Clock) throws -> DailyRoutine {
        let templates = liveSubtasks(of: todo).map {
            RoutineSubtaskTemplate(id: UUID(), title: $0.title, sortOrder: $0.sortOrder, tagIDs: $0.tagIDs)
        }
        let order = (try? nextSharedOrder(in: context)) ?? 0
        let routine = DailyRoutine(
            id: routineID,
            title: todo.title,
            sortOrder: order,
            createdDayKey: clock.today(),
            weekdayMask: weekdayMask(for: todo, calendar: clock.calendar),
            remindMinutes: todo.remindMinutes,
            tagIDs: todo.tagIDs,
            isImportant: todo.isImportant,
            isUrgent: todo.isUrgent,
            notes: todo.notes
        )
        routine.sourceBundleID = todo.sourceBundleID
        routine.subtaskTemplates = templates
        context.insert(routine)
        try moveAttachments(from: todo.id, kind: .todo, to: routineID, newKind: .routine, in: context)
        let now = clock.now()
        todo.deletedAt = now
        SoftDelete.stampLiveSubtasks(todo.subtasks, at: now)
        return routine
    }

    /// 新建今天的待办；模板变成未完成的新子任务，活附件改挂，原习惯软删（打卡记录留在原习惯上）。
    static func applyRoutineToTodo(_ routine: DailyRoutine, todoID: UUID, in context: ModelContext,
                                   clock: Clock) throws -> TodoItem {
        let today = clock.today()
        let order = (try? nextSharedOrder(in: context, dayKey: today)) ?? 0
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
        for template in orderedTemplates(of: routine) {
            let subtask = SubtaskItem(
                id: UUID(),
                title: template.title,
                isDone: false,
                sortOrder: template.sortOrder,
                tagIDs: template.tagIDs,
                todo: todo
            )
            context.insert(subtask)
        }
        try moveAttachments(from: routine.id, kind: .routine, to: todoID, newKind: .todo, in: context)
        routine.deletedAt = clock.now()
        return todo
    }

    /// 预览与写入共用：哪些子任务会变成模板、模板会变成哪些子任务、新习惯取哪些星期。
    static func liveSubtasks(of todo: TodoItem) -> [SubtaskItem] {
        todo.subtasks.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func orderedTemplates(of routine: DailyRoutine) -> [RoutineSubtaskTemplate] {
        routine.subtaskTemplates.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func weekdayMask(for todo: TodoItem, calendar: Calendar) -> Int {
        ItemConversion.weekdayMask(for: todo.dayKey, calendar: calendar)
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
