import Foundation

enum RoutineQueryTruth: Equatable { case matches, doesNotMatch, unknown, invalidInput }

struct RoutineScheduleExistence: Equatable {
    let truth: RoutineQueryTruth
    let witnessDay: String?
    /// 每段至少含一个未知日，不表示该段所有日期均未知；精确单日可继续调用 history.day。
    let intervalsContainingUnknownDays: [ContentQueryDateInterval]
    var unknownReasons: [RoutineScheduleReason] = []
}

extension RoutineScheduleHistory {
    /// 证据边界间规则不变，最多检查七个星期位；不按多年跨度逐日扫描或建立历史数据库。
    func existence(in window: ContentQueryDateWindow) -> RoutineScheduleExistence {
        guard hasValidInput else { return .init(truth: .invalidInput, witnessDay: nil, intervalsContainingUnknownDays: []) }
        var witness: String?
        var unknown: [ContentQueryDateInterval] = []
        var reasons: [RoutineScheduleReason] = []
        for interval in window.intervals {
            for segment in segments(in: interval) {
                var hasUnknown = false
                for offset in 0..<7 {
                    let key = DayKey.shifted(segment.lowerBound, by: offset, calendar: dates.calendar)
                    guard key >= segment.lowerBound && key <= segment.upperBound,
                          ContentQuerySnapshotValidation.validDay(key, dates: dates) else { break }
                    let reading = day(key)
                    switch reading.state {
                    case .scheduled: if witness == nil { witness = key }
                    case .unknown:
                        hasUnknown = true
                        if !reasons.contains(reading.reason) { reasons.append(reading.reason) }
                    case .notScheduled: break
                    case .invalidInput:
                        return .init(truth: .invalidInput, witnessDay: nil, intervalsContainingUnknownDays: [])
                    }
                }
                if hasUnknown { unknown.append(segment) }
            }
        }
        return .init(truth: witness != nil ? .matches : (unknown.isEmpty ? .doesNotMatch : .unknown),
                     witnessDay: witness, intervalsContainingUnknownDays: unknown, unknownReasons: reasons)
    }

    /// 同一分段也供执行记录枚举复用；调用方仍须限制证据输入与枚举工作量。
    func segments(in interval: ContentQueryDateInterval) -> [ContentQueryDateInterval] {
        var starts: Set<String> = [interval.lowerBound]
        if ContentQuerySnapshotMatching.contains(interval, day: createdDayKey) { starts.insert(createdDayKey) }
        for item in evidence where item.routineID == routineID {
            guard let overlap = interval.intersection(item.interval) else { continue }
            starts.insert(overlap.lowerBound)
            if overlap.upperBound < interval.upperBound {
                starts.insert(DayKey.shifted(overlap.upperBound, by: 1, calendar: dates.calendar))
            }
        }
        let ordered = starts.sorted()
        return ordered.enumerated().map { index, start in
            let end = index + 1 < ordered.count
                ? DayKey.shifted(ordered[index + 1], by: -1, calendar: dates.calendar) : interval.upperBound
            return .init(lowerBound: start, upperBound: end)
        }
    }
}

enum RoutineOccurrenceState: Equatable { case open, done, skipped, notScheduled, unknown, conflict, invalidInput }

/// 状态组合只消费同一业务身份的两个读取结果；没有保存、选择动作或完整查询提供者。
struct RoutineOccurrenceEvaluation: Equatable {
    let schedule: RoutineScheduleDay
    let records: RoutineCheckRead

    var state: RoutineOccurrenceState {
        guard schedule.object == records.object, schedule.object.type == .routineOccurrence,
              let day = schedule.object.dayKey, CommandArgumentValidation.isCanonicalDay(day),
              schedule.state != .invalidInput, records.state != .invalidInput else { return .invalidInput }
        if schedule.state == .notScheduled { return .notScheduled }
        if records.state == .conflict { return .conflict }
        guard schedule.state == .scheduled else { return .unknown }
        switch records.state {
        case .completed: return .done
        case .skipped: return .skipped
        case .unprocessed, .absent: return .open
        case .incomplete: return .unknown
        case .conflict: return .conflict
        case .invalidInput: return .invalidInput
        }
    }

    func matching(_ status: ContentQueryStatus) -> RoutineQueryTruth {
        switch state {
        case .open: return status == .open ? .matches : .doesNotMatch
        case .done: return status == .done ? .matches : .doesNotMatch
        case .skipped: return status == .skipped ? .matches : .doesNotMatch
        case .notScheduled: return .doesNotMatch
        case .unknown, .conflict: return .unknown
        case .invalidInput: return .invalidInput
        }
    }
}
