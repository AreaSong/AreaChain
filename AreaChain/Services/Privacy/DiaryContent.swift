import Foundation
import SwiftData

@MainActor
enum DiaryContent {
    static func read(_ entry: DiaryEntry, vault: PrivacyVault? = nil) throws -> String {
        let vault = vault ?? .shared
        let tags: [TagItem]
        if !entry.hasProtectedContent, let context = entry.modelContext {
            tags = try context.fetch(FetchDescriptor<TagItem>())
        } else { tags = [] }
        return try readChecked(entry, vault: vault, protectionTags: tags)
    }

    /// 同批目录重载只供搜索门禁持有的许可调用；普通调用方不能传空目录绕过旧检查。
    static func read(_ entry: DiaryEntry, vault: PrivacyVault, protectionTags: [TagItem],
                     permit: ContentQueryBodyReadPermit) throws -> String {
        try permit.validate()
        let text = try readChecked(entry, vault: vault, protectionTags: protectionTags)
        try permit.validate()
        return text
    }

    private static func readChecked(_ entry: DiaryEntry, vault: PrivacyVault, protectionTags: [TagItem]) throws -> String {
        if !entry.hasProtectedContent {
            if requiresProtection(tagIDs: entry.tagIDs, tags: protectionTags) { throw PrivacyError.corruptData }
            return entry.text
        }
        guard vault.isUnlocked else { throw PrivacyError.locked }
        guard let id = entry.privacyVaultID, let encrypted = entry.encryptedText else {
            throw PrivacyError.corruptData
        }
        let data = try vault.keys.open(encrypted, vaultID: id, context: "diary:\(entry.id.uuidString)")
        guard let text = String(data: data, encoding: .utf8) else { throw PrivacyError.corruptData }
        return text
    }

    static func snapshot(_ entry: DiaryEntry, vault: PrivacyVault? = nil) -> DiarySnapshot {
        let vault = vault ?? .shared
        var value = entry.snapshot
        if let text = try? read(entry, vault: vault) {
            value.text = text
            value.isContentAvailable = true
        } else {
            value.text = ""
            value.isPrivate = true
            value.isContentAvailable = false
        }
        return value
    }

    static func write(_ text: String, to entry: DiaryEntry, protect: Bool, vault: PrivacyVault? = nil) throws {
        let vault = vault ?? .shared
        guard protect || entry.hasProtectedContent else {
            entry.text = text
            return
        }
        guard vault.isUnlocked, let config = vault.configuration else { throw PrivacyError.locked }
        let data = try vault.keys.seal(Data(text.utf8), vaultID: config.vaultID, context: "diary:\(entry.id.uuidString)")
        // 从来不把解密正文回填进可自动保存的 SwiftData 属性。
        entry.encryptedText = data
        entry.privacyVaultID = config.vaultID
        DiaryPrivacy.assign(entry, isPrivate: true)
        entry.text = ""
        vault.touch()
    }

    static func requiresProtection(tagIDs: String, tags: [TagItem]) -> Bool {
        DiaryPrivacy.requiresProtection(tagIDs: tagIDs, tags: tags)
    }

    static func requiresProtection(text: String, tagIDs: Set<UUID>, tags: [TagItem]) -> Bool {
        DiaryPrivacy.requiresProtection(text: text, tagIDs: tagIDs, tags: tags)
    }

    static func requiresProtection(text: String, tagIDs: Set<UUID>, context: ModelContext) throws -> Bool {
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        return DiaryPrivacy.requiresProtection(text: text, tagIDs: tagIDs, tags: tags)
    }
}
