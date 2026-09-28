import Foundation

/// 活附件按拥有者分组。失效条件：传入的 `items` 数组变化（含软删、换主）。
struct CatalogAttachmentIndex {
    private let byOwner: [AttachmentOwnerKey: [AttachmentItem]]
    private let byOwnerID: [UUID: [AttachmentItem]]

    init(_ items: [AttachmentItem]) {
        var byOwner: [AttachmentOwnerKey: [AttachmentItem]] = [:]
        var byOwnerID: [UUID: [AttachmentItem]] = [:]
        for item in items where item.deletedAt == nil {
            byOwnerID[item.ownerID, default: []].append(item)
            if let key = item.ownerKey {
                byOwner[key, default: []].append(item)
            }
        }
        for key in byOwner.keys {
            byOwner[key]?.sort { $0.createdAt < $1.createdAt }
        }
        for key in byOwnerID.keys {
            byOwnerID[key]?.sort { $0.createdAt < $1.createdAt }
        }
        self.byOwner = byOwner
        self.byOwnerID = byOwnerID
    }

    func live(ownerID: UUID, ownerKind: AttachmentOwner? = nil) -> [AttachmentItem] {
        if let ownerKind {
            return byOwner[AttachmentOwnerKey(kind: ownerKind, id: ownerID)] ?? []
        }
        return byOwnerID[ownerID] ?? []
    }
}
