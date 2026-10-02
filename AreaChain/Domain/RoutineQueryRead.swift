import Foundation

/// 全部输入均为调用方声明；本请求不证明真实仓储或历史已经核验。
struct RoutineQueryRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let session: ContentQuerySession
    let routines: [RoutineSnapshot]
    let tagNames: [UUID: String]?
    let checks: [CheckSnapshot]
    let checkCoverage: [RoutineCheckCoverage]
    let scheduleEvidence: [RoutineScheduleEvidence]
    var imageInput: ContentQueryImageInput?

    var description: String { "RoutineQueryRequest(redacted)" }
    var debugDescription: String { description }
}

enum RoutineQueryIssue: Equatable {
    case invalidQuery, invalidDateContext, duplicateRoutineID, invalidCreatedDay, invalidCreatedAt
    case missingTagNames, missingAssociatedTagName(UUID), imageAssociationUnavailable
    case unsupportedListedDay, unsupportedAgendaDate, missingPageCheckCoverage, invalidPageCheckInput
    case invalidScheduleEvidence, uncertainSchedule, missingOccurrenceDay
    case check(RoutineCheckIssue), schedule(RoutineScheduleReason)
    case imageAssociation(ContentQueryImageIssue)
}

enum RoutineQuerySeverity: Equatable { case warning, error }

struct RoutineQueryDiagnostic: Equatable {
    let issue: RoutineQueryIssue
    var severity: RoutineQuerySeverity = .error
    /// 严重程度不决定结果；例如相同重复只警告，AND 已确定失败也可使未知不再影响最终结果。
    var affectsDetermination = true
    var conditionIDs: [ContentQueryConditionID] = []
    var object: CommandObjectReference?
    var inputIndices: [Int] = []
}

struct RoutineQueryCoverage: Equatable {
    let providerTypes: Set<CommandObjectType> = [.routine]
    let requestedTypes: Set<CommandObjectType>
    let coveredTypes: Set<CommandObjectType>
    let deletion: ContentQueryDeletionPolicy?
    var isPartialTypeCoverage: Bool { !requestedTypes.isSubset(of: coveredTypes) }
}

/// 见证日不是操作日；只有 occurrence 的 object.dayKey 是用户显式 on。
struct RoutineQueryMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let title: String
    let notes: String
    let createdAt: Date
    let isEnabled: Bool
    let evidence: [ContentQueryMatchEvidence]
    let dateExistence: RoutineScheduleExistence?
    let occurrence: RoutineOccurrenceEvaluation?

    var description: String { "RoutineQueryMatch(redacted)" }
    var debugDescription: String { description }
}

struct RoutineQueryResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let queryIsValid: Bool
    let typeAnalysis: ContentQueryTypeAnalysis
    var state: TodoQueryReadState
    let coverage: RoutineQueryCoverage
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    var diagnostics: [RoutineQueryDiagnostic] = []
    var matches: [RoutineQueryMatch] = []
    var undeterminedObjects: [CommandObjectReference] = []

    var isCompleteForCoveredTypes: Bool {
        state == .evaluated && undeterminedObjects.isEmpty && !diagnostics.contains { $0.affectsDetermination }
    }
    var description: String { "RoutineQueryResponse(redacted)" }
    var debugDescription: String { description }
}

/// 每组求值保留所有诊断，再做三值逻辑；不因短路遗漏输入错误。
struct RoutineQueryEvaluationResult {
    var truth: RoutineQueryTruth
    var evidence: [ContentQueryMatchEvidence] = []
    var diagnostics: [RoutineQueryDiagnostic] = []

    static func combine(_ values: [Self], any: Bool) -> Self {
        let truths = values.map(\.truth)
        let decisive: RoutineQueryTruth = any ? .matches : .doesNotMatch
        let fallback: RoutineQueryTruth = any ? .doesNotMatch : .matches
        let truth = truths.contains(decisive) ? decisive
            : (truths.contains(.unknown) || truths.contains(.invalidInput) ? .unknown : fallback)
        return .init(truth: truth, evidence: values.filter { $0.truth == .matches }.flatMap(\.evidence),
                     diagnostics: values.flatMap { value in
                        value.diagnostics.map { diagnostic in
                            var diagnostic = diagnostic
                            diagnostic.affectsDetermination = diagnostic.affectsDetermination && truth == .unknown
                                && (value.truth == .unknown || value.truth == .invalidInput)
                            return diagnostic
                        }
                     })
    }

    static func known(_ matches: Bool, id: ContentQueryConditionID, field: ContentQueryMatchField) -> Self {
        .init(truth: matches ? .matches : .doesNotMatch,
              evidence: matches ? [.init(conditionID: id, field: field)] : [])
    }

    static func unknown(_ issue: RoutineQueryIssue, id: ContentQueryConditionID) -> Self {
        .init(truth: .unknown, diagnostics: [.init(issue: issue, conditionIDs: [id])])
    }
}
