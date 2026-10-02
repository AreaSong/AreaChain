import Foundation

enum TodoQueryTruth { case matches, doesNotMatch, unknown }

/// 保留既有 todo 字段匹配，给图片条件增加局部三态；所有分支先求值，避免短路吞掉输入错误。
struct TodoQueryEvaluation {
    var truth: TodoQueryTruth
    var evidence: [ContentQueryMatchEvidence] = []
    var diagnostics: [TodoQueryDiagnostic] = []

    static func combine(_ values: [Self], any: Bool) -> Self {
        let decisive: TodoQueryTruth = any ? .matches : .doesNotMatch
        let fallback: TodoQueryTruth = any ? .doesNotMatch : .matches
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

    static func known(_ evidence: [ContentQueryMatchEvidence]?) -> Self {
        .init(truth: evidence == nil ? .doesNotMatch : .matches, evidence: evidence ?? [])
    }
}
