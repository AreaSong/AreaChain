import Foundation

/// 仅求值活手记注入快照；生产者负责保留 DiaryContent.snapshot 的可读性/保护事实。
enum DiaryQueryProvider {
    static func read(_ request: DiaryQueryRequest) -> DiaryQueryResponse {
        let session = request.session
        let composition = session.composition
        let applicable = composition?.types.contains(.diary) == true && composition?.deletion == .liveOnly
        let valid = session.isStructurallyValid
        var response = DiaryQueryResponse(
            requestID: request.requestID, queryIsValid: valid, typeAnalysis: session.typeAnalysis,
            state: valid ? (applicable ? .evaluated : .notApplicable) : .invalidQuery,
            coverage: .init(requestedTypes: composition?.types ?? [], coveredTypes: applicable ? [.diary] : [],
                            deletion: composition?.deletion),
            textDiagnostics: session.textDiagnostics, conditionDiagnostics: session.conditionDiagnostics)
        guard valid else { response.diagnostics = [.init(issue: .invalidQuery)]; return response }
        guard applicable else { return response }
        if let restriction = session.typeAnalysis.assessment(for: .diary)?.readRestriction {
            response.state = restriction
            return response
        }
        guard ContentQuerySnapshotValidation.validDay(session.queryDates.todayKey, dates: session.queryDates) else {
            response.state = .blocked
            response.diagnostics = [.init(issue: .invalidDateContext)]
            return response
        }
        // 即使没有候选也报告缺失能力；是否影响某个对象由完整三态求值决定。
        response.diagnostics = session.conditions.compactMap { condition in
            guard request.imageInput == nil, case .clause(let terms) = condition.value,
                  terms.contains(where: { $0.atom == .image }) else { return nil }
            return .init(issue: .imageAssociationUnavailable, affectsDetermination: false, conditionIDs: [condition.id])
        }
        evaluate(request, response: &response)
        return response
    }

    private static func evaluate(_ request: DiaryQueryRequest, response: inout DiaryQueryResponse) {
        let positions = Dictionary(grouping: request.diaries.indices, by: { request.diaries[$0].id })
        let images = ContentQueryImageRead(conditions: request.session.conditions, input: request.imageInput,
                                          owners: .init(diaries: request.diaries), privacy: request.metadata)
        let context = DiaryQueryMatching.Context(session: request.session, metadata: request.metadata, images: images)
        for (index, diary) in request.diaries.enumerated() {
            let object = CommandObjectReference(type: .diary, id: diary.id)
            let indices = positions[diary.id] ?? []
            if diary.deletedAt == nil {
                response.diagnostics += DiaryQueryPrivacy(diary: diary, metadata: request.metadata).diagnostics.map {
                    var diagnostic = $0
                    diagnostic.object = object
                    diagnostic.inputIndices = [index]
                    return diagnostic
                }
            }
            if indices.count > 1 {
                if indices.first == index {
                    response.diagnostics.append(.init(issue: .duplicateDiaryID, object: object, inputIndices: indices))
                    response.undeterminedObjects.append(object)
                }
                continue
            }
            guard diary.deletedAt == nil else { continue }
            let issues = validation(diary, dates: request.session.queryDates)
            guard issues.isEmpty else {
                response.diagnostics += issues.map { .init(issue: $0, object: object, inputIndices: [index]) }
                response.undeterminedObjects.append(object)
                continue
            }
            let result = DiaryQueryMatching(context: context, diary: diary).evaluate()
            response.diagnostics += result.diagnostics.map {
                var diagnostic = $0
                diagnostic.object = object
                diagnostic.inputIndices = [index]
                return diagnostic
            }
            switch result.truth {
            case .matches:
                response.matches.append(.init(diary: diary, metadata: request.metadata, evidence: result.evidence,
                                              session: request.session, locale: request.locale))
            case .unknown: response.undeterminedObjects.append(object)
            case .doesNotMatch: break
            }
        }
    }

    private static func validation(_ diary: DiarySnapshot, dates: ContentQueryDateContext) -> [DiaryQueryIssue] {
        var issues: [DiaryQueryIssue] = []
        if !ContentQuerySnapshotValidation.validDay(diary.dayKey, dates: dates) { issues.append(.invalidDiaryDay) }
        if !ContentQuerySnapshotValidation.validTimestamp(diary.createdAt, dates: dates) { issues.append(.invalidCreatedAt) }
        return issues
    }
}
