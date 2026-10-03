import Foundation
import SwiftData

/// 枚举前后核对同一执行域；使用图片适配已有物理行校验，不以 requestID 证明新鲜度。
@MainActor
struct TrashContentQueryCapture {
    let context: ModelContext
    let permit: ContentQueryBodyReadPermit

    func read<Model: PersistentModel, Value: Equatable>(
        _ fetch: () throws -> ContentQueryBatchSource<Model>, project: @escaping (Model) -> Value
    ) throws -> ContentQueryBatchSource<Model> {
        try permit.validate()
        do {
            // 在依赖回调前登记基线，回调中修改/新增行不能被重新盖成初始事实。
            let baseline = try context.fetch(FetchDescriptor<Model>())
            try ImageContentQueryCapture.retain(baseline, context: context, permit: permit, project: project)
            let source = try fetch()
            try permit.validate()
            if let rows = source.values {
                try ImageContentQueryCapture.retain(rows, context: context, permit: permit,
                    complete: source.coverage == .complete, project: project)
            }
            return source
        } catch let error as ContentQueryReadSessionError { throw error }
        catch { try permit.validate(); return .failed }
    }

    static func todo(_ row: TodoItem) -> TodoSnapshot {
        // 不访问 relationship 的活子项视图；子任务始终来自平面独立表。
        .init(id: row.id, title: row.title, isDone: row.isDone, dayKey: row.dayKey, createdAt: row.createdAt,
              remindMinutes: row.remindMinutes, dueMinutes: row.dueMinutes, sortOrder: row.sortOrder,
              deletedAt: row.deletedAt, tagIDs: row.tagIDs, isImportant: row.isImportant,
              isUrgent: row.isUrgent, sourceBundleID: row.sourceBundleID, notes: row.notes, subtasks: [])
    }

    static func tag(_ row: TagItem) -> TagQuerySnapshot {
        .init(id: row.id, name: row.name, sortOrder: row.sortOrder, deletedAt: row.deletedAt,
              isPrivateDiary: row.isPrivateDiary, colorToken: row.colorToken)
    }
}

struct TrashSubtaskStamp: Equatable {
    let id: UUID
    let value: SubtaskSnapshot?
    let parent: PersistentIdentifier?
    @MainActor init(_ row: SubtaskItem) {
        id = row.id; value = row.snapshot; parent = row.todo?.persistentModelID
    }
}

struct TrashDiaryStamp: Equatable {
    let metadata: DiarySnapshot
    let encrypted: Data?
    let vaultID: UUID?
    @MainActor init(_ row: DiaryEntry) {
        metadata = DiaryContentQueryReader.metadataOnly(row)
        encrypted = row.encryptedText; vaultID = row.privacyVaultID
    }
}

extension ContentQueryBatchSource {
    func projecting<Output>(_ transform: (Value) -> Output) -> ContentQueryBatchSource<Output> {
        switch self {
        case .notProvided: .notProvided
        case .failed: .failed
        case .partial(let rows): .partial(rows.map(transform))
        case .complete(let rows): .complete(rows.map(transform))
        }
    }
}
