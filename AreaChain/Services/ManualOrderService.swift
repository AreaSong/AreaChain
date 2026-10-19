import Foundation
import SwiftData

/// 同一天待办与习惯混排手动顺序的唯一写入：按条目身份把新 sortOrder 写回待办或习惯。
/// 只在调用方事务内写入；原拖动经 DayBoardMutations.applyManualOrder 包一次 ModelChanges。
@MainActor enum ManualOrderService {
    static func apply(_ entries: [ManualOrderEntry], in context: ModelContext) throws {
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let todoMap = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
        let routineMap = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        for entry in entries {
            if let todo = todoMap[entry.id] {
                todo.sortOrder = entry.sortOrder
            } else if let routine = routineMap[entry.id] {
                routine.sortOrder = entry.sortOrder
            }
        }
    }

    /// 某天列表里未完成的待办与到期习惯，按看板显示顺序（带子任务在前，再按 sortOrder、创建时间）。
    /// 分组与比较都沿 DayBoardDayProjection.partition 与 Classification.precedes，不另定规则；不套用页面筛选。
    static func openEntries(dayKey: String, in context: ModelContext,
                            calendar: Calendar = .current) throws -> [ManualOrderRow] {
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let checks = try context.fetch(FetchDescriptor<RoutineCheck>())
        let source = DayBoardSource(routines: routines, checks: checks, todos: todos)
        let lists = DayBoardDayProjection.partition(source: source, dayKey: dayKey, calendar: calendar)
        let rows = lists.openTodos.map { snap in
            ManualOrderRow(kind: .todo, id: snap.id, title: snap.title, key: snap.boardSortKey)
        } + lists.openRoutines.map { snap in
            ManualOrderRow(kind: .routine, id: snap.id, title: snap.title, key: snap.boardSortKey)
        }
        return rows.map { row in
            var row = row
            row.key.dayKey = dayKey
            return row
        }.sorted { Classification.precedes($0.key, $1.key) }
    }
}

/// 一行混排条目：类型、身份、标题与看板排序键。
struct ManualOrderRow: Equatable {
    enum Kind: Equatable { case todo, routine }
    let kind: Kind
    let id: UUID
    let title: String
    var key: BoardSortKey
}
