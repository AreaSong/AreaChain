import Foundation

/// 活定义的有界只读提供者；只保持输入顺序，不产生每日结果、排序或操作目标。
enum RoutineQueryProvider {
    static func read(_ request: RoutineQueryRequest) -> RoutineQueryResponse {
        let session = request.session
        let composition = session.composition
        let applicable = composition?.types.contains(.routine) == true && composition?.deletion == .liveOnly
        let valid = session.isStructurallyValid
        var response = RoutineQueryResponse(
            requestID: request.requestID, queryIsValid: valid, typeAnalysis: session.typeAnalysis,
            state: valid ? (applicable ? .evaluated : .notApplicable) : .invalidQuery,
            coverage: .init(requestedTypes: composition?.types ?? [], coveredTypes: applicable ? [.routine] : [],
                            deletion: composition?.deletion),
            textDiagnostics: session.textDiagnostics, conditionDiagnostics: session.conditionDiagnostics)
        guard valid else { response.diagnostics = [.init(issue: .invalidQuery)]; return response }
        guard applicable else { return response }
        if let restriction = session.typeAnalysis.assessment(for: .routine)?.readRestriction {
            response.state = restriction
            return response
        }
        guard ContentQuerySnapshotValidation.validDay(session.queryDates.todayKey, dates: session.queryDates) else {
            response.state = .blocked
            response.diagnostics = [.init(issue: .invalidDateContext)]
            return response
        }
        // 即使没有候选定义，也公开能力缺口；对象是否确定由下面的完整布尔求值决定。
        response.diagnostics = capabilities(request)
        evaluate(request, response: &response)
        return response
    }

    private static func capabilities(_ request: RoutineQueryRequest) -> [RoutineQueryDiagnostic] {
        request.session.conditions.flatMap { condition -> [RoutineQueryDiagnostic] in
            var issues: [RoutineQueryIssue] = []
            switch condition.value {
            case .clause(let terms):
                if request.imageInput == nil && terms.contains(where: { $0.atom == .image }) {
                    issues.append(.imageAssociationUnavailable)
                }
                if request.tagNames == nil && terms.contains(where: { $0.atom.dimension == .tag }) { issues.append(.missingTagNames) }
            case .page(.boardDate(let scope, let rule)):
                if rule.evaluation == .listedDay && ![.all, .today].contains(scope) { issues.append(.unsupportedListedDay) }
                if rule.evaluation == .agenda && ![.overdue, .upcoming].contains(scope) { issues.append(.unsupportedAgendaDate) }
            default: break
            }
            return issues.map { .init(issue: $0, affectsDetermination: false, conditionIDs: [condition.id]) }
        }
    }

    private static func evaluate(_ request: RoutineQueryRequest, response: inout RoutineQueryResponse) {
        let positions = Dictionary(grouping: request.routines.indices, by: { request.routines[$0].id })
        let images = ContentQueryImageRead(conditions: request.session.conditions, input: request.imageInput,
                                          owners: .init(routines: request.routines))
        for (index, routine) in request.routines.enumerated() {
            let object = CommandObjectReference(type: .routine, id: routine.id)
            let indices = positions[routine.id] ?? []
            if indices.count > 1 {
                if indices.first == index {
                    response.diagnostics.append(.init(issue: .duplicateRoutineID, object: object, inputIndices: indices))
                    response.undeterminedObjects.append(object)
                }
                continue
            }
            guard routine.deletedAt == nil else { continue }
            let issues = validation(routine, dates: request.session.queryDates)
            guard issues.isEmpty else {
                response.diagnostics += issues.map { .init(issue: $0, object: object, inputIndices: [index]) }
                response.undeterminedObjects.append(object)
                continue
            }
            let matcher = RoutineQueryMatching(request: request, routine: routine, images: images)
            let result = matcher.evaluate()
            response.diagnostics += result.diagnostics.map {
                var diagnostic = $0
                diagnostic.object = object
                diagnostic.affectsDetermination = diagnostic.affectsDetermination
                    && (result.truth == .unknown || result.truth == .invalidInput)
                return diagnostic
            }
            switch result.truth {
            case .matches:
                response.matches.append(.init(id: object, title: routine.title, notes: routine.notes,
                                              createdAt: routine.createdAt, isEnabled: routine.isEnabled,
                                              evidence: result.evidence, dateExistence: matcher.existence,
                                              occurrence: matcher.occurrence))
            case .unknown, .invalidInput: response.undeterminedObjects.append(object)
            case .doesNotMatch: break
            }
        }
    }

    private static func validation(_ routine: RoutineSnapshot, dates: ContentQueryDateContext) -> [RoutineQueryIssue] {
        var issues: [RoutineQueryIssue] = []
        if !ContentQuerySnapshotValidation.validDay(routine.createdDayKey, dates: dates) { issues.append(.invalidCreatedDay) }
        if !ContentQuerySnapshotValidation.validTimestamp(routine.createdAt, dates: dates) { issues.append(.invalidCreatedAt) }
        return issues
    }
}
