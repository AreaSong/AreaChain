import Foundation

enum DiaryQueryTruth: Equatable { case matches, doesNotMatch, unknown }

/// 手记的局部三态组合；先收集所有分支诊断，再决定真假，不把 unknown 取反成 true。
struct DiaryQueryEvaluation {
    var truth: DiaryQueryTruth
    var evidence: [ContentQueryMatchEvidence] = []
    var diagnostics: [DiaryQueryDiagnostic] = []

    static func combine(_ values: [Self], any: Bool) -> Self {
        let decisive: DiaryQueryTruth = any ? .matches : .doesNotMatch
        let fallback: DiaryQueryTruth = any ? .doesNotMatch : .matches
        let truth = values.contains { $0.truth == decisive } ? decisive
            : (values.contains { $0.truth == .unknown } ? .unknown : fallback)
        return .init(truth: truth, evidence: values.filter { $0.truth == .matches }.flatMap(\.evidence),
                     diagnostics: values.flatMap { value in
                        value.diagnostics.map { diagnostic in
                            var diagnostic = diagnostic
                            diagnostic.affectsDetermination = diagnostic.affectsDetermination
                                && truth == .unknown && value.truth == .unknown
                            return diagnostic
                        }
                     })
    }

    static func known(_ matches: Bool, id: ContentQueryConditionID, field: ContentQueryMatchField) -> Self {
        .init(truth: matches ? .matches : .doesNotMatch,
              evidence: matches ? [.init(conditionID: id, field: field)] : [])
    }

    static func unknown(_ issue: DiaryQueryIssue, id: ContentQueryConditionID) -> Self {
        .init(truth: .unknown, diagnostics: [.init(issue: issue, conditionIDs: [id])])
    }
}

/// 只核对注入值，不调用 DiaryContent.snapshot/read 或 vault。快照的保护标志必须由生产者保留。
struct DiaryQueryPrivacy {
    let canPublishBody: Bool
    let diagnostics: [DiaryQueryDiagnostic]

    init(diary: DiarySnapshot, metadata: DiaryQueryMetadata) {
        var readable = diary
        // 不可读快照可能携带展示占位文字；不能把它当正文判断旧标记。
        if !readable.isContentAvailable { readable.text = "" }
        let sensitive = DiaryPrivacy.isSensitive(readable, tagNames: metadata.tagNames ?? [:],
                                                  privateTagIDs: metadata.privateTagIDs ?? [])
        let namesComplete = metadata.tagNames.map { names in
            TagIDList.parse(diary.tagIDs).allSatisfy { names[$0] != nil }
        } ?? false
        let validTags = DiaryQueryMetadata.hasValidTagIDs(diary.tagIDs)
        let complete = namesComplete && metadata.privateTagIDs != nil && validTags
        canPublishBody = diary.isContentAvailable && !sensitive && complete
        var issues: [DiaryQueryDiagnostic] = []
        // 资料完整性诊断只由元数据决定，不能借诊断有无泄露正文是否含旧敏感标记。
        if !complete {
            issues.append(.init(issue: .incompletePrivacyMetadata, severity: .warning, affectsDetermination: false))
        }
        if !validTags { issues.append(.init(issue: .invalidTagIDs, affectsDetermination: false)) }
        diagnostics = issues
    }
}
