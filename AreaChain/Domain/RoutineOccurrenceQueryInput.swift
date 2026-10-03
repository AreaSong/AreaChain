import Foundation

/// 单个习惯的输入切片；局部归并下标映射回请求，不重新实现记录状态或历史判断。
struct RoutineOccurrenceQueryInput: CustomStringConvertible, CustomDebugStringConvertible {
    let routine: RoutineSnapshot
    let history: RoutineScheduleHistory
    let coverage: RoutineCheckCoverage
    let checks: [CheckSnapshot]
    let checkIndices: [Int]
    let evidenceIndices: [Int]

    var description: String { "RoutineOccurrenceQueryInput(redacted)" }
    var debugDescription: String { description }

    init(_ request: RoutineOccurrenceQueryRequest, routine: RoutineSnapshot) {
        self.routine = routine
        checkIndices = request.checks.indices.filter { request.checks[$0].routineId == routine.id }
        checks = checkIndices.map { request.checks[$0] }
        evidenceIndices = request.scheduleEvidence.indices.filter { request.scheduleEvidence[$0].routineID == routine.id }
        history = .init(routine: routine, evidence: evidenceIndices.map { request.scheduleEvidence[$0] }, dates: request.session.queryDates)
        coverage = .init(routineID: routine.id, completeIntervals: request.checkCoverage.filter {
            $0.routineID == routine.id
        }.flatMap(\.completeIntervals))
    }

    var object: CommandObjectReference { .init(type: .routine, id: routine.id) }
    var readCost: Int { 8 + checks.count + coverage.completeIntervals.count + history.evidence.count * 2 }
    var coverageWindow: ContentQueryDateWindow? {
        .init(intervals: coverage.completeIntervals, calendar: history.dates.calendar)
    }
    var hasValidRecords: Bool {
        coverageWindow != nil && checks.allSatisfy { ContentQuerySnapshotValidation.validDay($0.dayKey, dates: history.dates) }
    }

    func read(_ day: String) -> RoutineOccurrenceEvaluation {
        let records = RoutineCheckReading.read(routineID: routine.id, on: day, checks: checks,
                                               coverage: coverage, dates: history.dates)
        let schedule = history.day(day)
        return .init(schedule: .init(object: schedule.object, state: schedule.state, reason: schedule.reason,
                                    evidenceIndices: schedule.evidenceIndices.map { evidenceIndices[$0] }),
                     records: .init(object: records.object, state: records.state, observedState: records.observedState,
                                    isComplete: records.isComplete, inputIndices: records.inputIndices.map { checkIndices[$0] },
                                    diagnostics: records.diagnostics))
    }

    /// 只细分记录完整性边界；排程边界仍由 History.segments 提供，避免在不完整多年区间逐日扫描。
    func splitCoverage(_ interval: ContentQueryDateInterval) -> [ContentQueryDateInterval] {
        var starts: Set<String> = [interval.lowerBound]
        for covered in coverageWindow?.intervals ?? [] {
            guard let overlap = interval.intersection(covered) else { continue }
            starts.insert(overlap.lowerBound)
            if overlap.upperBound < interval.upperBound {
                starts.insert(DayKey.shifted(overlap.upperBound, by: 1, calendar: history.dates.calendar))
            }
        }
        let sorted = starts.sorted()
        return sorted.enumerated().map { index, start in
            let end = index + 1 < sorted.count
                ? DayKey.shifted(sorted[index + 1], by: -1, calendar: history.dates.calendar) : interval.upperBound
            return .init(lowerBound: start, upperBound: end)
        }
    }
}

struct RoutineOccurrenceQueryPattern {
    var scheduledMask = 0
    var unknown: [(RoutineScheduleReason, Int)] = []

    static func read(_ interval: ContentQueryDateInterval, history: RoutineScheduleHistory) -> Self {
        var result = Self()
        for offset in 0..<7 {
            let day = DayKey.shifted(interval.lowerBound, by: offset, calendar: history.dates.calendar)
            guard day >= interval.lowerBound && day <= interval.upperBound,
                  let date = DayKey.date(from: day, calendar: history.dates.calendar) else { break }
            let mask = WeekdayMask.only(weekday: history.dates.calendar.component(.weekday, from: date))
            let reading = history.day(day)
            if reading.state == .scheduled { result.scheduledMask |= mask }
            if reading.state == .unknown || reading.state == .invalidInput {
                if let index = result.unknown.firstIndex(where: { $0.0 == reading.reason }) { result.unknown[index].1 |= mask }
                else { result.unknown.append((reading.reason, mask)) }
            }
        }
        return result
    }

    func nextScheduled(from start: String?, through end: String, calendar: Calendar) -> String? {
        guard let start, scheduledMask != 0 else { return nil }
        for offset in 0..<7 {
            let day = DayKey.shifted(start, by: offset, calendar: calendar)
            guard day >= start && day <= end else { return nil }
            if WeekdayMask.contains(scheduledMask, dayKey: day, calendar: calendar) { return day }
        }
        return nil
    }
}
