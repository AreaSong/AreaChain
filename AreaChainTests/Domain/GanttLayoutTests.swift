import Foundation
import Testing
@testable import AreaChain

struct GanttLayoutTests {
    @Test func barsStayOnDayKeyAndRoutinesDotWeekdays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        let month = DayKey.daysInMonth(containing: "2026-09-07", calendar: calendar)
        let open = TodoSnapshot(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            title: "修导出",
            isDone: false,
            dayKey: "2026-09-07"
        )
        let done = TodoSnapshot(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            title: "已做",
            isDone: true,
            dayKey: "2026-09-07"
        )
        let otherMonth = TodoSnapshot(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            title: "八月",
            isDone: false,
            dayKey: "2026-08-31"
        )
        let bars = GanttLayout.todoBars(todos: [open, done, otherMonth], monthKeys: Set(month))
        #expect(bars.map(\.dayKey) == ["2026-09-07"])
        #expect(bars.map(\.title) == ["修导出"])

        let routine = RoutineSnapshot(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "写日报",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.workdays
        )
        let marks = GanttLayout.routineMarks(routines: [routine], monthKeys: month, calendar: calendar)
        #expect(marks.contains { $0.dayKey == "2026-09-01" })
        #expect(marks.contains { $0.dayKey == "2026-09-07" })
        #expect(!marks.contains { $0.dayKey == "2026-09-05" })
        #expect(!marks.contains { $0.dayKey == "2026-09-06" })
    }
}
