import Foundation

struct GanttTodoMove: Equatable {
    let id: UUID
    let originalDay: String
    let destinationDay: String
}

/// 预览只移动当月可见色块；以日期索引平移，避免夏令时和逐项截断改变任务间隔。
struct GanttDragState: Equatable {
    let sourceID: UUID
    let bars: [GanttTodoBar]
    let days: [String]
    private(set) var dayOffset = 0

    init?(sourceID: UUID, selectedIDs: Set<UUID>, bars: [GanttTodoBar], days: [String]) {
        guard bars.contains(where: { $0.id == sourceID && days.contains($0.dayKey) }) else { return nil }
        let ids = selectedIDs.contains(sourceID) ? selectedIDs : [sourceID]
        self.sourceID = sourceID
        self.bars = bars.filter { ids.contains($0.id) && days.contains($0.dayKey) }
        self.days = days
    }

    mutating func update(dayOffset requested: Int) {
        let indices = bars.compactMap { days.firstIndex(of: $0.dayKey) }
        guard let first = indices.min(), let last = indices.max() else { return }
        dayOffset = min(max(requested, -first), days.count - 1 - last)
    }

    func previewDay(for id: UUID) -> String? {
        guard let bar = bars.first(where: { $0.id == id }), let index = days.firstIndex(of: bar.dayKey) else { return nil }
        return days[index + dayOffset]
    }

    var moves: [GanttTodoMove] {
        guard dayOffset != 0 else { return [] }
        return bars.compactMap { bar in
            previewDay(for: bar.id).map { GanttTodoMove(id: bar.id, originalDay: bar.dayKey, destinationDay: $0) }
        }
    }

    func matches(_ current: [GanttTodoBar]) -> Bool {
        bars.allSatisfy { original in current.contains { $0.id == original.id && $0.dayKey == original.dayKey } }
    }
}
