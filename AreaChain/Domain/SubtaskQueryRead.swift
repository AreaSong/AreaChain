import Foundation

/// 所有父项与嵌套子任务均为调用方注入值；includedInSnapshots 声明完整读取，空数组不自行作此声明。
struct SubtaskQueryRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let session: ContentQuerySession
    let todos: [TodoSnapshot]
    let tagNames: [UUID: String]?
    let subtaskData: TodoQuerySubtaskData

    var description: String { "SubtaskQueryRequest(redacted)" }
    var debugDescription: String { description }
}

struct SubtaskQueryCoverage: Equatable {
    let providerTypes: Set<CommandObjectType> = [.subtask]
    let requestedTypes: Set<CommandObjectType>
    let coveredTypes: Set<CommandObjectType>
    let deletion: ContentQueryDeletionPolicy?

    var isPartialTypeCoverage: Bool { !requestedTypes.isSubset(of: coveredTypes) }
}

/// 只定位本请求的输入位置；重复身份不能从这些下标恢复成可操作对象。
struct SubtaskQueryInputPosition: Equatable {
    let parentIndex: Int
    var subtaskIndex: Int?
}

struct SubtaskQueryDiagnostic: Equatable {
    let issue: TodoQueryIssue
    var conditionIDs: [ContentQueryConditionID] = []
    var object: CommandObjectReference?
    var inputPositions: [SubtaskQueryInputPosition] = []
}

/// 子任务身份始终为自身 UUID；父标题只供所属关系展示，不作为自身文字命中。
struct SubtaskQueryMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let title: String
    let isDone: Bool
    let createdAt: Date
    let parent: CommandObjectReference
    let parentTitle: String
    let parentScheduledDay: String
    let evidence: [ContentQueryMatchEvidence]

    var description: String { "SubtaskQueryMatch(redacted)" }
    var debugDescription: String { description }
}

struct SubtaskQueryResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    /// 仅表示结构有效；其余状态由 typeAnalysis / state / diagnostics 分别表达。
    let queryIsValid: Bool
    let typeAnalysis: ContentQueryTypeAnalysis
    var state: TodoQueryReadState
    let coverage: SubtaskQueryCoverage
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    var diagnostics: [SubtaskQueryDiagnostic] = []
    /// 保留父输入顺序和嵌套输入顺序，不按 sortOrder 或相关性重排。
    var matches: [SubtaskQueryMatch] = []

    var isCompleteForCoveredTypes: Bool { state == .evaluated && diagnostics.isEmpty }
    var description: String { "SubtaskQueryResponse(redacted)" }
    var debugDescription: String { description }
}
