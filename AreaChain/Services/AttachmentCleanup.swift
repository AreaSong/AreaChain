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
        store: AttachmentStore = .shared,
        root: URL? = nil,
        removeFile: ((UUID) throws -> Void)? = nil
    ) throws -> Bool {
        let ids = try fileIDs(listed: listedFileIDs, purgedOwners: purgedOwners, context: context)
        guard ModelChanges.perform(in: context, { try removeParents(context) }) else { return false }
        ModelChanges.attempt { try purge(ids: ids, context: context, store: store, root: root, removeFile: removeFile) }
        return true
    }

    /// 删除意图以回收站元数据保留；文件或提交失败都能在下一次清空时重试。
    /// `store`／`root` 同时决定删除位置与“仍在未关联池中”的保留集合：两者必须来自同一目录，
    /// 否则隔离宿主会按共享池判断保留、却删自己目录的文件（§9.102 M-5G）。默认值即生产的共享目录。
    static func purge(
        ids: Set<UUID>, context: ModelContext,
        store: AttachmentStore = .shared,
        root: URL? = nil,
        removeFile: ((UUID) throws -> Void)? = nil
    ) throws {
        let removeFile = removeFile ?? { try store.removeFiles([$0], root: root) }
        guard let descriptor = OwnedAttachments.descriptor(ids: ids) else { return }
        let items = try context.fetch(descriptor)
        guard Set(items.map(\.id)).count == items.count else { throw RepositoryError.invalidArgument("附件标识重复") }
        let allRows = (try? OwnedAttachments.all(in: context)) ?? []
        var retainedStorageIDs = Set(
            allRows.filter { !ids.contains($0.id) }.map { $0.storageID ?? $0.id }
        )
        retainedStorageIDs.formUnion(AttachmentPoolStore.unlinkedItems(store: store, root: root).map(\.id))
        var remaining: Set<UUID> = []
        for item in items {
            do {
                let canonicalID = item.storageID ?? item.id
                if !retainedStorageIDs.contains(canonicalID) {
                    try removeFile(canonicalID)
                }
                if let retired = item.retiredStorageID, retired != item.storageID, !retainedStorageIDs.contains(retired) {
                    try removeFile(retired)
                }
                context.delete(item)
            } catch {
                remaining.insert(item.id)
            }
        }
        if context.hasChanges { try ModelChanges.commit(context) }
        if !remaining.isEmpty { throw AttachmentCleanupError(remainingIDs: remaining) }
    }
}
