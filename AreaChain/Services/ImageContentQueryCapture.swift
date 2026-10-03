import Foundation
import SwiftData

/// 每种来源只向 Batch 投影一次；复查重新枚举同一上下文，拒绝插入/删除/重入修改。
/// 这是同步只读比较，不承诺跨上下文事务原子性；复查成本不受领域分页预算限制。
@MainActor
final class ImageContentQueryCapture {
    let context: ModelContext
    let permit: ContentQueryBodyReadPermit
    var diaryRows: [DiaryEntry]?
    var tagRows: [TagItem]?

    init(context: ModelContext, permit: ContentQueryBodyReadPermit) {
        self.context = context; self.permit = permit
    }

    func tasks(_ reads: TaskContentQueryReads) -> TaskContentQueryReads {
        var wrapped = reads
        wrapped.todos = {
            try self.permit.validate()
            let rows = try reads.todos()
            try Self.retain(rows, context: self.context, permit: self.permit) { row in
                var value = row.snapshot
                value.subtasks = []
                return value
            }
            return rows
        }
        wrapped.tags = { ids in
            try self.permit.validate()
            let rows = try reads.tags(ids)
            try Self.retain(rows, context: self.context, permit: self.permit, complete: false, project: TagStamp.init)
            return rows
        }
        return wrapped
    }

    func routines(_ reads: RoutineContentQueryReads) -> RoutineContentQueryReads {
        var wrapped = reads
        wrapped.definitions = {
            try self.permit.validate()
            let rows = try reads.definitions()
            try Self.retain(rows, context: self.context, permit: self.permit) { $0.snapshot }
            return rows
        }
        return wrapped
    }

    func diaries(_ reads: DiaryContentQueryReads) -> DiaryContentQueryReads {
        var wrapped = reads
        wrapped.allDiaries = {
            try self.permit.validate()
            let rows = try reads.allDiaries()
            try Self.retain(rows, context: self.context, permit: self.permit, project: DiaryStamp.init)
            self.diaryRows = rows
            return rows
        }
        return wrapped
    }

    func tags(_ reads: TagContentQueryReads) -> TagContentQueryReads {
        var wrapped = reads
        wrapped.allTags = {
            try self.permit.validate()
            let rows = try reads.allTags()
            try Self.retain(rows, context: self.context, permit: self.permit, project: TagStamp.init)
            self.tagRows = rows
            return rows
        }
        return wrapped
    }

    static func retain<Model: PersistentModel, Value: Equatable>(_ rows: [Model], context: ModelContext,
        permit: ContentQueryBodyReadPermit, complete: Bool = true, project: @escaping (Model) -> Value) throws {
        try permit.validate()
        guard rows.allSatisfy({ $0.modelContext === context }) else { throw ContentQueryReadSessionError.stalePermit }
        // 物理行标识只留在许可内核验；业务重复 UUID 不被去重。初始全表也校验注入范围。
        let baseline = try context.fetch(FetchDescriptor<Model>())
        let values = Dictionary(uniqueKeysWithValues: baseline.map { ($0.persistentModelID, project($0)) })
        let selected = rows.map { ($0.persistentModelID, project($0)) }
        guard selected.allSatisfy({ values[$0.0] == $0.1 }),
              !complete || (selected.count == values.count && Set(selected.map(\.0)).count == values.count)
        else { throw ContentQueryReadSessionError.stalePermit }
        permit.retainFacts {
            let current = try context.fetch(FetchDescriptor<Model>())
            guard current.count == values.count,
                  current.allSatisfy({ values[$0.persistentModelID] == project($0) }) else {
                throw ContentQueryReadSessionError.stalePermit
            }
        }
        try permit.validate()
    }
}

private struct DiaryStamp: Equatable {
    let metadata: DiarySnapshot
    let encrypted: Data?
    let vaultID: UUID?
    @MainActor init(_ row: DiaryEntry) {
        metadata = DiaryContentQueryReader.metadataOnly(row)
        encrypted = row.encryptedText; vaultID = row.privacyVaultID
    }
}

private struct TagStamp: Equatable {
    let id: UUID
    let name: String
    let isPrivate: Bool
    let deletedAt: Date?
    init(_ row: TagItem) {
        id = row.id; name = row.name; isPrivate = row.isPrivateDiary; deletedAt = row.deletedAt
    }
}
