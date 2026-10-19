import Foundation
import SwiftData

/// 解析输入文本中的 `@附件名` 引用，将公开附件或未关联附件池中的物理附件关联到目标宿主。
@MainActor
enum InputAttachmentResolver {
    static func linkIfPresent(
        in text: String,
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        store: AttachmentStore = .shared,
        root: URL? = nil
    ) {
        for match in matches(in: text, ownerKind: ownerKind, ownerID: ownerID, context: context, store: store, root: root) {
            let item = AttachmentItem(
                ownerKind: ownerKind.rawValue,
                ownerID: ownerID,
                filename: match.filename
            )
            item.storageID = match.storageID
            context.insert(item)
            if match.isInUnlinkedPool {
                for id in match.allStorageIDs {
                    AttachmentPoolStore.removeUnlinkedEntry(id: id, store: store, root: root)
                }
            }
        }
    }

    /// 只读：`linkIfPresent` 将要关联的附件（按引用顺序、已关联到同一宿主的物理附件跳过）。不插入对象、不动附件池。
    static func matches(
        in text: String,
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        store: AttachmentStore = .shared,
        root: URL? = nil
    ) -> [AttachmentLibraryItem] {
        let names = AttachmentSyntax.names(in: text)
        guard !names.isEmpty else { return [] }
        if ownerKind == .diary {
            guard let diaries = try? AttachmentAccess.fetchDiaries(id: ownerID, in: context),
                  diaries.count == 1, let entry = diaries.first,
                  entry.deletedAt == nil, !entry.hasProtectedContent else {
                return []
            }
        }
        let allLive = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments))) ?? []
        let tags = (try? context.fetch(FetchDescriptor<TagItem>())) ?? []
        let owners = (try? AttachmentAccess.ownerIndex(context: context, keys: allLive.compactMap(\.ownerKey))) ?? .empty
        let unlinked = AttachmentPoolStore.unlinkedItems(store: store, root: root)
        let storageIDs = allLive.map { $0.storageID ?? $0.id } + unlinked.map(\.id)
        let hashes = AttachmentPoolStore.contentHashes(for: storageIDs, store: store, root: root)
        let library = AttachmentLibraryProjection.build(
            attachments: allLive,
            unlinked: unlinked,
            owners: owners,
            tags: tags,
            contentHashes: hashes
        )

        var existingStorageIDs = Set(
            allLive
                .filter { $0.ownerKind == ownerKind.rawValue && $0.ownerID == ownerID }
                .map { $0.storageID ?? $0.id }
        )

        var result: [AttachmentLibraryItem] = []
        for name in names {
            let key = AttachmentSyntax.normalizedName(name)
            guard let match = resolveMatch(forNormalizedKey: key, library: library) else {
                continue
            }
            guard existingStorageIDs.insert(match.storageID).inserted else { continue }
            result.append(match)
        }
        return result
    }

    private static func resolveMatch(
        forNormalizedKey key: String,
        library: [AttachmentLibraryItem]
    ) -> AttachmentLibraryItem? {
        library.first { AttachmentSyntax.normalizedName($0.filename) == key }
    }
}
