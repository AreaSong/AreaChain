import Foundation
import SwiftData

struct AttachmentCleanupError: Error {
    let remainingIDs: Set<UUID>
}

@MainActor
enum AttachmentCleanup {
    /// 清空回收站时，墓碑 `@Query` 看不到仍活着的孤儿附件；按 owner 再拉一次，含活行。
    static func fileIDs(
        listed: [UUID],
        purgedOwners: Set<AttachmentOwnerKey>,
        context: ModelContext
    ) throws -> Set<UUID> {
        var ids = Set(listed)
        var todoIDs = Set<UUID>()
        var routineIDs = Set<UUID>()
        var diaryIDs = Set<UUID>()
        for owner in purgedOwners {
            switch owner.kind {
            case .todo: todoIDs.insert(owner.id)
            case .routine: routineIDs.insert(owner.id)
            case .diary: diaryIDs.insert(owner.id)
            }
        }
        ids.formUnion(try OwnedAttachments.matching(ownerIDs: todoIDs, kind: .todo, in: context).map(\.id))
        ids.formUnion(try OwnedAttachments.matching(ownerIDs: routineIDs, kind: .routine, in: context).map(\.id))
        ids.formUnion(try OwnedAttachments.matching(ownerIDs: diaryIDs, kind: .diary, in: context).map(\.id))
        return ids
    }

    /// 与回收站清空同一顺序：先收集文件 ID，再删父项，再按 id 清文件。收集失败不删父项。
    @discardableResult
    static func emptyListed(
        listedFileIDs: [UUID],
        purgedOwners: Set<AttachmentOwnerKey>,
        context: ModelContext,
        removeParents: (ModelContext) throws -> Void,
        removeFile: (UUID) throws -> Void = { try AttachmentStore.removeFiles([$0]) }
    ) throws -> Bool {
        let ids = try fileIDs(listed: listedFileIDs, purgedOwners: purgedOwners, context: context)
        guard ModelChanges.perform(in: context, { try removeParents(context) }) else { return false }
        ModelChanges.attempt { try purge(ids: ids, context: context, removeFile: removeFile) }
        return true
    }

    /// 删除意图以回收站元数据保留；文件或提交失败都能在下一次清空时重试。
    static func purge(
        ids: Set<UUID>, context: ModelContext,
        removeFile: (UUID) throws -> Void = { try AttachmentStore.removeFiles([$0]) }
    ) throws {
        guard let descriptor = OwnedAttachments.descriptor(ids: ids) else { return }
        let items = try context.fetch(descriptor)
        guard Set(items.map(\.id)).count == items.count else { throw RepositoryError.invalidArgument("附件标识重复") }
        var remaining: Set<UUID> = []
        for item in items {
            do {
                try removeFile(item.storageID ?? item.id)
                if let retired = item.retiredStorageID, retired != item.storageID { try removeFile(retired) }
                context.delete(item)
            } catch {
                remaining.insert(item.id)
            }
        }
        if context.hasChanges { try ModelChanges.commit(context) }
        if !remaining.isEmpty { throw AttachmentCleanupError(remainingIDs: remaining) }
    }
}
