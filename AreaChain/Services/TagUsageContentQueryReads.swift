import Foundation
import SwiftData

/// 复用既有全枚举接口；source 包装只表达缺源/部分/失败，不接收预计算统计或正文能力。
@MainActor
struct TagUsageContentQueryReads {
    let context: ModelContext
    var todos: () throws -> ContentQueryBatchSource<TodoItem>
    var subtasks: () throws -> ContentQueryBatchSource<SubtaskItem>
    var routines: () throws -> ContentQueryBatchSource<DailyRoutine>
    var diaries: () throws -> ContentQueryBatchSource<DiaryEntry>
    var tags: () throws -> ContentQueryBatchSource<TagItem>

    init(context: ModelContext) {
        self.context = context
        let tasks = TaskContentQueryReads(context: context)
        let routines = RoutineContentQueryReads(context: context)
        let diaries = DiaryContentQueryReads(context: context)
        let tags = TagContentQueryReads(context: context)
        todos = { .complete(try tasks.todos()) }
        subtasks = { .complete(try tasks.subtasks()) }
        self.routines = { .complete(try routines.definitions()) }
        self.diaries = { .complete(try diaries.allDiaries()) }
        self.tags = { .complete(try tags.allTags()) }
    }

    func read(query: ContentQuerySession, requestID: UUID, observation: RoutineContentQueryObservation,
              options: ContentQueryBatchOptions, permit: ContentQueryBodyReadPermit) throws
        -> (ContentQueryBatch, TagUsageContentQueryDetails) {
        let capture = TagUsageContentQueryCapture(context: context, permit: permit)
        let needsUsage = TagUsageContentQueryPlan.needsUsage(query, options: options)
        if needsUsage { try capture.load(self) }
        let statistics = needsUsage ? capture.statistics(dates: query.queryDates) : nil
        let reader = needsUsage ? capture.familyReader() : TaskFamilyContentQueryReader(context: context, diaryMode: .metadataOnly)
        let result = reader.read(session: query, requestID: requestID, observation: observation,
                                 options: options, storedUsage: statistics)
        var batch = result.batch
        if needsUsage { capture.preserveCoverage(in: &batch) }
        try permit.validate()
        return (batch, statistics?.details ?? .init())
    }
}

enum TagUsageContentQueryPlan {
    static func needsUsage(_ query: ContentQuerySession, options: ContentQueryBatchOptions) -> Bool {
        if case .command = query.input { return false }
        return query.isStructurallyValid && query.composition?.deletion == .liveOnly
            && query.typeAnalysis.possibleTypes.contains(.tag) && options.tagView.needsUsage
    }
}

enum TagUsageContentQueryIssue: Hashable {
    case fetchFailed(CommandObjectType), incompleteSource(CommandObjectType)
    case duplicateIdentity(CommandObjectType), invalidDate(CommandObjectType), invalidTagIDs(CommandObjectType)
    case invalidSubtaskOwnership, invalidTagIdentity
}

/// 只报告来源状态和封闭问题；没有私密贡献数、行下标或关联对象身份。
struct TagUsageContentQueryDetails: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var sources: [CommandObjectType: ContentQuerySourceCoverage] = [:]
    var usageOrigin: TagContentQueryUsageOrigin = .notProvided
    var issues: Set<TagUsageContentQueryIssue> = []
    var description: String { "TagUsageContentQueryDetails(redacted)" }
    var debugDescription: String { description }
}
