import Foundation
import Testing
@testable import AreaChain

struct GanttDragStateTests {
    private let days = DayKey.daysInMonth(containing: "2026-09-14", calendar: Calendar(identifier: .gregorian))
    private let bars = [10, 14, 16].map {
        GanttTodoBar(id: UUID(), title: "任务 \($0)", dayKey: String(format: "2026-09-%02d", $0))
    }

    @Test func selectedTasksMoveTogetherWithoutChangingTheirSpacing() throws {
        var drag = try #require(GanttDragState(
            sourceID: bars[1].id, selectedIDs: Set(bars.prefix(2).map(\.id)), bars: bars, days: days
        ))
        drag.update(dayOffset: 3)
        #expect(drag.moves.map(\.originalDay) == ["2026-09-10", "2026-09-14"])
        #expect(drag.moves.map(\.destinationDay) == ["2026-09-13", "2026-09-17"])
        #expect(drag.previewDay(for: bars[2].id) == nil)
        #expect(bars.map(\.dayKey) == ["2026-09-10", "2026-09-14", "2026-09-16"])
    }

    @Test func draggingAnUnselectedTaskDoesNotMoveTheOldSelection() throws {
        var drag = try #require(GanttDragState(
            sourceID: bars[2].id, selectedIDs: Set(bars.prefix(2).map(\.id)), bars: bars, days: days
        ))
        drag.update(dayOffset: -2)
        #expect(drag.moves == [GanttTodoMove(id: bars[2].id, originalDay: "2026-09-16", destinationDay: "2026-09-14")])
    }

    @Test func groupStopsAtMonthEdgesWithoutCollapsingDateGaps() throws {
        var drag = try #require(GanttDragState(
            sourceID: bars[1].id, selectedIDs: Set(bars.map(\.id)), bars: bars, days: days
        ))
        drag.update(dayOffset: Int.min)
        #expect(drag.moves.map(\.destinationDay) == ["2026-09-01", "2026-09-05", "2026-09-07"])
        drag.update(dayOffset: Int.max)
        #expect(drag.moves.map(\.destinationDay) == ["2026-09-24", "2026-09-28", "2026-09-30"])
    }

    @Test func returningToStartProducesNoMutation() throws {
        var drag = try #require(GanttDragState(sourceID: bars[0].id, selectedIDs: [], bars: bars, days: days))
        #expect(drag.moves.isEmpty)
        drag.update(dayOffset: 1)
        drag.update(dayOffset: 0)
        #expect(drag.moves.isEmpty)
        #expect(drag.previewDay(for: bars[0].id) == bars[0].dayKey)
    }

    @Test func hiddenSelectionAndMissingSourcesAreExcluded() throws {
        let hidden = GanttTodoBar(id: UUID(), title: "其他月份", dayKey: "2026-10-01")
        let drag = try #require(GanttDragState(
            sourceID: bars[0].id, selectedIDs: [bars[0].id, hidden.id, UUID()], bars: bars + [hidden], days: days
        ))
        #expect(drag.bars == [bars[0]])
        #expect(GanttDragState(sourceID: hidden.id, selectedIDs: [], bars: bars + [hidden], days: days) == nil)
        #expect(GanttDragState(sourceID: UUID(), selectedIDs: [], bars: bars, days: days) == nil)
        #expect(GanttDragState(sourceID: bars[0].id, selectedIDs: [], bars: bars, days: []) == nil)
    }

    @Test func changedOrRemovedParticipantsInvalidateTheOriginalSnapshot() throws {
        let drag = try #require(GanttDragState(
            sourceID: bars[0].id, selectedIDs: Set(bars.prefix(2).map(\.id)), bars: bars, days: days
        ))
        var current = bars
        #expect(drag.matches(current))
        current[0].title = "改名不影响日期"
        #expect(drag.matches(current))
        current[1].dayKey = "2026-09-15"
        #expect(!drag.matches(current))
        #expect(!drag.matches(Array(bars.dropFirst())))
    }
}
