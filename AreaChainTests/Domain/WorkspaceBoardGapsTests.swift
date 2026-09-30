import Foundation
import Testing
@testable import AreaChain

struct WorkspaceBoardGapsTests {
    @Test func allItemsDaysPutTodayBeforeFutureThenPast() {
        let ordered = AllItemsDayOrder.ordered(
            ["2026-09-28", "2026-09-30", "2026-09-30", "2026-10-02", "2026-09-29"],
            todayKey: "2026-09-30"
        )
        #expect(ordered == ["2026-09-30", "2026-10-02", "2026-09-29", "2026-09-28"])
    }

    @Test func weekKeysCoverSevenDaysIncludingTheSelection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let keys = DayKey.weekKeys(containing: "2026-09-30", calendar: calendar)
        #expect(keys.count == 7)
        #expect(keys.contains("2026-09-30"))
        #expect(keys == ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04"])
    }

    @Test func gridStepMovesByDayOrWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(CalendarGridStep.nextDay.apply(to: "2026-09-30", calendar: calendar) == "2026-10-01")
        #expect(CalendarGridStep.previousWeek.apply(to: "2026-09-30", calendar: calendar) == "2026-09-23")
        #expect(CalendarGridStep.from(keyCode: 124) == .nextDay)
        #expect(CalendarGridStep.from(keyCode: 36) == nil)
    }

    @Test func storedFiltersKeepTagsPriorityReminderAndSource() {
        var filters = BoardFilters()
        let tag = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        filters.tasks = filters.tasks
            .withTag(tag)
            .withBundle("com.example.mail")
            .withPriorityScope(.p2)
            .withReminderScope(.set)
            .withDateScope(.overdue)
        filters.diary = BoardFilter(tagID: tag)
        let data = BoardFilterCodec.encode(filters)
        let restored = data.flatMap(BoardFilterCodec.decode)
        #expect(restored?.tasks.tagID == tag)
        #expect(restored?.tasks.bundleID == "com.example.mail")
        #expect(restored?.tasks.priorityScope == .p2)
        #expect(restored?.tasks.reminderScope == .set)
        #expect(restored?.tasks.dateScope == .all)
        #expect(restored?.diary.tagID == tag)
        #expect(BoardFilterCodec.decode(Data("nope".utf8)) == nil)
    }

    @Test func heatmapPreviewKeepsEightCompletedTitles() {
        let todos = (0..<10).map { index in
            TodoSnapshot(
                id: UUID(),
                title: "待办 \(index)",
                isDone: true,
                dayKey: "2026-09-30",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        let titles = DashboardCompletionTitles.previews(todos: todos, routines: [], marks: [:])
        #expect(titles["2026-09-30"]?.count == 8)
        #expect(titles["2026-09-30"]?.first == "待办 0")
    }
}
