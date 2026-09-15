import Foundation

enum PrivacyError: String, Error, LocalizedError {
    case locked, notConfigured, busy, cancelled, wrongPassword, weakPassword
    case corruptData, unsupportedVersion, systemUnavailable, lastMethod
    case storageFailure, privateImport, missingAttachment, requiresBackup, staleOperation, tooLarge
    case systemCleanupPending

    var messageKey: String { "privacy.error." + rawValue }
    var errorDescription: String? {
        L10n.string(String.LocalizationValue(stringLiteral: messageKey), locale: .current)
    }
}

struct PasswordKeySlot: Codable, Equatable, Sendable {
    var salt: Data
    var iterations: Int
    var wrappedKey: Data
}

/// 只保存密钥的加密封装；系统密码、主密码和解密后的数据密钥均不落盘。
struct PrivacyConfiguration: Codable, Equatable, Sendable {
    var version = 1
    var vaultID: UUID
    var passwordSlot: PasswordKeySlot?
    var systemKeyID: UUID?
    var verification: Data
    var idleSeconds: Int = 300

    func validate() throws {
        guard version == 1 else { throw PrivacyError.unsupportedVersion }
        guard passwordSlot != nil || systemKeyID != nil else { throw PrivacyError.lastMethod }
        guard [60, 300, 900].contains(idleSeconds),
              verification.count >= 28, verification.count <= 256 else {
            throw PrivacyError.corruptData
        }
        if let slot = passwordSlot {
            guard slot.salt.count == 32, slot.wrappedKey.count == 60,
                  (600_000...5_000_000).contains(slot.iterations) else {
                throw PrivacyError.corruptData
            }
        }
    }
}

struct PrivateAttachmentEnvelope: Codable, Sendable {
    var version = 1
    var vaultID: UUID
    var attachmentID: UUID
    var ownerID: UUID
    var sealedData: Data

    var context: String { "attachment:\(ownerID.uuidString):\(attachmentID.uuidString)" }
}
