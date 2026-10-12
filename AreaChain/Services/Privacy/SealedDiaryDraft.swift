import Foundation

struct DiaryDraftText: Codable, Equatable {
    var title: String = ""
    var text: String
    var baselineTitle: String = ""
    var baseline: String
}

struct SealedDiaryDraft {
    var data: Data
    var vaultID: UUID
    var id: UUID
    var isDirty: Bool

    @MainActor static func seal(
        text: String, baseline: String, title: String = "", baselineTitle: String = "",
        id: UUID, vault: PrivacyVault
    ) throws -> Self {
        guard let vaultID = vault.configuration?.vaultID else { throw PrivacyError.notConfigured }
        let payload = DiaryDraftText(title: title, text: text, baselineTitle: baselineTitle, baseline: baseline)
        let raw = try JSONEncoder().encode(payload)
        let data = try vault.keys.seal(raw, vaultID: vaultID, context: "draft:\(id.uuidString)")
        return Self(data: data, vaultID: vaultID, id: id, isDirty: title != baselineTitle || text != baseline)
    }

    @MainActor func open(vault: PrivacyVault) throws -> DiaryDraftText {
        let raw = try vault.keys.open(data, vaultID: vaultID, context: "draft:\(id.uuidString)")
        return try JSONDecoder().decode(DiaryDraftText.self, from: raw)
    }
}
