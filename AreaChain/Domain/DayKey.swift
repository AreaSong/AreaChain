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

    static func displayName(_ key: String, calendar: Calendar = .current) -> String {
        guard let date = date(from: key, calendar: calendar) else { return key }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"
        return formatter.string(from: date)
    }

    static func shortStamp(_ key: String, calendar: Calendar = .current) -> String {
        guard let date = date(from: key, calendar: calendar) else { return key }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
