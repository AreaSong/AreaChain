import Foundation

struct ContentQueryDateContext {
    let todayKey: String
    let calendar: Calendar
}

/// 闭区间只持有规范民事日期键；不存零点时间戳，也不枚举区间内日期。
struct ContentQueryDateInterval: Equatable {
    let lowerBound: String
    let upperBound: String

    func intersection(_ other: Self) -> Self? {
        let lower = max(lowerBound, other.lowerBound)
        let upper = min(upperBound, other.upperBound)
        return lower <= upper ? Self(lowerBound: lower, upperBound: upper) : nil
    }
}

enum ContentQueryDates {
    static func parse(_ text: String, context: ContentQueryDateContext) -> Result<ContentQueryDateInterval, Failure> {
        let parts = text.components(separatedBy: "..")
        guard parts.count <= 2 else { return .failure(.invalidDate) }
        guard !parts.contains("") else { return .failure(.incompleteCondition) }
        let keys = parts.map { $0 == "today" || $0 == "今天" ? context.todayKey : $0 }
        if parts.contains("today") || parts.contains("今天") {
            guard valid(context.todayKey, calendar: context.calendar) else { return .failure(.invalidDateContext) }
        }
        if parts.contains(where: { partialDay($0) }) { return .failure(.incompleteCondition) }
        guard keys.allSatisfy({ valid($0, calendar: context.calendar) }) else { return .failure(.invalidDate) }
        let lower = keys[0]
        let upper = keys.last ?? lower
        guard lower <= upper else { return .failure(.reversedDateInterval) }
        return .success(.init(lowerBound: lower, upperBound: upper))
    }

    enum Failure: String, Error {
        case invalidDate, reversedDateInterval, incompleteCondition, invalidDateContext
        var issue: ContentQueryIssue {
            switch self {
            case .invalidDate: .invalidDate
            case .reversedDateInterval: .reversedDateInterval
            case .incompleteCondition: .incompleteCondition
            case .invalidDateContext: .invalidDateContext
            }
        }
    }

    private static func partialDay(_ text: String) -> Bool {
        guard !text.isEmpty, text.count < 10, text != "today", text != "今天" else { return false }
        if "today".hasPrefix(text) || "今天".hasPrefix(text) { return true }
        let template = Array("0000-00-00")
        return text.enumerated().allSatisfy { offset, char in
            template[offset] == "-" ? char == "-" : char.isASCII && char.isNumber
        }
    }

    private static func valid(_ key: String, calendar: Calendar) -> Bool {
        // 复用严格公历日校验，再确认调用方日历可往返；拒绝隐式日历归一化。
        guard CommandArgumentValidation.isCanonicalDay(key), calendar.identifier == .gregorian,
              let date = DayKey.date(from: key, calendar: calendar) else { return false }
        return DayKey.from(date, calendar: calendar) == key
    }
}
