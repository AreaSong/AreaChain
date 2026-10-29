import Foundation
import SwiftData

/// 看板的简单修改指令。其余看板修改（新建、优先级、完成、复制、批量完成）转交已有指令执行，
/// 不在这里另写；只有“整组平移”没有现成指令，按安排页拖动的同一规则与写入入口实现。
@MainActor enum BoardCommandSpecs {
    static func all(_ dependencies: TaskCommandDependencies) -> [any SimpleCommandSpec] {
        [GanttShiftSpec(dependencies: dependencies)]
    }
}

/// gantt.shift：所选待办整体平移 N 天、保留彼此间隔，限 `day` 所在的月份（安排页当前月）。
/// 资格与拖动一致（未完成、未删除、在该月里）；越出当月整组拒绝，不像拖动那样钳到月边。
/// 写入只调 GanttRescheduleService.apply（逐项 moveTodo），骨架包一次事务：任一项失败整组回滚。
@MainActor struct GanttShiftSpec: SimpleCommandCallSpec {
    let dependencies: TaskCommandDependencies
    let command = CommandID(rawValue: "gantt.shift")
    let shape = CommandSimpleShape.fixed(.todo)
    let copy = CommandSimpleCopy(preview: "unified.simple.gantt.shift.preview", saved: "unified.simple.gantt.shift.saved")

    private func parameters(_ input: CommandResolvedInput) throws -> (offset: Int, days: [String]) {
        let arguments = Dictionary(TagCommandSpecs.arguments(input).map { ($0.parameter, $0.value) },
                                   uniquingKeysWith: { _, last in last })
        guard case .number(let raw)?? = arguments[.offset], raw.rounded() == raw, abs(raw) <= 31,
              case .day(let day)?? = arguments[.day], CommandArgumentValidation.isCanonicalDay(day) else {
            throw CommandSimpleIssue.invalidArguments
        }
        return (Int(raw), DayKey.daysInMonth(containing: day, calendar: dependencies.calendar))
    }

    /// 目标须是该月安排页上的色块：未完成、未删除、日期在月内；总量沿批量改期的同一上限。
    private func bars(_ input: CommandResolvedInput, days: [String], in context: ModelContext) throws -> [GanttTodoBar] {
        let targets = input.targets.objects
        guard targets.count <= CommandBatchWriteSet.Counts.entityLimit else { throw CommandSimpleIssue.invalidTarget(.tooMany) }
        return try targets.map { target in
            let todo = try TaskCommandSpecs.todo(target.id, in: context)
            try TaskCommandSpecs.qualify(target, dependencies)
            guard !todo.isDone, days.contains(todo.dayKey) else { throw CommandSimpleIssue.invalidTarget(.notListed) }
            return GanttTodoBar(id: todo.id, title: todo.title, dayKey: todo.dayKey)
        }
    }

    private func state(_ bars: [GanttTodoBar], day: (GanttTodoBar) -> String) -> CommandSimpleState {
        .init(rows: bars.map { bar in
            .init(key: bar.id.uuidString, record: nil, title: bar.title,
                  fields: [.init(id: "day", value: day(bar), display: .verbatim(day(bar)))])
        })
    }

    private func moves(_ input: CommandResolvedInput, in context: ModelContext) throws -> ([GanttTodoBar], [GanttTodoMove]) {
        let (offset, days) = try parameters(input)
        let bars = try bars(input, days: days, in: context)
        guard let moves = GanttRescheduleService.shift(bars, by: offset, monthDays: days) else {
            throw CommandSimpleIssue.invalidTarget(.outOfRange)
        }
        return (bars, moves)
    }

    /// 写后核对只读冻结的行：读的是当前日期，不再要求仍在原月份。
    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        guard call.frozen != nil else {
            let (_, days) = try parameters(call.input)
            return state(try bars(call.input, days: days, in: context)) { $0.dayKey }
        }
        let todos = try call.input.targets.objects.map { try TaskCommandSpecs.todo($0.id, in: context) }
        return state(todos.map { GanttTodoBar(id: $0.id, title: $0.title, dayKey: $0.dayKey) }) { $0.dayKey }
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let (bars, moves) = try moves(call.input, in: context)
        let destinations = Dictionary(moves.map { ($0.id, $0.destinationDay) }, uniquingKeysWith: { first, _ in first })
        return state(bars) { destinations[$0.id] ?? $0.dayKey }
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        try GanttRescheduleService.apply(try moves(call.input, in: context).1, repository: dependencies.tasks(context))
    }
}
