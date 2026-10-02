import Foundation

enum ClipboardQueryIssue: Equatable {
    case invalidQuery, invalidDateContext, invalidRegex, unsupportedCondition
    case recordsNotProvided, recordsPartial, recordsReadFailed
    case duplicateRecordID, invalidCopiedAt, invalidPinnedAt, invalidImageReference
}

/// 不接收 Error.localizedDescription 或输入字符串，避免诊断回显正文/路径/正则。
struct ClipboardQueryDiagnostic: Equatable {
    let issue: ClipboardQueryIssue
    var severity: TodoQuerySeverity = .error
    var affectsDetermination = true
    var conditionIDs: [ContentQueryConditionID] = []
    var object: CommandObjectReference?
    var inputIndices: [Int] = []
}

enum ClipboardQueryImagePayload: Equatable { case none, reference, invalidReference }

/// 只表明有哪些载荷；没有存储名、路径、字节、可访问 URL 或打开能力。
struct ClipboardQueryPayload: Equatable {
    let hasPlainText: Bool
    let hasHTML: Bool
    let hasRTF: Bool
    let hasFiles: Bool
    let image: ClipboardQueryImagePayload

    init(_ record: ClipboardHistoryRecord) {
        hasPlainText = !record.plainText.isEmpty
        hasHTML = record.html != nil
        hasRTF = record.rtf != nil
        hasFiles = !record.filePaths.isEmpty
        // 与 ClipboardHistoryStore.imageData(named:) 的字符串门槛一致；不进行文件 IO。
        if let name = record.imageFile {
            image = !name.isEmpty && !name.contains("/") ? .reference : .invalidReference
        } else { image = .none }
    }
}

/// 范围始终指向 Match.plainText 全文 UTF-16；显式模式没有伪造统一条件 ID。
struct ClipboardQueryModeEvidence: Equatable {
    let field: ContentQueryMatchField = .clipboardPlainText
    let mode: ClipboardSearchMode
    let ranges: [NSRange]
}

struct ClipboardQueryMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let plainText: String
    let copiedAt: Date
    let pinnedAt: Date?
    let pinKey: String?
    let sourceBundleID: String
    let payload: ClipboardQueryPayload
    let mode: ClipboardQueryMode
    let evidence: [ContentQueryMatchEvidence]
    let modeEvidence: ClipboardQueryModeEvidence?

    var isPinned: Bool { pinnedAt != nil }
    var description: String { "ClipboardQueryMatch(redacted)" }
    var debugDescription: String { description }
}

struct ClipboardQueryCoverage: Equatable {
    let providerTypes: Set<CommandObjectType> = [.clipboardEntry]
    let requestedTypes: Set<CommandObjectType>
    let coveredTypes: Set<CommandObjectType>
    let records: ClipboardQueryReadCoverage
    /// 非 clipboard、无效查询等在读取注入数组前退出；范围声明不意味着已评估数据。
    var didEvaluateRecords = false
    var isPartialTypeCoverage: Bool { !requestedTypes.isSubset(of: coveredTypes) }
}

enum ClipboardQuerySortBasis: Equatable { case inputOrder }

struct ClipboardQueryOrdering: Equatable {
    let requested: ClipboardQuerySortBasis = .inputOrder
    let applied: ClipboardQuerySortBasis = .inputOrder
    /// 仅表示已知子集有序；未读完整/隔离对象时不能声称完整结果顺序。
    var isComplete = false
}

struct ClipboardQueryResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let mode: ClipboardQueryMode
    var queryIsValid: Bool
    let typeAnalysis: ContentQueryTypeAnalysis
    var state: TodoQueryReadState
    var coverage: ClipboardQueryCoverage
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    var ordering = ClipboardQueryOrdering()
    var diagnostics: [ClipboardQueryDiagnostic] = []
    var matches: [ClipboardQueryMatch] = []
    var undeterminedObjects: [CommandObjectReference] = []

    var isCompleteForCoveredTypes: Bool {
        state == .evaluated && coverage.records == .complete && coverage.didEvaluateRecords
            && undeterminedObjects.isEmpty && ordering.isComplete
            && !diagnostics.contains { $0.affectsDetermination }
    }
    var description: String { "ClipboardQueryResponse(redacted)" }
    var debugDescription: String { description }
}
