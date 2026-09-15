import CommonCrypto
import CryptoKit
import Foundation
import Security

enum VaultCrypto {
    static let passwordIterations = 600_000
    static let attachmentMagic = Data("ACPRIV1\n".utf8)
    static let maximumAttachmentBytes = 64 * 1_024 * 1_024

    static func randomBytes(count: Int) throws -> Data {
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        guard status == errSecSuccess else { throw PrivacyError.systemUnavailable }
        return bytes
    }

    static func seal(_ data: Data, key: SymmetricKey, context: String) throws -> Data {
        let aad = Data(("AreaChain.privacy.v1:" + context).utf8)
        guard let combined = try AES.GCM.seal(data, using: key, authenticating: aad).combined else {
            throw PrivacyError.corruptData
        }
        return combined
    }

    static func open(_ data: Data, key: SymmetricKey, context: String) throws -> Data {
        do {
            let aad = Data(("AreaChain.privacy.v1:" + context).utf8)
            return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key, authenticating: aad)
        } catch {
            throw PrivacyError.corruptData
        }
    }

    static func deriveKey(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        guard salt.count == 32, (600_000...5_000_000).contains(iterations),
              password.utf8.count <= 4_096 else { throw PrivacyError.corruptData }
        var passwordBytes = Array(password.utf8)
        var derived = Data(count: 32)
        defer { _ = passwordBytes.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        let status = passwordBytes.withUnsafeBytes { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                derived.withUnsafeMutableBytes { output in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress?.assumingMemoryBound(to: CChar.self), passwordBuffer.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self), saltBuffer.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                        output.baseAddress?.assumingMemoryBound(to: UInt8.self), output.count
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw PrivacyError.corruptData }
        defer { derived.resetBytes(in: 0..<derived.count) }
        return SymmetricKey(data: derived)
    }

    static func wrap(_ key: Data, password: String, vaultID: UUID) throws -> PasswordKeySlot {
        guard password.count >= 12, password.utf8.count <= 4_096 else { throw PrivacyError.weakPassword }
        let salt = try randomBytes(count: 32)
        let wrappingKey = try deriveKey(password: password, salt: salt, iterations: passwordIterations)
        let wrapped = try seal(key, key: wrappingKey, context: "key:\(vaultID.uuidString)")
        return PasswordKeySlot(salt: salt, iterations: passwordIterations, wrappedKey: wrapped)
    }

    static func unwrap(_ slot: PasswordKeySlot, password: String, vaultID: UUID) throws -> Data {
        let key = try deriveKey(password: password, salt: slot.salt, iterations: slot.iterations)
        do {
            let data = try open(slot.wrappedKey, key: key, context: "key:\(vaultID.uuidString)")
            guard data.count == 32 else { throw PrivacyError.corruptData }
            return data
        } catch {
            throw PrivacyError.wrongPassword
        }
    }

    static func verify(_ key: Data, configuration: PrivacyConfiguration) throws {
        guard key.count == 32 else { throw PrivacyError.corruptData }
        let challenge = try open(configuration.verification, key: SymmetricKey(data: key),
                                 context: "verification:\(configuration.vaultID.uuidString)")
        guard challenge == Data(configuration.vaultID.uuidString.utf8) else { throw PrivacyError.corruptData }
    }
}
