import Foundation

/// 标签查询的原始只读事实；不是导出契约，不持有实体或关联记录。
struct TagQuerySnapshot: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let name: String
    var sortOrder: Int = 0
    var deletedAt: Date?
    var isPrivateDiary = false
    var colorToken: String = TagColorToken.default.rawValue

    var isDiaryPreset: Bool { DiaryMemoTags.isPresetName(name) }
    var resolvedColorToken: TagColorToken { .resolved(colorToken) }
    var listFacts: TagListFacts { .init(id: id, sortOrder: sortOrder, isDeleted: deletedAt != nil) }
    var description: String { "TagQuerySnapshot(redacted)" }
    var debugDescription: String { description }
}

/// 显式页面视图选项，不承载可编辑的文字/条件副本；默认不采用目录排序。
enum TagQueryView: Equatable {
    case inputOrder
    case catalog(TagListFilter)

    var needsUsage: Bool {
        switch self {
        case .catalog(.frequent), .catalog(.recent), .catalog(.unused): true
        default: false
        }
    }
}

struct TagQueryRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let session: ContentQuerySession
    let tags: [TagQuerySnapshot]
    var usage: TagQueryUsageInput?
    var view: TagQueryView = .inputOrder

    var description: String { "TagQueryRequest(redacted)" }
    var debugDescription: String { description }
}

enum TagQueryIssue: Equatable {
    case invalidQuery, duplicateTagID, unsupportedCondition
    case usageUnavailable, usageIncomplete, duplicateUsageID, negativeUsageCount
    case invalidUsageTimestamp, inconsistentUsageRecord
}

struct TagQueryDiagnostic: Equatable {
    let issue: TagQueryIssue
    var severity: TodoQuerySeverity = .error
    var affectsDetermination = true
    var conditionIDs: [ContentQueryConditionID] = []
    var object: CommandObjectReference?
    var inputIndices: [Int] = []
    var usageIndices: [Int] = []
}

struct TagQueryCoverage: Equatable {
    let providerTypes: Set<CommandObjectType> = [.tag]
    let requestedTypes: Set<CommandObjectType>
    let coveredTypes: Set<CommandObjectType>
    let deletion: ContentQueryDeletionPolicy?
    /// nil 表示未提供使用数据；完整声明仅来自调用方，不证明仓储已完整枚举。
    let usage: TagQueryUsageCoverage?

    var isPartialTypeCoverage: Bool { !requestedTypes.isSubset(of: coveredTypes) }
}

enum TagQuerySortBasis: Equatable {
    case inputOrder, sortOrder, activeCountThenSortOrder, latestCreatedAtThenSortOrder
}

struct TagQueryOrdering: Equatable {
    let requested: TagQuerySortBasis
    var applied: TagQuerySortBasis
    /// false 时只有已知子集有序，或 frequent 因未知计数回退到输入顺序。
    var isComplete = true

    init(view: TagQueryView) {
        switch view {
        case .inputOrder: requested = .inputOrder
        case .catalog(.all), .catalog(.unused): requested = .sortOrder
        case .catalog(.frequent): requested = .activeCountThenSortOrder
        case .catalog(.recent): requested = .latestCreatedAtThenSortOrder
        }
        applied = requested
    }
}

struct TagQueryMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let tag: TagQuerySnapshot
    let evidence: [ContentQueryMatchEvidence]
    /// 只发布完整、合法的单标签统计；部分记录不能冒充准确计数。
    let usage: TagUsageRecord?
    let usageState: TagQueryUsageState

    var id: CommandObjectReference { .init(type: .tag, id: tag.id) }
    var description: String { "TagQueryMatch(redacted)" }
    var debugDescription: String { description }
}

struct TagQueryResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let queryIsValid: Bool
    let typeAnalysis: ContentQueryTypeAnalysis
    var state: TodoQueryReadState
    let coverage: TagQueryCoverage
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    let view: TagQueryView
    var ordering: TagQueryOrdering
    var diagnostics: [TagQueryDiagnostic] = []
    var matches: [TagQueryMatch] = []
    /// 仅表示匹配/视图成员资格未知；排序缺口单独由 ordering 声明。
    var undeterminedObjects: [CommandObjectReference] = []

    var isCompleteForCoveredTypes: Bool {
        state == .evaluated && undeterminedObjects.isEmpty && ordering.isComplete
            && !diagnostics.contains { $0.affectsDetermination }
    }
    var description: String { "TagQueryResponse(redacted)" }
    var debugDescription: String { description }
}
