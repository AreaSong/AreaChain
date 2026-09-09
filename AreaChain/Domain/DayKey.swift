import Foundation

enum DayKey {
    static func from(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func today(_ date: Date = .now, calendar: Calendar = .current) -> String {
        from(date, calendar: calendar)
    }

    static func yesterday(from date: Date = .now, calendar: Calendar = .current) -> String {
        shifted(from(date, calendar: calendar), by: -1, calendar: calendar)
    }

    static func tomorrow(from date: Date = .now, calendar: Calendar = .current) -> String {
        shifted(from(date, calendar: calendar), by: 1, calendar: calendar)
    }

    static func shifted(_ key: String, by days: Int, calendar: Calendar = .current) -> String {
        guard let date = date(from: key, calendar: calendar),
              let next = calendar.date(byAdding: .day, value: days, to: date)
        else {
            return key
        }
        return from(next, calendar: calendar)
    }

    static func keys(from start: String, before end: String, calendar: Calendar = .current) -> [String] {
        var keys: [String] = []
        var cursor = start
        var steps = 0
        while cursor < end, steps < 4000 {
            keys.append(cursor)
            let next = shifted(cursor, by: 1, calendar: calendar)
            guard next > cursor else { break }
            cursor = next
            steps += 1
        }
        return keys
    }

    static func isWeekday(_ key: String, calendar: Calendar = .current) -> Bool {
        guard let date = date(from: key, calendar: calendar) else { return false }
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let pieces = key.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }
        var components = DateComponents()
        components.year = pieces[0]
        components.month = pieces[1]
        components.day = pieces[2]
        return calendar.date(from: components)
    }

    static func date(dayKey: String, minutes: Int, calendar: Calendar = .current) -> Date? {
        guard let day = date(from: dayKey, calendar: calendar), (0..<1440).contains(minutes) else {
            return nil
        }
        return calendar.date(byAdding: .minute, value: minutes, to: day)
    }

    static func displayName(
        _ key: String,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        guard let date = date(from: key, calendar: calendar) else { return key }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = usesChineseDate(locale) ? "M月d日 EEE" : "MMM d EEE"
        return formatter.string(from: date)
    }

    static func shortStamp(
        _ key: String,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        guard let date = date(from: key, calendar: calendar) else { return key }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    static func dayNumber(_ key: String, calendar: Calendar = .current) -> String {
        guard let date = date(from: key, calendar: calendar) else { return key }
        return "\(calendar.component(.day, from: date))"
    }

    static func monthTitle(
        _ key: String,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        guard let date = date(from: key, calendar: calendar) else { return key }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = usesChineseDate(locale) ? "yyyy年M月" : "MMMM yyyy"
        return formatter.string(from: date)
    }

    static func shiftedMonth(_ key: String, by months: Int, calendar: Calendar = .current) -> String {
        guard let date = date(from: key, calendar: calendar),
              let next = calendar.date(byAdding: .month, value: months, to: date)
        else {
            return key
        }
        return from(next, calendar: calendar)
    }

    static func daysInMonth(containing key: String, calendar: Calendar = .current) -> [String] {
        guard let date = date(from: key, calendar: calendar),
              let interval = calendar.dateInterval(of: .month, for: date)
        else {
            return []
        }
        var keys: [String] = []
        var cursor = interval.start
        while cursor < interval.end {
            keys.append(from(cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return keys
    }

    static func monthGrid(containing key: String, calendar: Calendar = .current) -> [String?] {
        let days = daysInMonth(containing: key, calendar: calendar)
        guard let first = days.first, let firstDate = date(from: first, calendar: calendar) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: firstDate)
        let pad = (weekday - calendar.firstWeekday + 7) % 7
        var cells = Array(repeating: String?.none, count: pad)
        cells.append(contentsOf: days.map { Optional($0) })
        while !cells.isEmpty, cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private static func usesChineseDate(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "zh" || locale.identifier.hasPrefix("zh")
    }
}
