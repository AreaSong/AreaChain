import Foundation
import SwiftData

/// 三个排序指令都用 1 起的 position 数字参数，不依赖对象选择器的登记顺序。字段是“在列表里的位置”而不是
/// 原 sortOrder：位置不变时预览前后相等，按无变化处理、不写库；写后再读的位置必须等于预览。

/// subtask.order → reorderSubtasks(for:orderedIDs:)：同一父任务内的活子任务（与详情页同序）移到指定位置。
@MainActor struct SubtaskOrderSpec: SimpleCommandSpec {
    let dependencies: TaskCommandDependencies
    let command = CommandID(rawValue: "subtask.order")
    let shape = CommandSimpleShape.single(.subtask)
    let copy = CommandSimpleCopy(preview: "unified.simple.order.preview", saved: "unified.simple.order.saved")

    /// 详情页按 sortOrder 排活子任务；同值时再按 UUID，保证每次读取顺序一致。
    private func siblings(_ input: CommandResolvedInput, in context: ModelContext) throws -> (TodoItem, [SubtaskItem]) {
        let target = input.targets.objects[0]
        let subtask = try TaskCommandSpecs.subtask(target.id, in: context)
        guard let argument = input.arguments.first(where: { $0.parameter == .parent }),
              case .object(let parent)? = argument.value, parent.type == .todo else { throw CommandSimpleIssue.invalidArguments }
        guard let todo = subtask.todo, todo.id == parent.id else { throw CommandSimpleIssue.invalidTarget(.parentMismatch) }
        _ = try TaskCommandSpecs.todo(parent.id, in: context)
        try TaskCommandSpecs.qualify(parent, dependencies)
        try TaskCommandSpecs.qualify(target, dependencies)
        let live = todo.subtasks.filter { $0.deletedAt == nil }
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
        return (todo, live)
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        let (_, live) = try siblings(input, in: context)
        return OrderRows.state(live.map { ($0.id, $0.persistentModelID, $0.title) })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        let (_, live) = try siblings(input, in: context)
        let index = try TaskCommandSpecs.position(input, count: live.count)
        return OrderRows.state(OrderRows.moved(live.map { ($0.id, $0.persistentModelID, $0.title) },
                                               moving: input.targets.objects[0].id, to: index))
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let (todo, live) = try siblings(input, in: context)
        let index = try TaskCommandSpecs.position(input, count: live.count)
        let ordered = OrderRows.moved(live.map { ($0.id, $0.persistentModelID, $0.title) }, moving: input.targets.objects[0].id, to: index)
        try dependencies.tasks(context).reorderSubtasks(for: todo.id, orderedIDs: ordered.map(\.0))
    }
}

/// routine.order → reorderRoutines(orderedIDs:)：全部活习惯（含已暂停，与重复事项面板同序）中移到指定位置。
@MainActor struct RoutineOrderSpec: SimpleCommandSpec {
    let dependencies: TaskCommandDependencies
    let command = CommandID(rawValue: "routine.order")
    let shape = CommandSimpleShape.single(.routine)
    let copy = CommandSimpleCopy(preview: "unified.simple.order.preview", saved: "unified.simple.order.saved")

    private func live(_ input: CommandResolvedInput, in context: ModelContext) throws -> [DailyRoutine] {
        let target = input.targets.objects[0]
        _ = try TaskCommandSpecs.routine(target.id, in: context)
        try TaskCommandSpecs.qualify(target, dependencies)
        return try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.deletedAt == nil }))
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        OrderRows.state(try live(input, in: context).map { ($0.id, $0.persistentModelID, $0.title) })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        let rows = try live(input, in: context).map { ($0.id, $0.persistentModelID, $0.title) }
        let index = try TaskCommandSpecs.position(input, count: rows.count)
        return OrderRows.state(OrderRows.moved(rows, moving: input.targets.objects[0].id, to: index))
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let rows = try live(input, in: context).map { ($0.id, $0.persistentModelID, $0.title) }
        let index = try TaskCommandSpecs.position(input, count: rows.count)
        let ordered = OrderRows.moved(rows, moving: input.targets.objects[0].id, to: index)
        try dependencies.routines(context).reorderRoutines(orderedIDs: ordered.map(\.0))
    }
}

