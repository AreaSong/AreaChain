import Foundation
import Testing
@testable import AreaChain

struct ManualOrderConversionTests {
    @Test func reorderStaysInsideOneDay() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let entries = [
            ManualOrderEntry(id: a, dayKey: "2026-09-07", sortOrder: 0),
            ManualOrderEntry(id: b, dayKey: "2026-09-07", sortOrder: 1),
            ManualOrderEntry(id: c, dayKey: "2026-09-08", sortOrder: 0),
        ]
        let next = ManualOrder.reordered(entries, moving: b, before: a)
        #expect(next?.map(\.id) == [b, a, c])
        #expect(next?.first { $0.id == b }?.sortOrder == 0)
        #expect(next?.first { $0.id == a }?.sortOrder == 1)
        #expect(ManualOrder.reordered(entries, moving: b, before: c) == nil)
    }

    @Test func foldedNotesAppendsSubtasks() {
        #expect(ItemConversion.foldedNotes(existing: "备注", subtaskTitles: [" 一步 ", ""]) == "备注\n一步")
        #expect(ItemConversion.foldedNotes(existing: "", subtaskTitles: ["一步"]) == "一步")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(ItemConversion.weekdayMask(for: "2026-09-07", calendar: calendar) == WeekdayMask.only(weekday: 2))
    }

    @Test func habitMonthMarksCheckedSkippedMissedAndOpen() {
        let id = UUID()
        let routine = RoutineSnapshot(
            id: id, title: "晨间", sortOrder: 0, isEnabled: true, createdDayKey: "2026-09-01"
        )
        let checks = [
            CheckSnapshot(routineId: id, dayKey: "2026-09-07", isDone: true),
            CheckSnapshot(routineId: id, dayKey: "2026-09-08", isDone: true, isSkipped: true),
        ]
        #expect(HabitMonth.mark(dayKey: nil, routine: routine, checks: [], todayKey: "2026-09-09") == .padding)
        #expect(HabitMonth.mark(dayKey: "2026-09-07", routine: routine, checks: checks, todayKey: "2026-09-09") == .checked)
        #expect(HabitMonth.mark(dayKey: "2026-09-08", routine: routine, checks: checks, todayKey: "2026-09-09") == .skipped)
        #expect(HabitMonth.mark(dayKey: "2026-09-06", routine: routine, checks: checks, todayKey: "2026-09-09") == .missed)
        #expect(HabitMonth.mark(dayKey: "2026-09-09", routine: routine, checks: checks, todayKey: "2026-09-09") == .open)
    }
}
