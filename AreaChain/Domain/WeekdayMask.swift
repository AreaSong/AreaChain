import Foundation

enum WeekdayMask {
    static let all = 0b1111111
    static let workdays = 0b0111110

    static func resolved(stored: Int?, weekdaysOnly: Bool) -> Int {
        if let stored {
            return sanitized(stored)
        }
        return weekdaysOnly ? workdays : all
    }

    static func sanitized(_ mask: Int) -> Int {
        let clipped = mask & all
        return clipped == 0 ? all : clipped
    }

    static func isAll(_ mask: Int) -> Bool {
        sanitized(mask) == all
    }

    static func isWorkdays(_ mask: Int) -> Bool {
        sanitized(mask) == workdays
    }

    static func contains(_ mask: Int, weekday: Int) -> Bool {
        (sanitized(mask) & bit(weekday: weekday)) != 0
    }

    static func contains(_ mask: Int, dayKey: String, calendar: Calendar = .current) -> Bool {
        guard let date = DayKey.date(from: dayKey, calendar: calendar) else { return false }
        return contains(mask, weekday: calendar.component(.weekday, from: date))
    }

    static func toggling(_ mask: Int, weekday: Int) -> Int {
        let current = sanitized(mask)
        let next = current ^ bit(weekday: weekday)
        return (next & all) == 0 ? current : next
    }

    static func orderedWeekdays(calendar: Calendar = .current) -> [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    static func veryShortSymbol(_ weekday: Int, locale: Locale, calendar: Calendar = .current) -> String {
        symbol(weekday, in: weekdaySymbols(calendar, locale: locale).veryShort)
    }

    static func accessibilityName(_ weekday: Int, locale: Locale, calendar: Calendar = .current) -> String {
        symbol(weekday, in: weekdaySymbols(calendar, locale: locale).standalone)
    }

    static func selectedLabels(_ mask: Int, locale: Locale, calendar: Calendar = .current) -> String {
        let symbols = weekdaySymbols(calendar, locale: locale).short
        let names = orderedWeekdays(calendar: calendar).compactMap { weekday -> String? in
            guard contains(mask, weekday: weekday) else { return nil }
            return symbol(weekday, in: symbols)
        }
        let separator = locale.identifier.hasPrefix("zh") ? "、" : ", "
        return names.joined(separator: separator)
    }

    private static func bit(weekday: Int) -> Int {
        guard (1...7).contains(weekday) else { return 0 }
        return 1 << (weekday - 1)
    }

    private static func symbol(_ weekday: Int, in symbols: [String]) -> String {
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "\(weekday)" }
        return symbols[index]
    }

    private static func weekdaySymbols(_ calendar: Calendar, locale: Locale) -> (
        veryShort: [String],
        short: [String],
        standalone: [String]
    ) {
        var cal = calendar
        cal.locale = locale
        return (
            cal.veryShortStandaloneWeekdaySymbols,
            cal.shortStandaloneWeekdaySymbols,
            cal.standaloneWeekdaySymbols
        )
    }
}
