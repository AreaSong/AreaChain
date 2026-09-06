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
        #expect(DayKey.displayName("2026-09-07").contains("9月7日"))
    }
}
