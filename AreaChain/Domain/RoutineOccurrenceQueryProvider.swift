import Foundation

/// 只消费显式执行记录范围；不接真实仓储，不给旧定义提供者添加隐式每日结果。
enum RoutineOccurrenceQueryProvider {
    static func read(_ request: RoutineOccurrenceQueryRequest) -> RoutineOccurrenceQueryResponse {
        let session = request.session
        let composition = session.composition
        let applicable = session.scope == .routineOccurrences && composition?.deletion == .liveOnly
            && composition?.types.contains(.routineOccurrence) == true
        let valid = session.isStructurallyValid
        var response = RoutineOccurrenceQueryResponse(
            requestID: request.requestID, queryIsValid: valid, typeAnalysis: session.typeAnalysis,
            state: valid ? (applicable ? .evaluated : .notApplicable) : .invalidQuery,
            coverage: .init(requestedTypes: composition?.types ?? [], coveredTypes: applicable ? [.routineOccurrence] : [],
                            deletion: composition?.deletion, definitions: request.definitionCoverage),
            textDiagnostics: session.textDiagnostics, conditionDiagnostics: session.conditionDiagnostics)
        guard valid else { response.diagnostics = [.init(issue: .invalidQuery)]; return response }
        guard applicable else { return response }
        guard prepareWindow(request, response: &response) else { return response }
        if let restriction = session.typeAnalysis.assessment(for: .routineOccurrence)?.readRestriction {
            response.state = restriction
            return response
        }
        guard request.budget.isValid else {
            response.state = .blocked
            response.diagnostics.append(.init(issue: .invalidBudget))
            return response
        }
        var reading = RoutineOccurrenceQueryEnumeration(request: request, response: response)
        reading.run()
        return reading.response
    }

    private static func prepareWindow(
        _ request: RoutineOccurrenceQueryRequest, response: inout RoutineOccurrenceQueryResponse
    ) -> Bool {
        let session = request.session
        let dates = session.queryDates
        guard ContentQuerySnapshotValidation.validDay(dates.todayKey, dates: dates) else {
            return reject(.invalidDateContext, state: .blocked, response: &response)
        }
        let date: ContentQueryDateWindow?
        switch ContentQueryDateWindow.resolve(session.conditions, dates: dates) {
        case .unconstrained: date = nil
        case .window(let value): date = value
        case .invalid: return reject(.invalidQuery, state: .invalidQuery, response: &response)
        }
        let browse = request.browseWindow
        if let browse, !browse.intervals.allSatisfy({ ContentQueryDateWindow.valid($0, calendar: dates.calendar) }) {
            return reject(.invalidDateContext, state: .blocked, response: &response)
        }
        if let date, let browse, date != browse {
            return reject(.inconsistentWindows, state: .invalidQuery, response: &response)
        }
        let on = session.occurrenceDay.dayKey
        var effective = date ?? browse
        if let on {
            if let effective, !effective.contains(on) {
                return reject(.occurrenceOutsideWindow, state: .unsatisfiable, response: &response)
            }
            effective = .init(intervals: [.init(lowerBound: on, upperBound: on)], calendar: dates.calendar)
        }
        guard let effective else { return reject(.missingWindow, state: .requiresInput, response: &response) }
        response.coverage.window = .init(date: date, browse: browse, on: on, effective: effective)
        return true
    }

    private static func reject(
        _ issue: RoutineOccurrenceQueryIssue, state: TodoQueryReadState, response: inout RoutineOccurrenceQueryResponse
    ) -> Bool {
        response.state = state
        response.diagnostics.append(.init(issue: issue))
        return false
    }
}

/// 全部条件参与且沿原条件 ID 给出依据；类型分析拒绝所属字段，不把标题拿来匹配记录。
enum RoutineOccurrenceQueryMatching {
    static func evidence(
        session: ContentQuerySession, occurrence: RoutineOccurrenceEvaluation
    ) -> [ContentQueryMatchEvidence]? {
        let results = session.conditions.map { condition -> RoutineQueryEvaluationResult in
            switch condition.value {
            case .scope:
                return .known(true, id: condition.id, field: .scope)
            case .page(.contentTypes(let types)):
                return .known(types.contains(.routineOccurrence), id: condition.id, field: .objectType)
            case .clause(let terms):
                let values = terms.enumerated().map { index, term -> RoutineQueryEvaluationResult in
                    var value = atom(term.atom, occurrence: occurrence, id: condition.id)
                    value.evidence = value.evidence.map { evidence in
                        var next = evidence
                        next.alternativeIndex = index
                        return next
                    }
                    return value
                }
                return .combine(values, any: true)
            default: return .init(truth: .unknown)
            }
        }
        let result = RoutineQueryEvaluationResult.combine(results, any: false)
        return result.truth == .matches ? result.evidence : nil
    }

    private static func atom(
        _ atom: ContentQueryAtom, occurrence: RoutineOccurrenceEvaluation, id: ContentQueryConditionID
    ) -> RoutineQueryEvaluationResult {
        let day = occurrence.records.object.dayKey ?? ""
        switch atom {
        case .date(let interval):
            return .known(ContentQuerySnapshotMatching.contains(interval, day: day), id: id, field: .occurrenceDay)
        case .on(let selected): return .known(day == selected, id: id, field: .occurrenceDay)
        case .status(let status): return .known(occurrence.matching(status) == .matches, id: id, field: .completion)
        default: return .init(truth: .unknown)
        }
    }
}
