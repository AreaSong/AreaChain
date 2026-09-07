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
}
