import Foundation
import SwiftData

/// 安排页改期的唯一写入入口（合并批 M-2 A 从 GanttRescheduling 抽出）：拖动提交与 gantt.shift 共用。
/// 事务边界由调用方给出；本入口只做资格核对、按页面同一规则推出整组移动，以及逐项调原仓储 moveTodo。
@MainActor enum GanttRescheduleService {
    /// 拖动期间发生改期、完成或删除时，不用旧快照覆盖较新的任务状态。
    static func eligible(_ moves: [GanttTodoMove], todos: [TodoItem], context: ModelContext) -> Bool {
        moves.allSatisfy { move in
            todos.contains {
                $0.id == move.id && $0.dayKey == move.originalDay && !$0.isDone && $0.deletedAt == nil
                    && $0.modelContext === context
            }
        }
    }

    static func apply(_ moves: [GanttTodoMove], repository: any TaskRepositoryProtocol) throws {
        for move in moves {
            try repository.moveTodo(id: move.id, to: move.destinationDay)
        }
    }

    /// 与拖动同一索引平移（GanttDragState）：整组按同一天数移动、保留间隔；页面把越界钳到月边，
    /// 指令不替用户截断，越出当月返回 nil。偏移为 0 时没有移动。
    static func shift(_ bars: [GanttTodoBar], by offset: Int, monthDays days: [String]) -> [GanttTodoMove]? {
        guard let first = bars.first, bars.allSatisfy({ days.contains($0.dayKey) }),
              var drag = GanttDragState(sourceID: first.id, selectedIDs: Set(bars.map(\.id)), bars: bars, days: days),
              drag.bars.count == bars.count else { return nil }
        drag.update(dayOffset: offset)
        guard drag.dayOffset == offset else { return nil }
        return drag.moves
    }
}
