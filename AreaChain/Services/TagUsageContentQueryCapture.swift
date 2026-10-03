import Foundation
import SwiftData

/// 一批实体供统计和已请求的内容投影共同消费；统计专用请求不生成正文/标题快照。
@MainActor
final class TagUsageContentQueryCapture {
    let context: ModelContext
    let permit: ContentQueryBodyReadPermit
    var todos: ContentQueryBatchSource<TodoItem> = .notProvided
    var subtasks: ContentQueryBatchSource<SubtaskItem> = .notProvided
    var routines: ContentQueryBatchSource<DailyRoutine> = .notProvided
    var diaries: ContentQueryBatchSource<DiaryEntry> = .notProvided
    var tags: ContentQueryBatchSource<TagItem> = .notProvided
    var details = TagUsageContentQueryDetails()

    init(context: ModelContext, permit: ContentQueryBodyReadPermit) {
        self.context = context; self.permit = permit
    }

    func load(_ reads: TagUsageContentQueryReads) throws {
        // 依赖调用前已登记元数据基线；重入修改不能成为本次初始事实。
        todos = try capture(.todo, fetch: reads.todos, project: TagUsageTodoStamp.init)
        subtasks = try capture(.subtask, fetch: reads.subtasks, project: TagUsageSubtaskStamp.init)
        routines = try capture(.routine, fetch: reads.routines, project: TagUsageRowStamp.init)
        diaries = try capture(.diary, fetch: reads.diaries, project: TagUsageDiaryStamp.init)
        tags = try capture(.tag, fetch: reads.tags, project: TagUsageTagStamp.init)
        details.usageOrigin = .stored
        try permit.validate()
    }

    private func capture<Model: PersistentModel, Value: Equatable>(
        _ type: CommandObjectType, fetch: () throws -> ContentQueryBatchSource<Model>,
        project: @escaping (Model) -> Value
    ) throws -> ContentQueryBatchSource<Model> {
        try permit.validate()
        let source = try TrashContentQueryCapture(context: context, permit: permit).read(fetch, project: project)
        details.sources[type] = source.coverage
        if source.coverage == .failed { details.issues.insert(.fetchFailed(type)) }
        if source.coverage == .partial || source.coverage == .notProvided { details.issues.insert(.incompleteSource(type)) }
        return source
    }

    /// 原内容读取器需要数组；失败仍由原 reader 映射，不把缺源盖成 complete([])。
    func familyReader() -> TaskFamilyContentQueryReader {
        var tasks = TaskContentQueryReads(context: context)
        tasks.todos = { try self.todos.requiredValues() }
        tasks.subtasks = { try self.subtasks.requiredValues() }
        tasks.tags = { ids in try self.tags.requiredValues().filter { ids.contains($0.id) } }
        var routines = RoutineContentQueryReads(context: context)
        routines.definitions = { try self.routines.requiredValues() }
        var diaries = DiaryContentQueryReads(context: context)
        diaries.allDiaries = { try self.diaries.requiredValues() }
        var tags = TagContentQueryReads(context: context)
        tags.allTags = { try self.tags.requiredValues() }
        return .init(tasks: tasks, routines: routines, tags: tags, diaries: diaries)
    }

    /// 数组接口不表达源覆盖；投影后恢复本次真实状态，不让局部数组被原接口盖成完整。
    func preserveCoverage(in batch: inout ContentQueryBatch) {
        batch.snapshots.todos = batch.snapshots.todos.limited(to: todos.coverage)
        batch.snapshots.subtasks = batch.snapshots.subtasks.limited(to: subtasks.coverage)
        batch.snapshots.routines = batch.snapshots.routines.limited(to: routines.coverage)
        batch.snapshots.diaries = batch.snapshots.diaries.limited(to: diaries.coverage)
        batch.snapshots.tags = batch.snapshots.tags.limited(to: tags.coverage)
        for (type, coverage) in details.sources where coverage != .complete {
            batch.facts.trashCoverage.types[type] = .notProvided
        }
        if tags.coverage != .complete {
            batch.facts.metadata = .init(tagNames: nil, privateTagIDs: nil)
        }
    }
}

private extension ContentQueryBatchSource {
    func requiredValues() throws -> [Value] {
        guard let values else { throw ContentQueryReadSessionError.readFailed }
        return values
    }

    func limited(to source: ContentQuerySourceCoverage) -> Self {
        guard coverage != .notProvided else { return self }
        switch source {
        case .notProvided: return .notProvided
        case .failed: return .failed
        case .partial: return values.map(Self.partial) ?? self
        case .complete: return self
        }
    }
}

struct TagUsageRowStamp: Equatable {
    let id: UUID
    let subject: TagUsageSubject
    let deletedAt: Date?
    init(id: UUID, tagIDs: String, createdAt: Date, deletedAt: Date?) {
        self.id = id; self.deletedAt = deletedAt
        subject = .init(tagIDs: tagIDs, createdAt: createdAt, isDeleted: deletedAt != nil)
    }
    @MainActor init(_ row: TodoItem) { self.init(id: row.id, tagIDs: row.tagIDs, createdAt: row.createdAt, deletedAt: row.deletedAt) }
    @MainActor init(_ row: SubtaskItem) { self.init(id: row.id, tagIDs: row.tagIDs, createdAt: row.createdAt, deletedAt: row.deletedAt) }
    @MainActor init(_ row: DailyRoutine) { self.init(id: row.id, tagIDs: row.tagIDs, createdAt: row.createdAt, deletedAt: row.deletedAt) }
    @MainActor init(_ row: DiaryEntry) { self.init(id: row.id, tagIDs: row.tagIDs, createdAt: row.createdAt, deletedAt: row.deletedAt) }

    // 坏日期也须稳定冻结，留给完整性校验判未知；NaN 的普通相等比较会误报来源变化。
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.subject.tagIDs == rhs.subject.tagIDs
            && lhs.subject.createdAt.timeIntervalSince1970.bitPattern == rhs.subject.createdAt.timeIntervalSince1970.bitPattern
            && lhs.deletedAt?.timeIntervalSince1970.bitPattern == rhs.deletedAt?.timeIntervalSince1970.bitPattern
    }
}

struct TagUsageTagStamp: Equatable {
    let id: UUID
    let name: String
    let sortOrder: Int
    let deletedAt: UInt64?
    let isPrivate: Bool
    let color: String
    @MainActor init(_ model: TagItem) {
        id = model.id; name = model.name; sortOrder = model.sortOrder
        deletedAt = model.deletedAt?.timeIntervalSince1970.bitPattern
        isPrivate = model.isPrivateDiary; color = model.colorToken
    }
}

struct TagUsageTodoStamp: Equatable {
    let row: TagUsageRowStamp
    let children: [PersistentIdentifier]
    @MainActor init(_ model: TodoItem) {
        row = .init(model); children = model.subtasks.map(\.persistentModelID)
    }
}

struct TagUsageSubtaskStamp: Equatable {
    let row: TagUsageRowStamp
    let parent: PersistentIdentifier?
    @MainActor init(_ model: SubtaskItem) {
        row = .init(model); parent = model.todo?.persistentModelID
    }
}

struct TagUsageDiaryStamp: Equatable {
    let row: TagUsageRowStamp
    let protected: Bool
    @MainActor init(_ model: DiaryEntry) {
        row = .init(model); protected = model.hasProtectedContent
    }
}
