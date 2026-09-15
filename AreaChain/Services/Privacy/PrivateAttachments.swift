import Foundation

enum PrivateAttachments {
    static func encode(_ data: Data, attachmentID: UUID, ownerID: UUID,
                       vaultID: UUID, keys: VaultKeyAccess) throws -> Data {
        guard data.count <= VaultCrypto.maximumAttachmentBytes else { throw PrivacyError.tooLarge }
        var envelope = PrivateAttachmentEnvelope(vaultID: vaultID, attachmentID: attachmentID,
                                                 ownerID: ownerID, sealedData: Data())
        envelope.sealedData = try keys.seal(data, vaultID: vaultID, context: envelope.context)
        return VaultCrypto.attachmentMagic + (try JSONEncoder().encode(envelope))
    }

    static func decode(_ data: Data, reference: AttachmentRef, keys: VaultKeyAccess) throws -> Data {
        guard data.starts(with: VaultCrypto.attachmentMagic) else {
            guard reference.privacyVaultID == nil else { throw PrivacyError.corruptData }
            return data
        }
        guard data.count < VaultCrypto.maximumAttachmentBytes * 2 else { throw PrivacyError.corruptData }
        let body = data.dropFirst(VaultCrypto.attachmentMagic.count)
        let envelope = try JSONDecoder().decode(PrivateAttachmentEnvelope.self, from: body)
        guard envelope.version == 1, envelope.attachmentID == reference.id,
              reference.ownerKind == AttachmentOwner.diary.rawValue,
              reference.ownerID == envelope.ownerID,
              reference.privacyVaultID == envelope.vaultID else {
            throw PrivacyError.corruptData
        }
        return try keys.open(envelope.sealedData, vaultID: envelope.vaultID, context: envelope.context)
    }
}