/// tasks.order → ManualOrderService.apply：某天未完成的待办与到期习惯混排，规则沿 ManualOrder 与看板排序键。
/// 带子任务的事项在看板上总排在前面，跨越这一分组的位置写入后也显示不出来，因此拒绝。
@MainActor struct DayOrderSpec: SimpleCommandSpec {
    let dependencies: TaskCommandDependencies
    let command = CommandID(rawValue: "tasks.order")
    let shape = CommandSimpleShape.singleAny([.todo, .routine])
    let copy = CommandSimpleCopy(preview: "unified.simple.order.preview", saved: "unified.simple.order.saved")

    private func list(_ input: CommandResolvedInput, in context: ModelContext) throws -> (String, [ManualOrderRow]) {
        let target = input.targets.objects[0]
        guard let argument = input.arguments.first(where: { $0.parameter == .day }),
              case .day(let day)? = argument.value else { throw CommandSimpleIssue.invalidArguments }
        if target.type == .todo { _ = try TaskCommandSpecs.todo(target.id, in: context) }
        else { _ = try TaskCommandSpecs.routine(target.id, in: context) }
        try TaskCommandSpecs.qualify(target, dependencies)
        let rows = try ManualOrderService.openEntries(dayKey: day, in: context, calendar: dependencies.calendar)
        guard rows.contains(where: { $0.id == target.id && ($0.kind == .todo) == (target.type == .todo) }) else {
            throw CommandSimpleIssue.invalidTarget(.notListed)
        }
        return (day, rows)
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        OrderRows.state(try list(input, in: context).1.map { ($0.id, nil, $0.title) })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        let (day, rows) = try list(input, in: context)
        return OrderRows.state(try moved(rows, day: day, input: input).map { row in (row.id, nil, title(row.id, rows)) })
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let (day, rows) = try list(input, in: context)
        try ManualOrderService.apply(try moved(rows, day: day, input: input), in: context)
    }

    private func moved(_ rows: [ManualOrderRow], day: String, input: CommandResolvedInput) throws -> [ManualOrderEntry] {
        let index = try TaskCommandSpecs.position(input, count: rows.count)
        let entries = rows.map { ManualOrderEntry(id: $0.id, dayKey: day, sortOrder: $0.key.sortOrder) }
        guard let next = ManualOrder.reordered(entries, moving: input.targets.objects[0].id, to: index) else {
            throw CommandSimpleIssue.invalidTarget(.outOfRange)
        }
        let grouped = next.map { entry in rows.first { $0.id == entry.id }?.key.hasSubtasks ?? false }
        guard grouped == grouped.sorted(by: { $0 && !$1 }) else { throw CommandSimpleIssue.invalidTarget(.crossesGroup) }
        return next
    }

    private func title(_ id: UUID, _ rows: [ManualOrderRow]) -> String { rows.first { $0.id == id }?.title ?? "" }
}

@MainActor enum OrderRows {
    typealias Item = (UUID, PersistentIdentifier?, String)

    static func state(_ items: [Item]) -> CommandSimpleState {
        .init(rows: items.enumerated().map { index, item in
            .init(key: item.0.uuidString, record: item.1, title: item.2, fields: [TaskCommandSpecs.positionField(index)])
        })
    }

    static func moved(_ items: [Item], moving: UUID, to index: Int) -> [Item] {
        guard let from = items.firstIndex(where: { $0.0 == moving }) else { return items }
        var next = items
        let item = next.remove(at: from)
        next.insert(item, at: index)
        return next
    }
}
