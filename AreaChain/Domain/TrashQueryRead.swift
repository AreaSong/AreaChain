import Foundation

/// 一次同步读取的输入；标签名覆盖与墓碑身份覆盖独立，不保存到响应。
struct TrashQueryRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let session: ContentQuerySession
    let input: TrashTombstoneInput
    var routineInput: TrashQueryRoutineInput?
    var tagNames: [UUID: String]?
    var tagNamesCoverage: TrashReadCompleteness = .notProvided
    var description: String { "TrashQueryRequest(redacted)" }
    var debugDescription: String { description }
}

enum TrashQueryIssue: Equatable {
    case schedule(RoutineScheduleReason), check(RoutineCheckIssue)
    case unreadableBody, missingParentAttributes, missingTagNames, invalidField
    case imageAssociationUnavailable, routineEvidenceUnavailable, unsupportedCondition
}

struct TrashQueryDiagnostic: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let issue: TrashQueryIssue
    let conditionID: ContentQueryConditionID
    var object: CommandObjectReference?
    var affectsDetermination = true
    var description: String { "TrashQueryDiagnostic(redacted)" }
    var debugDescription: String { description }
}

struct TrashQueryMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let object: TrashTombstone
    let evidence: [ContentQueryMatchEvidence]
    var id: CommandObjectReference { object.id }
    var description: String { "TrashQueryMatch(redacted)" }
    var debugDescription: String { description }
}

/// displayAnchor 可以是提升的子项；source 保留真实父组，绝不把上下文当操作目标。
struct TrashQueryGroup: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let source: TrashTombstoneGroup
    let displayAnchor: CommandObjectReference
    let matches: [CommandObjectReference]
    let context: [TrashTombstone]
    var description: String { "TrashQueryGroup(redacted)" }
    var debugDescription: String { description }
}

enum TrashQueryState: Equatable { case invalidQuery, notApplicable, evaluated }

struct TrashQueryResponse: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let state: TrashQueryState
    let typeAnalysis: ContentQueryTypeAnalysis
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    var typeCoverage: [CommandObjectType: TrashReadCompleteness] = [:]
    var readingDiagnostics: [TrashTombstoneDiagnostic] = []
    var diagnostics: [TrashQueryDiagnostic] = []
    var matches: [TrashQueryMatch] = []
    var groups: [TrashQueryGroup] = []
    var undeterminedObjects: [CommandObjectReference] = []
    var nonmatchingObjects: [CommandObjectReference] = []
    var restrictedTypes: [CommandObjectType: ContentQueryTypeAssessment] = [:]
    var definiteMatchCount: Int { matches.count }
    var visibleGroupCount: Int { groups.count }
    var visibleContextCount: Int { groups.reduce(0) { $0 + $1.context.count } }
    /// 固定粗粒度限制，不随隐藏图片的存在、数量或查询而改变。
    var imageDisplayLimited: Bool { state == .evaluated }
    var countsDescribeVisibleProjectionOnly: Bool { true }
    var hasIncompleteInput: Bool {
        typeCoverage.values.contains { $0 != .completeIncludingDeleted } || !readingDiagnostics.isEmpty
    }
    var description: String { "TrashQueryResponse(redacted)" }
    var debugDescription: String { description }
}

struct TrashQueryEvaluation: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "TrashQueryEvaluation(redacted)" }
    var debugDescription: String { description }
    var value: TodoQueryEvaluation
    var diagnostics: [TrashQueryDiagnostic] = []

    static func known(_ evidence: [ContentQueryMatchEvidence]?) -> Self { .init(value: .known(evidence)) }
    static func unknown(_ issue: TrashQueryIssue, id: ContentQueryConditionID) -> Self {
        .init(value: .init(truth: .unknown), diagnostics: [.init(issue: issue, conditionID: id)])
    }
    static func combine(_ values: [Self], any: Bool) -> Self {
        let combined = TodoQueryEvaluation.combine(values.map(\.value), any: any)
        return .init(value: combined, diagnostics: values.flatMap { result in
            result.diagnostics.map { diagnostic in
                var diagnostic = diagnostic
                diagnostic.affectsDetermination = diagnostic.affectsDetermination && combined.truth == .unknown
                return diagnostic
            }
        })
    }
}
