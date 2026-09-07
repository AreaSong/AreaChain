import Foundation
import Testing
@testable import AreaChain

struct WeekdayMaskTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func resolvedFallsBackToWeekdaysOnly() {
        #expect(WeekdayMask.resolved(stored: nil, weekdaysOnly: false) == WeekdayMask.all)
        #expect(WeekdayMask.resolved(stored: nil, weekdaysOnly: true) == WeekdayMask.workdays)
        #expect(WeekdayMask.resolved(stored: 8, weekdaysOnly: true) == 8)
        #expect(WeekdayMask.resolved(stored: 0, weekdaysOnly: true) == WeekdayMask.all)
    }

    @Test func workdaysSkipWeekendKeys() {
        #expect(WeekdayMask.contains(WeekdayMask.workdays, dayKey: "2026-09-07", calendar: utc))
        #expect(!WeekdayMask.contains(WeekdayMask.workdays, dayKey: "2026-09-06", calendar: utc))
        #expect(!WeekdayMask.contains(WeekdayMask.workdays, dayKey: "2026-09-05", calendar: utc))
    }

    @Test func togglingKeepsAtLeastOneDay() {
        let wednesday = 1 << (4 - 1)
        #expect(WeekdayMask.toggling(wednesday, weekday: 4) == wednesday)
        #expect(WeekdayMask.contains(WeekdayMask.toggling(WeekdayMask.all, weekday: 1), weekday: 1) == false)
        #expect(WeekdayMask.contains(WeekdayMask.toggling(WeekdayMask.all, weekday: 1), weekday: 2))
    }

    @Test func orderedWeekdaysFollowFirstWeekday() {
        var mondayFirst = utc
        mondayFirst.firstWeekday = 2
        #expect(WeekdayMask.orderedWeekdays(calendar: mondayFirst) == [2, 3, 4, 5, 6, 7, 1])
    }
}
