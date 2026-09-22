import Foundation
import SwiftData

@MainActor
enum DiaryContent {
    static func read(_ entry: DiaryEntry, vault: PrivacyVault? = nil) throws -> String {
        let vault = vault ?? .shared
        if !entry.hasProtectedContent {
            if let context = entry.modelContext {
                let tags = try context.fetch(FetchDescriptor<TagItem>())
                if requiresProtection(tagIDs: entry.tagIDs, tags: tags) { throw PrivacyError.corruptData }
            }
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
        requiresProtection(text: "", tagIDs: Set(TagIDList.parse(tagIDs)), tags: tags)
    }

    static func requiresProtection(text: String, tagIDs: Set<UUID>, tags: [TagItem]) -> Bool {
        let names = Set((TagSyntax.names(in: text) + DiaryMemoTags.autoTagNames(in: text)).map(TagSyntax.normalizedName))
        return tags.contains { tag in
            tag.isPrivateDiary && (tagIDs.contains(tag.id) || names.contains(TagSyntax.normalizedName(tag.name)))
        }
    }

    static func requiresProtection(text: String, tagIDs: Set<UUID>, context: ModelContext) throws -> Bool {
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        return requiresProtection(text: text, tagIDs: tagIDs, tags: tags)
    }
}
