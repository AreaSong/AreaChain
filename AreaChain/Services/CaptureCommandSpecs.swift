import Foundation
import SwiftData

/// tasks.postponeYesterday：今日页“昨天”清单里全部未完成的待办（不含习惯）延至今天。
/// 取法沿 AgendaProjection.overdueTodos（与今日页 DayBoardPageProjection 同一规则；指令没有页面筛选）。
/// 目标在准备时推出、接受后冻结：之后清单增减都要求重新预览；写入沿 B-M1 批量改期的 moveTodo，在一次事务内完成。
/// 总量沿 CommandBatchWriteSet.Counts.entityLimit；day 参数必须是今天。原页面按钮仍逐个保存，未改。
@MainActor struct PostponeYesterdaySpec: SimpleCommandCallSpec {
    let dependencies: TaskCommandDependencies
    let command = CommandID(rawValue: "tasks.postponeYesterday")
    let shape = CommandSimpleShape.none
    let copy = CommandSimpleCopy(preview: "unified.simple.postpone.preview", saved: "unified.simple.postpone.saved")

    private func day(_ input: CommandResolvedInput) throws -> String {
        guard input.arguments.count == 1, let argument = input.arguments.first, argument.parameter == .day,
              case .day(let day)? = argument.value else { throw CommandSimpleIssue.invalidArguments }
        return day
    }

    private func row(_ todo: TodoItem) -> CommandSimpleRow {
        .init(key: todo.id.uuidString, record: todo.persistentModelID, title: todo.title,
              fields: [.init(id: "day", value: todo.dayKey, display: .verbatim(todo.dayKey))])
    }

    /// 未冻结时按页面取法推出目标；冻结后只读冻结的待办（写后与未知核对）。
    private func targets(_ call: CommandSimpleCall, in context: ModelContext) throws -> [TodoItem] {
        if let frozen = call.frozen {
            return try frozen.sorted().map { key in
                guard let id = UUID(uuidString: key) else { throw CommandSimpleIssue.stale }
                return try TaskCommandSpecs.todo(id, in: context)
            }
        }
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let overdue = AgendaProjection.overdueTodos(todos: todos.map(\.snapshot), todayKey: dependencies.today(),
                                                    calendar: dependencies.calendar)
        return try overdue.map { try TaskCommandSpecs.todo($0.id, in: context) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        _ = try day(call.input)
        let todos = try targets(call, in: context)
        for todo in todos { try TaskCommandSpecs.qualify(.init(type: .todo, id: todo.id), dependencies) }
        return .init(rows: todos.map(row))
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let today = dependencies.today()
        guard try day(call.input) == today else { throw CommandSimpleIssue.invalidTarget(.notToday) }
        guard !before.rows.isEmpty else { throw CommandSimpleIssue.invalidTarget(.nothingToMove) }
        guard before.rows.count <= CommandBatchWriteSet.Counts.entityLimit else { throw CommandSimpleIssue.invalidTarget(.tooMany) }
        return .init(rows: before.rows.map { row in
            .init(key: row.key, record: row.record, title: row.title,
                  fields: [.init(id: "day", value: today, display: .verbatim(today))])
        })
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        let today = dependencies.today()
        let repository = dependencies.tasks(context)
        for todo in try targets(call, in: context) { try repository.moveTodo(id: todo.id, to: today) }
    }
}
