import Foundation
import SwiftData

/// 标签色只存稳定标识，颜色映射在 Theme，不持久化平台颜色对象。
enum TagColorToken: String, CaseIterable, Codable, Sendable, Equatable {
    case moss
    case stamp
    case ink
    case clay
    case amber
    case slate

    static let `default` = TagColorToken.moss

    static func resolved(_ raw: String) -> TagColorToken {
        TagColorToken(rawValue: raw) ?? .default
    }
}

@Model
final class TagItem {
    var id: UUID
    var name: String
    var sortOrder: Int
    var deletedAt: Date?
    var isPrivateDiary: Bool = false
    var colorToken: String = TagColorToken.default.rawValue

    var resolvedColorToken: TagColorToken {
        TagColorToken.resolved(colorToken)
    }

    var isDiaryPreset: Bool {
        DiaryMemoTags.isPresetName(name)
    }

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        deletedAt: Date? = nil,
        colorToken: String = TagColorToken.default.rawValue
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.deletedAt = deletedAt
        self.colorToken = TagColorToken.resolved(colorToken).rawValue
    }
}

@Model
final class AttachmentItem {
    var id: UUID
    var ownerKind: String
    var ownerID: UUID
    var filename: String
    var createdAt: Date
    var deletedAt: Date?
    var storageID: UUID? = nil
    var privacyVaultID: UUID? = nil
    var retiredStorageID: UUID? = nil

    var reference: AttachmentRef {
        AttachmentRef(id: id, filename: filename, storageID: storageID,
                      privacyVaultID: privacyVaultID, ownerID: privacyVaultID == nil ? nil : ownerID,
                      ownerKind: privacyVaultID == nil ? nil : ownerKind)
    }

    var ownerKey: AttachmentOwnerKey? {
        AttachmentOwner(rawValue: ownerKind).map { AttachmentOwnerKey(kind: $0, id: ownerID) }
    }

    init(
        id: UUID = UUID(),
        ownerKind: String,
        ownerID: UUID,
        filename: String,
        createdAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.ownerKind = ownerKind
        self.ownerID = ownerID
        self.filename = filename
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}
