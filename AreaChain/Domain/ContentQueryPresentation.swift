import Foundation

/// UTF-16 技术预算不代表原生行数、分页或产品规模；所有工作只针对已发布证据。
struct ContentQueryPresentationBudget: Equatable {
    var maxUTF16 = 160
    var contextUTF16 = 24
    var maxEvidence = 128
    var maxCandidates = 64
    var isValid: Bool {
        maxUTF16 > 0 && maxUTF16 <= 16_384 && contextUTF16 >= 0 && contextUTF16 <= maxUTF16
            && maxEvidence > 0 && maxEvidence <= 4_096 && maxCandidates > 0 && maxCandidates <= 256
    }
}

enum ContentQueryPresentationIssue: Equatable {
    case missingIdentity, ambiguousIdentity, duplicateOrderIdentity, unorderedSourceIdentity
    case invalidBudget, invalidCondition, invalidBranch, invalidField, invalidRelation, invalidRange, staleEvidence
    case evidenceLimit, candidateLimit, noPublicTextEvidence, metadataOnlySummaryOmitted
    case explicitModeMismatch, zeroLengthModeMatch, noLegalModeRange, graphemeExceedsBudget, hitExceedsBudget
}

/// 诊断只记录类别，不回显字符串、错误内容、隐藏正文范围或长度。
struct ContentQueryPresentationDiagnostic: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let issue: ContentQueryPresentationIssue
    var description: String { "ContentQueryPresentationDiagnostic(redacted)" }
    var debugDescription: String { description }
}

enum ContentQueryHighlightSource: Equatable {
    case condition(ContentQueryConditionID, alternative: Int)
    case clipboardMode(ClipboardSearchMode)
}

struct ContentQueryHighlight: Equatable {
    let range: NSRange
    let originalRange: NSRange
    let sources: [ContentQueryHighlightSource]
    let contributions: [ContentQueryHighlightContribution]
}

/// 合并外观范围时仍保留每个条件实际覆盖的子区间。
struct ContentQueryHighlightContribution: Equatable {
    let range: NSRange
    let originalRange: NSRange
    let source: ContentQueryHighlightSource
}

/// 一段未改写的原文字素；省略号不在映射中，也不属于命中。
struct ContentQueryTextMapping: Equatable {
    let originalRange: NSRange
    let range: NSRange
}

struct ContentQueryDisplayText: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let text: String
    let field: ContentQueryMatchField?
    let mapping: ContentQueryTextMapping?
    let highlights: [ContentQueryHighlight]
    let omittedPublicContent: Bool
    var description: String { "ContentQueryDisplayText(redacted)" }
    var debugDescription: String { description }
}

/// 字段和关联引用是结构化说明，名称不可用时不回查，也不复制查询参数。
struct ContentQueryPresentationReason: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let conditionID: ContentQueryConditionID
    let alternativeIndex: Int?
    let field: ContentQueryMatchField
    let kind: ContentQueryMatchKind
    let relatedObject: CommandObjectReference?
    let ownerObject: CommandObjectReference?
    var description: String { "ContentQueryPresentationReason(redacted)" }
    var debugDescription: String { description }
}

struct ContentQueryPresentationRelation: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum Role: Equatable { case parentTask, imageOwner, routine }
    let role: Role
    let object: CommandObjectReference
    let title: String?
    var description: String { "ContentQueryPresentationRelation(redacted)" }
    var debugDescription: String { description }
}

enum ContentQueryPresentationMetadata: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case day(field: ContentQueryMatchField, key: String)
    case completion(Bool), enabled(Bool), pinned(Bool), occurrenceStatus(ContentQueryStatus)
    case tags([DiaryQueryTag]), tagColor(TagColorToken), tagUsage(TagQueryUsageState, TagQueryUsageSummary?)
    case deleted(Date, TrashDeletionRelation)
    var description: String { "ContentQueryPresentationMetadata(redacted)" }
    var debugDescription: String { description }
}

/// 仅指向同一 response.source 中的公开字段；没有实体、文件、权限或执行闭包。
struct ContentQueryExpansionReference: Equatable {
    let object: CommandObjectReference
    let field: ContentQueryMatchField
}

struct ContentQueryPresentationRow: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    var primary: ContentQueryDisplayText?
    var summary: ContentQueryDisplayText?
    var reasons: [ContentQueryPresentationReason] = []
    var relations: [ContentQueryPresentationRelation] = []
    var metadata: [ContentQueryPresentationMetadata] = []
    var expansion: [ContentQueryExpansionReference] = []
    var diagnostics: [ContentQueryPresentationDiagnostic] = []
    var omittedPublicContent = false
    var canRequestExpansion: Bool { !expansion.isEmpty }
    var lineLimit: Int { 2 }
    var treatsContentAsPlainText: Bool { true }
    var description: String { "ContentQueryPresentationRow(redacted)" }
    var debugDescription: String { description }
}

/// 只在响应顶层保留一次来源，行内不持有整个批次；异常身份仍占原 ordered 的位置。
struct ContentQueryPresentationResponse: CustomStringConvertible, CustomDebugStringConvertible {
    let source: ContentQuerySortedResponse
    let locale: Locale
    let rows: [ContentQueryPresentationRow]
    let diagnostics: [ContentQueryPresentationDiagnostic]
    var description: String { "ContentQueryPresentationResponse(redacted)" }
    var debugDescription: String { description }
}
