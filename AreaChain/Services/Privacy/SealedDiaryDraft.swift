import Foundation

struct DiaryDraftText: Codable, Equatable {
    var text: String
    var baseline: String
}

struct SealedDiaryDraft {
    var data: Data
    var vaultID: UUID
    var id: UUID
    var isDirty: Bool

    @MainActor static func seal(text: String, baseline: String, id: UUID, vault: PrivacyVault) throws -> Self {
        guard let vaultID = vault.configuration?.vaultID else { throw PrivacyError.notConfigured }
        let raw = try JSONEncoder().encode(DiaryDraftText(text: text, baseline: baseline))
        let data = try vault.keys.seal(raw, vaultID: vaultID, context: "draft:\(id.uuidString)")
        return Self(data: data, vaultID: vaultID, id: id, isDirty: text != baseline)
    }

    @MainActor func open(vault: PrivacyVault) throws -> DiaryDraftText {
        let raw = try vault.keys.open(data, vaultID: vaultID, context: "draft:\(id.uuidString)")
        return try JSONDecoder().decode(DiaryDraftText.self, from: raw)
    }
}
