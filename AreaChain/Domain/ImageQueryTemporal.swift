import Foundation

/// 只为公开 routine 且本次条件确实需要时读取有界证据；不依赖当前定义推测历史。
struct ImageQueryTemporal {
    typealias Result = ImageQueryEvaluation
    let existence: RoutineScheduleExistence?
    let occurrence: RoutineOccurrenceEvaluation?

    init(request: ImageQueryRequest, owner: ImageOwnerProjection?) {
        guard let owner, case .routine(let attributes) = owner.attributes else {
            existence = nil
            occurrence = nil
            return
        }
        let history = RoutineScheduleHistory(routineID: owner.owner.id, createdDayKey: attributes.createdDay,
                                            evidence: request.scheduleEvidence, dates: request.session.queryDates)
        if case .window(let window) = ContentQueryDateWindow.resolve(request.session.conditions, dates: request.session.queryDates) {
            existence = history.existence(in: window)
        } else { existence = nil }
        if case .selected(let day) = request.session.occurrenceDay {
            let coverage = RoutineCheckCoverage(routineID: owner.owner.id, completeIntervals: request.checkCoverage.filter {
                $0.routineID == owner.owner.id
            }.flatMap(\.completeIntervals))
            occurrence = .init(schedule: history.day(day), records: RoutineCheckReading.read(
                routineID: owner.owner.id, on: day, checks: request.checks, coverage: coverage, dates: request.session.queryDates))
        } else { occurrence = nil }
    }

    func date(_ interval: ContentQueryDateInterval, id: ContentQueryConditionID) -> Result {
        guard let existence else { return .unknown(.invalidScheduleEvidence, id: id) }
        var result = Result(truth: existence.truth)
        if existence.truth == .invalidInput {
            result.diagnostics.append(.init(issue: .invalidScheduleEvidence, conditionIDs: [id]))
        }
        result.diagnostics += existence.unknownReasons.map {
            .init(issue: .schedule($0), severity: .warning, conditionIDs: [id])
        }
        if !existence.intervalsContainingUnknownDays.isEmpty {
            result.diagnostics.append(.init(issue: .uncertainSchedule, severity: .warning, conditionIDs: [id]))
        }
        if let day = existence.witnessDay {
            result.truth = ContentQuerySnapshotMatching.contains(interval, day: day) ? .matches : .doesNotMatch
            if result.truth == .matches { result.evidence = [.init(conditionID: id, field: .ownerScheduleExistence)] }
        }
        return result
    }

    func on(id: ContentQueryConditionID, status: ContentQueryStatus?) -> Result {
        guard let occurrence else { return .unknown(.missingOccurrenceDay, id: id) }
        let truth: RoutineQueryTruth
        if let status { truth = occurrence.matching(status) }
        else {
            switch occurrence.schedule.state {
            case .scheduled: truth = .matches
            case .notScheduled: truth = .doesNotMatch
            case .unknown: truth = .unknown
            case .invalidInput: truth = .invalidInput
            }
        }
        var result = Result(truth: truth, evidence: truth == .matches ? [.init(
            conditionID: id, field: status == nil ? .ownerOccurrenceDay : .ownerCompletion,
            relatedObject: occurrence.schedule.object)] : [])
        if occurrence.schedule.state == .unknown {
            result.diagnostics.append(.init(issue: .schedule(occurrence.schedule.reason), conditionIDs: [id]))
        }
        if occurrence.schedule.state == .invalidInput {
            result.diagnostics.append(.init(issue: .invalidScheduleEvidence, conditionIDs: [id]))
        }
        result.diagnostics += occurrence.records.diagnostics.map {
            .init(issue: .check($0), severity: $0.affectsDetermination ? .error : .warning,
                  affectsDetermination: status != nil && $0.affectsDetermination, conditionIDs: [id])
        }
        return result
    }
}
