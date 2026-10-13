import Foundation
import SwiftData

/// 标签色支持预设语义令牌与规范化 #RRGGBB 十六进制色值，颜色映射在 Theme，不持久化平台颜色对象。
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

    static func normalizedHex(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard body.allSatisfy(\.isHexDigit) else { return nil }
        if body.count == 3 {
            let expanded = body.map { "\($0)\($0)" }.joined()
            return "#" + expanded.uppercased()
        }
        guard body.count == 6 else { return nil }
        return "#" + body.uppercased()
    }

    static func resolvedToken(_ raw: String) -> String {
        if let preset = TagColorToken(rawValue: raw) { return preset.rawValue }
        if let hex = normalizedHex(raw) { return hex }
        return Self.default.rawValue
    }

    static func rgbComponents(of raw: String) -> (red: Double, green: Double, blue: Double)? {
        guard let hex = normalizedHex(raw),
              let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return (r, g, b)
    }

    static func hexString(red: Double, green: Double, blue: Double) -> String {
        let r = Int((min(max(red, 0), 1) * 255).rounded())
        let g = Int((min(max(green, 0), 1) * 255).rounded())
        let b = Int((min(max(blue, 0), 1) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct CustomTagColor: Codable, Equatable, Identifiable, Sendable {
    var hex: String
    var name: String

    var id: String { hex }

    var displayTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? hex : trimmed
    }

    init?(hex: String, name: String = "") {
        guard let normalized = TagColorToken.normalizedHex(hex) else { return nil }
        self.hex = normalized
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
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
        false
    }

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        deletedAt: Date? = nil,
        colorToken: String = TagColorToken.default.rawValue,
        isPrivateDiary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.deletedAt = deletedAt
        self.colorToken = TagColorToken.resolvedToken(colorToken)
        self.isPrivateDiary = isPrivateDiary
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
