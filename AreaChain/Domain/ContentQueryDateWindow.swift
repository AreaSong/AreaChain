import Foundation

/// 有界日期集合：区间内含端点，组内并集、组间交集；空集合与没有 date 条件不同。
struct ContentQueryDateWindow: Equatable {
    let intervals: [ContentQueryDateInterval]

    init?(intervals: [ContentQueryDateInterval], calendar: Calendar) {
        guard intervals.allSatisfy({ Self.valid($0, calendar: calendar) }) else { return nil }
        var merged: [ContentQueryDateInterval] = []
        for interval in intervals.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, Self.touches(last, interval, calendar: calendar) {
                merged[merged.count - 1] = .init(lowerBound: last.lowerBound, upperBound: max(last.upperBound, interval.upperBound))
            } else { merged.append(interval) }
        }
        self.intervals = merged
    }

    func contains(_ day: String) -> Bool {
        intervals.contains { ContentQuerySnapshotMatching.contains($0, day: day) }
    }

    func covers(_ interval: ContentQueryDateInterval, calendar: Calendar) -> Bool {
        Self.valid(interval, calendar: calendar) && intervals.contains {
            $0.lowerBound <= interval.lowerBound && $0.upperBound >= interval.upperBound
        }
    }

    enum Resolution: Equatable {
        case unconstrained
        case window(ContentQueryDateWindow)
        case invalid(ContentQueryIssue)
    }

    /// 只提取 date 条件；页面日期、created 与 on 保留各自语义，由调用方分别求值。
    static func resolve(_ conditions: [ContentQueryCondition], dates: ContentQueryDateContext) -> Resolution {
        var result: Self?
        for condition in conditions {
            guard case .clause(let terms) = condition.value, terms.contains(where: { $0.atom.dimension == .date }) else { continue }
            if let issue = ContentQueryConditionValidation.invalid(condition.value, dates: dates) { return .invalid(issue) }
            let intervals = terms.compactMap { term -> ContentQueryDateInterval? in
                if case .date(let interval) = term.atom { return interval }
                return nil
            }
            guard let next = Self(intervals: intervals, calendar: dates.calendar) else { return .invalid(.invalidDate) }
            if let previous = result {
                let intersections = previous.intervals.flatMap { left in next.intervals.compactMap { left.intersection($0) } }
                result = Self(intervals: intersections, calendar: dates.calendar)
            } else { result = next }
        }
        return result.map(Resolution.window) ?? .unconstrained
    }

    static func valid(_ interval: ContentQueryDateInterval, calendar: Calendar) -> Bool {
        let dates = ContentQueryDateContext(todayKey: interval.lowerBound, calendar: calendar)
        return interval.lowerBound <= interval.upperBound
            && ContentQuerySnapshotValidation.validDay(interval.lowerBound, dates: dates)
            && ContentQuerySnapshotValidation.validDay(interval.upperBound, dates: dates)
    }

    private static func touches(
        _ left: ContentQueryDateInterval, _ right: ContentQueryDateInterval, calendar: Calendar
    ) -> Bool {
        if right.lowerBound <= left.upperBound { return true }
        guard left.upperBound < "9999-12-31" else { return false }
        return DayKey.shifted(left.upperBound, by: 1, calendar: calendar) == right.lowerBound
    }
}
