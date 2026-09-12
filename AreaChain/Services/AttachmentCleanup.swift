import Foundation
import SwiftData

struct AttachmentCleanupError: Error {
    let remainingIDs: Set<UUID>
}

@MainActor
enum AttachmentCleanup {
    /// 删除意图以回收站元数据保留；文件或提交失败都能在下一次清空时重试。
    static func purge(
        ids: Set<UUID>, context: ModelContext,
        removeFile: (UUID) throws -> Void = { try AttachmentStore.removeFiles([$0]) }
    ) throws {
        let items = try context.fetch(FetchDescriptor<AttachmentItem>()).filter { ids.contains($0.id) }
        guard Set(items.map(\.id)).count == items.count else { throw RepositoryError.invalidArgument("附件标识重复") }
        var remaining: Set<UUID> = []
        for item in items {
            do {
                try removeFile(item.id)
                context.delete(item)
            } catch {
                remaining.insert(item.id)
            }
        }
        if context.hasChanges { try ModelChanges.commit(context) }
        if !remaining.isEmpty { throw AttachmentCleanupError(remainingIDs: remaining) }
    }
}
