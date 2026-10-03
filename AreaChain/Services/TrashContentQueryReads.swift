import Foundation
import SwiftData

/// 只接受当前上下文的模型枚举；没有文件、写入或外部正文 Batch 能力。
@MainActor
struct TrashContentQueryReads {
    let bodies: ContentQueryBodyReads
    var todos: () throws -> ContentQueryBatchSource<TodoItem>
    var subtasks: () throws -> ContentQueryBatchSource<SubtaskItem>
    var routines: () throws -> ContentQueryBatchSource<DailyRoutine>
    var diaries: () throws -> ContentQueryBatchSource<DiaryEntry>
    var tags: () throws -> ContentQueryBatchSource<TagItem>
    var images: () throws -> ContentQueryBatchSource<AttachmentItem>
    var history: RoutineContentQueryReads

    init(context: ModelContext, bodies: ContentQueryBodyReads? = nil) {
        let bodies = bodies ?? ContentQueryBodyReads(context: context)
        self.bodies = bodies
        let tasks = TaskContentQueryReads(context: context)
        let routines = RoutineContentQueryReads(context: context)
        let images = ImageContentQueryReads(context: context, bodies: bodies)
        todos = { .complete(try tasks.todos()) }
        subtasks = { .complete(try tasks.subtasks()) }
        self.routines = { .complete(try routines.definitions()) }
        diaries = { .complete(try bodies.diaries.allDiaries()) }
        tags = { .complete(try bodies.tags.allTags()) }
        self.images = images.attachments
        history = routines
    }
}

enum TrashContentQueryIssue: Equatable {
    case fetchFailed(CommandObjectType), incompleteRows(CommandObjectType)
    case unconvertibleSubtask, invalidSubtaskParent, tagNamesIncomplete, protectionIncomplete
}

/// 不含行下标、原始数据库错误、文件名或隐藏图片数量。
struct TrashContentQueryReadDetails: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var sources: [CommandObjectType: ContentQuerySourceCoverage] = [:]
    var tagNames: ContentQuerySourceCoverage = .notProvided
    var issues: Set<TrashContentQueryIssue> = []
    var description: String { "TrashContentQueryReadDetails(redacted)" }
    var debugDescription: String { description }
}

extension TrashContentQueryIssue: Hashable {}

enum TrashContentQueryPlan {
    static func types(_ query: ContentQuerySession) -> Set<CommandObjectType> {
        guard query.isStructurallyValid, query.scope == .catalog(.trash),
              Set(query.conditions.map(\.id)).count == query.conditions.count,
              query.composition?.deletion == .deletedOnly else { return [] }
        if case .command = query.input { return [] }
        let needed = ContentQueryBatchAssembly.trashInputTypes(query)
        // 同批全目录还用于旧正文中的标签名字保护检查，不能只取已关联的 ID。
        return needed.isEmpty ? [] : needed.union([.tag])
    }
}
