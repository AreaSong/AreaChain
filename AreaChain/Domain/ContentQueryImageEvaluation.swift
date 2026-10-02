import Foundation

// 三个提供者保留各自诊断/三态类型；这里只适配共用存在性结论，不引入全类型查询框架。
extension ContentQueryImageEvaluation {
    var todo: TodoQueryEvaluation {
        let value: TodoQueryTruth
        switch truth {
        case .matches: value = .matches
        case .doesNotMatch: value = .doesNotMatch
        case .unknown: value = .unknown
        }
        return .init(truth: value, evidence: evidence, diagnostics: reasons.map { reason in
            .init(issue: reason.issue == .inputNotProvided ? .imageAssociationUnavailable : .imageAssociation(reason.issue),
                  severity: reason.isError ? .error : .warning, affectsDetermination: reason.affectsDetermination,
                  conditionIDs: [reason.conditionID])
        })
    }

    var routine: RoutineQueryEvaluationResult {
        let value: RoutineQueryTruth
        switch truth {
        case .matches: value = .matches
        case .doesNotMatch: value = .doesNotMatch
        case .unknown: value = .unknown
        }
        return .init(truth: value, evidence: evidence, diagnostics: reasons.map { reason in
            .init(issue: reason.issue == .inputNotProvided ? .imageAssociationUnavailable : .imageAssociation(reason.issue),
                  severity: reason.isError ? .error : .warning, affectsDetermination: reason.affectsDetermination,
                  conditionIDs: [reason.conditionID])
        })
    }

    var diary: DiaryQueryEvaluation {
        let value: DiaryQueryTruth
        switch truth {
        case .matches: value = .matches
        case .doesNotMatch: value = .doesNotMatch
        case .unknown: value = .unknown
        }
        return .init(truth: value, evidence: evidence, diagnostics: reasons.map { reason in
            .init(issue: reason.issue == .inputNotProvided ? .imageAssociationUnavailable : .imageAssociation(reason.issue),
                  severity: reason.isError ? .error : .warning, affectsDetermination: reason.affectsDetermination,
                  conditionIDs: [reason.conditionID])
        })
    }
}
