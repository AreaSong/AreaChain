import Foundation

/// 调用方声明嵌套快照是否完整；默认空数组本身不能证明已读取子任务。
enum TodoQuerySubtaskData: Equatable { case unavailable, includedInSnapshots }

/// 同步只读请求。requestID 由调用方关联本次快照与会话；不是数据库版本或操作授权。
struct TodoQueryRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let session: ContentQuerySession
    let todos: [TodoSnapshot]
    let tagNames: [UUID: String]?
    let subtaskData: TodoQuerySubtaskData

    var description: String { "TodoQueryRequest(redacted)" }
    var debugDescription: String { description }
}

enum TodoQueryReadState: Equatable { case invalidQuery, notApplicable, unsatisfiable, inapplicableConditions, requiresInput, blocked, evaluated }

/// 类型覆盖与记录完整性分开：todo 的零命中不代表全局零命中。
struct TodoQueryCoverage: Equatable {
    let providerTypes: Set<CommandObjectType> = [.todo]
    let requestedTypes: Set<CommandObjectType>
    let coveredTypes: Set<CommandObjectType>
    let deletion: ContentQueryDeletionPolicy?

    var isPartialTypeCoverage: Bool { !requestedTypes.isSubset(of: coveredTypes) }
}

enum TodoQueryIssue: Equatable {
    case invalidQuery, ambiguousConditionIDs, invalidDateContext
    case missingTagNames, missingAssociatedTagName(UUID), missingSubtasks
    case imageAssociationUnavailable, unsupportedCondition, unsupportedAgendaDate, inapplicableCondition
    case duplicateTodoID, invalidScheduledDay, invalidCreatedAt
    case duplicateSubtaskID, invalidSubtaskOwner
}

/// 不带查询原文、标签名、标题或备注；下标仅指本次请求，不用来恢复可操作身份。
struct TodoQueryDiagnostic: Equatable {
    let issue: TodoQueryIssue
    var conditionIDs: [ContentQueryConditionID] = []
    var object: CommandObjectReference?
    var inputIndices: [Int] = []
}

enum ContentQueryMatchField: Equatable {
    case title, notes, tags, subtaskTags, completion, priority, reminder
    case scheduledDay, createdAt, sourceApplication, objectType, scope
    case parentPriority, parentScheduledDay, parentCompletion, parentReminder, parentSourceApplication, parentItemKind
}

enum ContentQueryMatchKind: Equatable {
    case positive
    /// 只证明字段不含该条件；没有正向高亮区间。
    case absence
    /// 既有分类型页面谓词明确不限制当前类型，例如 todo 上的 routineStatus。
    case typeNeutral
}

/// range 指向结果内未经改写的 title/notes；每个适用字段保留首个命中，足供后续片段生成。
/// conditionID / alternativeIndex 必须在同一 requestID 的 session.conditions 内解释。
struct ContentQueryMatchEvidence: Equatable {
    let conditionID: ContentQueryConditionID
    var alternativeIndex: Int?
    let field: ContentQueryMatchField
    var kind: ContentQueryMatchKind = .positive
    var range: NSRange?
    var relatedObject: CommandObjectReference?
}

/// 纯值投影；备注每条结果只保存一次，不随关键词复制，不持有 SwiftData 实体。
struct TodoQueryMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let title: String
    let notes: String
    let dayKey: String
    let createdAt: Date
    let isDone: Bool
    let evidence: [ContentQueryMatchEvidence]

    var description: String { "TodoQueryMatch(redacted)" }
    var debugDescription: String { description }
}

struct TodoQueryResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    /// 仅表示结构有效；不包含静态可满足性或提供者完整性。
    let queryIsValid: Bool
    let typeAnalysis: ContentQueryTypeAnalysis
    var state: TodoQueryReadState
    let coverage: TodoQueryCoverage
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    var diagnostics: [TodoQueryDiagnostic] = []
    /// 只保持输入相对顺序，不是全局排名，也不是最终产品排序。
    var matches: [TodoQueryMatch] = []

    var isCompleteForCoveredTypes: Bool { state == .evaluated && diagnostics.isEmpty }
    var description: String { "TodoQueryResponse(redacted)" }
    var debugDescription: String { description }
}

extension ContentQueryTypeAssessment {
    /// 静态分析已证明的拒绝与能力缺失分离；详细原因（可有多种）始终保留在响应中。
    var readRestriction: TodoQueryReadState? {
        if reasons.contains(where: { $0.issue == .contradiction }) { return .unsatisfiable }
        if reasons.contains(where: { $0.issue == .fieldNotApplicable }) { return .inapplicableConditions }
        if requiresInput { return .requiresInput }
        return nil
    }
}
