import Foundation
import Testing
@testable import AreaChain

struct DayKeyTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func formatsYearMonthDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 7
        let date = utc.date(from: components)!
        #expect(DayKey.from(date, calendar: utc) == "2026-09-07")
    }

    @Test func yesterdayGoesBackOneDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 7
        let date = utc.date(from: components)!
        #expect(DayKey.yesterday(from: date, calendar: utc) == "2026-09-06")
    }

    @Test func displayNameUsesChineseDate() {
        let locale = Locale(identifier: "zh_CN")
        #expect(DayKey.displayName("2026-09-07", locale: locale).contains("9月7日"))
    }

    @Test func displayNameUsesEnglishDate() {
        let locale = Locale(identifier: "en_US")
        let name = DayKey.displayName("2026-09-07", locale: locale)
        #expect(name.contains("Sep"))
        #expect(name.contains("7"))
    }

    @Test func shiftedMovesByDays() {
        #expect(DayKey.shifted("2026-09-07", by: -2, calendar: utc) == "2026-09-05")
        #expect(DayKey.shifted("2026-09-07", by: 1, calendar: utc) == "2026-09-08")
        #expect(DayKey.tomorrow(from: utc.date(from: DateComponents(year: 2026, month: 9, day: 7))!, calendar: utc) == "2026-09-08")
    }

    @Test func weekdaySkipsSaturdayAndSunday() {
        #expect(!DayKey.isWeekday("2026-09-05", calendar: utc))
        #expect(!DayKey.isWeekday("2026-09-06", calendar: utc))
        #expect(DayKey.isWeekday("2026-09-07", calendar: utc))
        #expect(DayKey.isWeekday("2026-09-11", calendar: utc))
    }

    @Test func dateFromDayKeyAndMinutes() {
        let morning = DayKey.date(dayKey: "2026-09-07", minutes: 9 * 60, calendar: utc)!
        #expect(utc.component(.hour, from: morning) == 9)
        #expect(utc.component(.minute, from: morning) == 0)
        #expect(DayKey.date(dayKey: "2026-09-07", minutes: 1440, calendar: utc) == nil)
        #expect(DayKey.date(dayKey: "bad", minutes: 0, calendar: utc) == nil)
    }

    @Test func monthGridPadsFromFirstWeekday() {
        var mondayFirst = utc
        mondayFirst.firstWeekday = 2
        let days = DayKey.daysInMonth(containing: "2026-09-07", calendar: mondayFirst)
        #expect(days.first == "2026-09-01")
        #expect(days.last == "2026-09-30")
        let grid = DayKey.monthGrid(containing: "2026-09-07", calendar: mondayFirst)
        #expect(grid.count % 7 == 0)
        #expect(grid[0] == nil)
        #expect(grid[1] == "2026-09-01")
        #expect(DayKey.shiftedMonth("2026-09-07", by: 1, calendar: mondayFirst) == "2026-10-07")
        #expect(DayKey.dayNumber("2026-09-07", calendar: mondayFirst) == "7")
    }
}
