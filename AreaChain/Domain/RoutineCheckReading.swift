import Foundation

/// 调用方声明这些日期的该习惯记录已完整提供；不是数据库核验结果，不可跨习惯或日期复用。
struct RoutineCheckCoverage: Equatable {
    let routineID: UUID
    let completeIntervals: [ContentQueryDateInterval]

    func covers(_ interval: ContentQueryDateInterval, calendar: Calendar) -> Bool {
        ContentQueryDateWindow(intervals: completeIntervals, calendar: calendar)?.covers(interval, calendar: calendar) == true
    }
}

enum RoutineCheckState: Equatable { case completed, skipped, unprocessed }
enum RoutineCheckReadState: Equatable { case completed, skipped, unprocessed, absent, incomplete, conflict, invalidInput }

struct RoutineCheckRead: Equatable {
    let object: CommandObjectReference
    let state: RoutineCheckReadState
    /// 仅描述已提供行；incomplete 时不得把 observedState 当作最终状态。
    let observedState: RoutineCheckState?
    let isComplete: Bool
    let inputIndices: [Int]
    let diagnostics: [RoutineCheckIssue]
}

enum RoutineCheckIssue: Equatable {
    case invalidDay, invalidRecordDay, invalidCoverage, coverageRoutineMismatch
    case incompleteInput, identicalDuplicates, conflictingRecords, doneAndSkipped
}

/// 新搜索专用只读归并，不替换 DayBoardCheckIndex 的 first-wins 或 Agenda 的任一闭合。
enum RoutineCheckReading {
    static func read(
        routineID: UUID, on day: String, checks: [CheckSnapshot], coverage: RoutineCheckCoverage,
        dates: ContentQueryDateContext
    ) -> RoutineCheckRead {
        let object = CommandObjectReference(type: .routineOccurrence, id: routineID, dayKey: day)
        if let issue = invalid(routineID: routineID, day: day, coverage: coverage, dates: dates) {
            return .init(object: object, state: .invalidInput, observedState: nil, isComplete: false,
                         inputIndices: [], diagnostics: [issue])
        }
        // 非规范日键无法可靠分配给请求日；拒绝该习惯的输入，不归一化或误报完整无记录。
        let invalidIndices = checks.indices.filter {
            checks[$0].routineId == routineID && !ContentQuerySnapshotValidation.validDay(checks[$0].dayKey, dates: dates)
        }
        if !invalidIndices.isEmpty {
            return .init(object: object, state: .invalidInput, observedState: nil, isComplete: false,
                         inputIndices: invalidIndices, diagnostics: [.invalidRecordDay])
        }
        let indices = checks.indices.filter { checks[$0].routineId == routineID && checks[$0].dayKey == day }
        let complete = coverage.covers(.init(lowerBound: day, upperBound: day), calendar: dates.calendar)
        let rows = indices.map { checks[$0] }
        var diagnostics: [RoutineCheckIssue] = complete ? [] : [.incompleteInput]
        let first = rows.first
        let same = rows.allSatisfy { $0.isDone == first?.isDone && $0.isSkipped == first?.isSkipped }
        if rows.count > 1 && same { diagnostics.append(.identicalDuplicates) }
        if !same { diagnostics.append(.conflictingRecords) }
        let invalidPair = rows.contains { $0.isDone && $0.isSkipped }
        if invalidPair { diagnostics.append(.doneAndSkipped) }
        let observed = same && !invalidPair ? first.map(state) : nil
        let resolved: RoutineCheckReadState
        if !same || invalidPair { resolved = .conflict }
        else if !complete { resolved = .incomplete }
        else {
            switch observed {
            case .completed: resolved = .completed
            case .skipped: resolved = .skipped
            case .unprocessed: resolved = .unprocessed
            case nil: resolved = .absent
            }
        }
        return .init(object: object, state: resolved, observedState: observed, isComplete: complete,
                     inputIndices: indices, diagnostics: diagnostics)
    }

    private static func state(_ check: CheckSnapshot) -> RoutineCheckState {
        if check.isDone { return .completed }
        return check.isSkipped ? .skipped : .unprocessed
    }

    private static func invalid(
        routineID: UUID, day: String, coverage: RoutineCheckCoverage, dates: ContentQueryDateContext
    ) -> RoutineCheckIssue? {
        guard ContentQuerySnapshotValidation.validDay(day, dates: dates) else { return .invalidDay }
        guard coverage.routineID == routineID else { return .coverageRoutineMismatch }
        guard ContentQueryDateWindow(intervals: coverage.completeIntervals, calendar: dates.calendar) != nil else {
            return .invalidCoverage
        }
        return nil
    }
}
