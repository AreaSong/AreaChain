import Foundation

enum Catalog {
    static func liveProjects(_ items: [ProjectItem]) -> [ProjectItem] {
        items.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func liveTags(_ items: [TagItem]) -> [TagItem] {
        items.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func liveAttachments(for ownerID: UUID, in items: [AttachmentItem]) -> [AttachmentItem] {
        items
            .filter { $0.deletedAt == nil && $0.ownerID == ownerID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func nextSortOrder(_ orders: [Int]) -> Int {
        (orders.max() ?? -1) + 1
    }
}

enum CloudKitAvailability {
    /// 当前 ad-hoc 签名没有 iCloud 容器；真同步以后再改 Persistence。
    static var isConfigured: Bool { false }
}
