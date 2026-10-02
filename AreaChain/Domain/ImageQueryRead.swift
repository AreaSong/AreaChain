import Foundation

/// 同一次 read 内解析关联，避免把旧响应拼到新拥有者上；requestID 不是安全授权或仓储代次。
/// 标签名字、排程与记录证据也必须由调用方绑定到本次读取上下文，领域层不核验真实来源。
struct ImageQueryRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let session: ContentQuerySession
    let association: ImageAssociationRequest
    var tagNames: [UUID: String]?
    var checks: [CheckSnapshot] = []
    var checkCoverage: [RoutineCheckCoverage] = []
    var scheduleEvidence: [RoutineScheduleEvidence] = []

    var description: String { "ImageQueryRequest(redacted)" }
    var debugDescription: String { description }
}

enum ImageQueryIssue: Equatable {
    case invalidQuery, invalidDateContext, invalidCreatedAt, missingOwnerAttributes
    case missingTagNames, missingAssociatedTagNames, ownerConditionNotApplicable, missingOccurrenceDay
    case ownerSourceUnavailable, unsupportedOwnerPageDate
    case invalidScheduleEvidence, uncertainSchedule
    case schedule(RoutineScheduleReason), check(RoutineCheckIssue)
}

struct ImageQueryDiagnostic: Equatable {
    let issue: ImageQueryIssue
    var severity: RoutineQuerySeverity = .error
    var affectsDetermination = true
    var conditionIDs: [ContentQueryConditionID] = []
    /// 仅已通过关联层的公开图片；无原始输入下标、隐藏图片 ID 或文件名。
    var object: CommandObjectReference?
    var owner: AttachmentOwnerKey?
}

enum ImageQueryAssociationCompleteness: Equatable { case notRead, completeForDeclaredInput, incomplete }

struct ImageQueryCoverage: Equatable {
    let providerTypes: Set<CommandObjectType> = [.image]
    let requestedTypes: Set<CommandObjectType>
    let coveredTypes: Set<CommandObjectType>
    let deletion: ContentQueryDeletionPolicy?
    var associations: ImageQueryAssociationCompleteness = .notRead
    var containsProtectedContent = false
    var isPartialTypeCoverage: Bool { !requestedTypes.isSubset(of: coveredTypes) }
}

/// filename 原文只保存一份；日期见证不是默认操作日，结果不承诺文件存在或可打开。
struct ImageQueryMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let image: ImageBrowseProjection
    var id: CommandObjectReference { image.id }
    var filename: String { image.filename }
    var createdAt: Date { image.createdAt }
    var owner: AttachmentOwnerKey { image.owner }
    let evidence: [ContentQueryMatchEvidence]
    let businessDay: String?
    let dateExistence: RoutineScheduleExistence?
    let occurrence: RoutineOccurrenceEvaluation?

    var description: String { "ImageQueryMatch(redacted)" }
    var debugDescription: String { description }
}

struct ImageQueryResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let queryIsValid: Bool
    let typeAnalysis: ContentQueryTypeAnalysis
    var state: TodoQueryReadState
    var coverage: ImageQueryCoverage
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    var associationDiagnostics: [ImageAssociationDiagnostic] = []
    /// 原关联层的非明细状态；不添加受保护图片的计数或对象未知项。
    var associations: [AttachmentOwnerKey: ImageOwnerAssociation] = [:]
    var owners: [AttachmentOwnerKey: ImageOwnerProjection] = [:]
    var diagnostics: [ImageQueryDiagnostic] = []
    var matches: [ImageQueryMatch] = []
    var undeterminedObjects: [CommandObjectReference] = []

    var isCompleteForCoveredTypes: Bool {
        state == .evaluated && coverage.associations == .completeForDeclaredInput
            && !coverage.containsProtectedContent && undeterminedObjects.isEmpty
            && !diagnostics.contains { $0.affectsDetermination }
    }
    var description: String { "ImageQueryResponse(redacted)" }
    var debugDescription: String { description }
}

/// 三态组合先保留诊断；某个条件的确定失败可排除公开对象，不把无关未知升级为全局阻断。
struct ImageQueryEvaluation {
    var truth: RoutineQueryTruth
    var evidence: [ContentQueryMatchEvidence] = []
    var diagnostics: [ImageQueryDiagnostic] = []

    static func combine(_ values: [Self], any: Bool) -> Self {
        let decisive: RoutineQueryTruth = any ? .matches : .doesNotMatch
        let truth: RoutineQueryTruth = values.contains { $0.truth == decisive } ? decisive
            : (values.contains { [.unknown, .invalidInput].contains($0.truth) } ? .unknown : (any ? .doesNotMatch : .matches))
        return .init(truth: truth, evidence: values.filter { $0.truth == .matches }.flatMap(\.evidence),
                     diagnostics: values.flatMap { value in
                         value.diagnostics.map { diagnostic in
                             var diagnostic = diagnostic
                             diagnostic.affectsDetermination = diagnostic.affectsDetermination && truth == .unknown
                                 && [.unknown, .invalidInput].contains(value.truth)
                             return diagnostic
                         }
                     })
    }

    static func known(_ matched: Bool, id: ContentQueryConditionID, field: ContentQueryMatchField) -> Self {
        .init(truth: matched ? .matches : .doesNotMatch,
              evidence: matched ? [.init(conditionID: id, field: field)] : [])
    }

    static func unknown(_ issue: ImageQueryIssue, id: ContentQueryConditionID) -> Self {
        .init(truth: .unknown, diagnostics: [.init(issue: issue, conditionIDs: [id])])
    }
}
