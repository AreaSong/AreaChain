import Foundation

/// 辅助资料只能随同次请求注入；coverage 的身份/日期语义沿既有记录接口。
struct TrashQueryRoutineInput: CustomStringConvertible, CustomDebugStringConvertible {
    var schedules: [RoutineScheduleEvidence] = []
    var checks: [CheckSnapshot] = []
    var checkCoverage: [RoutineCheckCoverage] = []
    var description: String { "TrashQueryRoutineInput(redacted)" }
    var debugDescription: String { description }
}

enum TrashQueryTemporal {
    typealias Result = TrashQueryEvaluation

    static func evaluate(_ atom: ContentQueryAtom, object: TrashTombstone, session: ContentQuerySession,
                         input: TrashQueryRoutineInput?, id: ContentQueryConditionID) -> Result {
        guard let input else { return .unknown(.routineEvidenceUnavailable, id: id) }
        let routineID: UUID
        let created: String
        if case .routine(let routine) = object.fields {
            routineID = routine.id; created = routine.createdDayKey
        } else if let parent = object.parentAttributes, case .routine(let fields) = parent.attributes {
            routineID = parent.owner.id; created = fields.createdDay
        } else { return .unknown(.missingParentAttributes, id: id) }
        let history = RoutineScheduleHistory(routineID: routineID, createdDayKey: created,
                                            evidence: input.schedules, dates: session.queryDates)
        if case .date(let interval) = atom { return date(interval, history: history, session: session, id: id) }
        guard let day = session.occurrenceDay.dayKey else { return .unknown(.routineEvidenceUnavailable, id: id) }
        let schedule = history.day(day)
        let coverage = RoutineCheckCoverage(routineID: routineID, completeIntervals: input.checkCoverage.filter {
            $0.routineID == routineID
        }.flatMap(\.completeIntervals))
        let records = RoutineCheckReading.read(routineID: routineID, on: day, checks: input.checks,
                                               coverage: coverage, dates: session.queryDates)
        var result: Result
        if case .status(let status) = atom {
            result = convert(RoutineOccurrenceEvaluation(schedule: schedule, records: records).matching(status), id: id, field: .completion)
        } else {
            switch schedule.state {
            case .scheduled: result = convert(.matches, id: id, field: .occurrenceDay)
            case .notScheduled: result = convert(.doesNotMatch, id: id, field: .occurrenceDay)
            case .unknown, .invalidInput: result = .unknown(.schedule(schedule.reason), id: id)
            }
        }
        if schedule.state == .unknown || schedule.state == .invalidInput {
            result.diagnostics.append(.init(issue: .schedule(schedule.reason), conditionID: id))
        }
        result.diagnostics += records.diagnostics.map {
            .init(issue: .check($0), conditionID: id,
                  affectsDetermination: atom.dimension == .status && $0 != .identicalDuplicates && result.value.truth == .unknown)
        }
        return result
    }

    private static func date(_ interval: ContentQueryDateInterval, history: RoutineScheduleHistory,
                             session: ContentQuerySession, id: ContentQueryConditionID) -> Result {
        guard case .window(let window) = ContentQueryDateWindow.resolve(session.conditions, dates: session.queryDates) else {
            return .unknown(.invalidField, id: id)
        }
        let existence = history.existence(in: window)
        var result = convert(existence.truth, id: id, field: .scheduleExistence)
        if let day = existence.witnessDay {
            result = convert(ContentQuerySnapshotMatching.contains(interval, day: day) ? .matches : .doesNotMatch,
                             id: id, field: .scheduleExistence)
        }
        result.diagnostics += existence.unknownReasons.map {
            .init(issue: .schedule($0), conditionID: id, affectsDetermination: result.value.truth == .unknown)
        }
        return result
    }

    private static func convert(_ truth: RoutineQueryTruth, id: ContentQueryConditionID, field: ContentQueryMatchField) -> Result {
        switch truth {
        case .matches: .known([.init(conditionID: id, field: field)])
        case .doesNotMatch: .known(nil)
        case .unknown: .unknown(.routineEvidenceUnavailable, id: id)
        case .invalidInput: .unknown(.invalidField, id: id)
        }
    }
}
