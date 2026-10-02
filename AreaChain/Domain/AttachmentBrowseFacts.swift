import Foundation

/// canBrowse 的最小纯值事实；事实本身不是授权或文件访问证明。
struct AttachmentBrowseFacts {
    let attachmentIsLive: Bool
    let hasPrivacyVault: Bool
    let owner: AttachmentOwnerKey?
    let ownerIsSingleLive: Bool
    let diaryIsSensitive: Bool
}

extension AttachmentAccess {
    static func canBrowse(_ facts: AttachmentBrowseFacts) -> Bool {
        guard facts.attachmentIsLive, !facts.hasPrivacyVault,
              let owner = facts.owner, facts.ownerIsSingleLive else { return false }
        return owner.kind != .diary || !facts.diaryIsSensitive
    }
}
