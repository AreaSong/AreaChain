import Foundation

/// nil 是未提供，空集合是调用方声明已提供；这些事实不授予正文访问或解锁能力。
struct DiaryQueryMetadata: CustomStringConvertible, CustomDebugStringConvertible {
    let tagNames: [UUID: String]?
    let privateTagIDs: Set<UUID>?

    static func hasValidTagIDs(_ raw: String) -> Bool {
        TagIDList.parse(raw).count == raw.split(separator: ",").count
    }

    var description: String { "DiaryQueryMetadata(redacted)" }
    var debugDescription: String { description }
}

struct DiaryQueryRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let session: ContentQuerySession
    let diaries: [DiarySnapshot]
    let metadata: DiaryQueryMetadata
    let locale: Locale
    var imageInput: ContentQueryImageInput?

    var description: String { "DiaryQueryRequest(redacted)" }
    var debugDescription: String { description }
}

enum DiaryQueryIssue: Equatable {
    case invalidQuery, invalidDateContext, duplicateDiaryID, invalidDiaryDay, invalidCreatedAt
    case missingTagNames, missingAssociatedTagName(UUID), incompletePrivacyMetadata
    case bodyUnavailable, imageAssociationUnavailable, inapplicableCondition, invalidTagIDs
    case imageAssociation(ContentQueryImageIssue)
}

enum DiaryQuerySeverity: Equatable { case warning, error }

/// 只带机器原因和身份；不携带查询原文、正文、占位内容或标签名字。
struct DiaryQueryDiagnostic: Equatable {
    let issue: DiaryQueryIssue
    var severity: DiaryQuerySeverity = .error
    var affectsDetermination = true
    var conditionIDs: [ContentQueryConditionID] = []
    var object: CommandObjectReference?
    var inputIndices: [Int] = []
}

struct DiaryQueryCoverage: Equatable {
    let providerTypes: Set<CommandObjectType> = [.diary]
    let requestedTypes: Set<CommandObjectType>
    let coveredTypes: Set<CommandObjectType>
    let deletion: ContentQueryDeletionPolicy?

    var isPartialTypeCoverage: Bool { !requestedTypes.isSubset(of: coveredTypes) }
}

struct DiaryQueryTag: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let name: String?

    var description: String { "DiaryQueryTag(redacted)" }
    var debugDescription: String { description }
}

/// 隐藏分支没有正文或正文证据的存储位置，不能靠 UI 忽略 rawText 来遮罩。
enum DiaryQueryPresentation: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case publicText(text: String, bodyEvidence: [ContentQueryMatchEvidence])
    case hiddenTitle(String)

    var description: String { "DiaryQueryPresentation(redacted)" }
    var debugDescription: String { description }
}

struct DiaryQueryMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let dayKey: String
    let createdAt: Date
    let isPinned: Bool
    let tags: [DiaryQueryTag]
    let presentation: DiaryQueryPresentation
    /// 仅元数据依据；tags 的范围指向同 relatedObject 的原始 name。
    let metadataEvidence: [ContentQueryMatchEvidence]

    init(diary: DiarySnapshot, metadata: DiaryQueryMetadata, evidence: [ContentQueryMatchEvidence],
         session: ContentQuerySession, locale: Locale) {
        id = .init(type: .diary, id: diary.id)
        dayKey = diary.dayKey
        createdAt = diary.createdAt
        isPinned = diary.isPinned
        tags = TagIDList.normalized(TagIDList.parse(diary.tagIDs)).map { .init(id: $0, name: metadata.tagNames?[$0]) }
        let canPublish = DiaryQueryPrivacy(diary: diary, metadata: metadata).canPublishBody
        let textIDs = Set(session.conditions.filter { $0.value.dimension == .content(.text) }.map(\.id))
        // 文字排除项的 tags absence 也依赖正文；隐藏结果连同该条件的全部依据一起丢弃。
        metadataEvidence = evidence.filter { $0.field != .diaryBody && (canPublish || !textIDs.contains($0.conditionID)) }
        presentation = canPublish
            ? .publicText(text: diary.text, bodyEvidence: evidence.filter { $0.field == .diaryBody })
            : .hiddenTitle(L10n.string("diary.private.title", locale: locale))
    }

    var description: String { "DiaryQueryMatch(redacted)" }
    var debugDescription: String { description }
}

struct DiaryQueryResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let queryIsValid: Bool
    let typeAnalysis: ContentQueryTypeAnalysis
    var state: TodoQueryReadState
    let coverage: DiaryQueryCoverage
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    var diagnostics: [DiaryQueryDiagnostic] = []
    var matches: [DiaryQueryMatch] = []
    var undeterminedObjects: [CommandObjectReference] = []

    var isCompleteForCoveredTypes: Bool {
        state == .evaluated && undeterminedObjects.isEmpty && !diagnostics.contains { $0.affectsDetermination }
    }
    var description: String { "DiaryQueryResponse(redacted)" }
    var debugDescription: String { description }
}
