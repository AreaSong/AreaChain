import CommonCrypto
import CryptoKit
import Foundation
import Security

enum VaultCrypto {
    static let passwordIterations = 600_000
    static let attachmentMagic = Data("ACPRIV1\n".utf8)
    static let maximumAttachmentBytes = 64 * 1_024 * 1_024

    #if DEBUG
    /// 仅测试：恢复路径应只 PBKDF2 unwrap 一次；夹具必须在 defer 里清掉。
    nonisolated(unsafe) static var testingPasswordUnwraps = 0
    /// 仅测试：卡在 PBKDF2 返回后、继续封装/解封之前。
    nonisolated(unsafe) static var testingAfterKeyDerivation: (@Sendable () throws -> Void)?
    /// 仅测试：卡在 HMAC 轮次中、整次派生结束前。
    nonisolated(unsafe) static var testingDuringKeyDerivation: (@Sendable (Int) throws -> Void)?
    #endif

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

    static func deriveKey(password: String, salt: Data, iterations: Int, cooperative: Bool = false) throws -> SymmetricKey {
        try PrivacyTask.checkCancellation()
        guard salt.count == 32, (600_000...5_000_000).contains(iterations),
              password.utf8.count <= 4_096 else { throw PrivacyError.corruptData }
        var passwordBytes = Array(password.utf8)
        defer { _ = passwordBytes.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        var derived: Data
        if cooperative {
            // 备份路径需要在 HMAC 轮次间观察取消；解锁仍走 CommonCrypto。
            derived = try pbkdf2HMACSHA256(password: passwordBytes, salt: salt, iterations: iterations)
        } else {
            derived = try pbkdf2CommonCrypto(password: passwordBytes, salt: salt, iterations: iterations)
        }
        defer { derived.resetBytes(in: 0..<derived.count) }
        #if DEBUG
        try testingAfterKeyDerivation?()
        #endif
        try PrivacyTask.checkCancellation()
        return SymmetricKey(data: derived)
    }

    private static func pbkdf2CommonCrypto(password: [UInt8], salt: Data, iterations: Int) throws -> Data {
        var derived = Data(count: 32)
        let status = password.withUnsafeBytes { passwordBuffer in
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
        return derived
    }

    private static func pbkdf2HMACSHA256(password: [UInt8], salt: Data, iterations: Int) throws -> Data {
        var u = [UInt8](repeating: 0, count: 32)
        var next = [UInt8](repeating: 0, count: 32)
        var t = [UInt8](repeating: 0, count: 32)
        var block = Array(salt)
        block.append(contentsOf: [0, 0, 0, 1])
        hmacSHA256(password: password, message: block, output: &u)
        t = u
        if iterations > 1 {
            for round in 2...iterations {
                hmacSHA256(password: password, message: u, output: &next)
                u = next
                for index in 0..<32 { t[index] ^= u[index] }
                if round.isMultiple(of: 2_048) {
                    #if DEBUG
                    try testingDuringKeyDerivation?(round)
                    #endif
                    try PrivacyTask.checkCancellation()
                }
            }
        }
        return Data(t)
    }

    private static func hmacSHA256(password: [UInt8], message: [UInt8], output: inout [UInt8]) {
        password.withUnsafeBytes { key in
            message.withUnsafeBytes { data in
                output.withUnsafeMutableBytes { mac in
                    CCHmac(
                        CCHmacAlgorithm(kCCHmacAlgSHA256),
                        key.baseAddress, key.count,
                        data.baseAddress, data.count,
                        mac.baseAddress
                    )
                }
            }
        }
    }

    static func wrap(_ key: Data, password: String, vaultID: UUID, cooperative: Bool = false) throws -> PasswordKeySlot {
        guard password.count >= 12, password.utf8.count <= 4_096 else { throw PrivacyError.weakPassword }
        let salt = try randomBytes(count: 32)
        let wrappingKey = try deriveKey(password: password, salt: salt, iterations: passwordIterations, cooperative: cooperative)
        let wrapped = try seal(key, key: wrappingKey, context: "key:\(vaultID.uuidString)")
        return PasswordKeySlot(salt: salt, iterations: passwordIterations, wrappedKey: wrapped)
    }

    static func unwrap(_ slot: PasswordKeySlot, password: String, vaultID: UUID, cooperative: Bool = false) throws -> Data {
        #if DEBUG
        testingPasswordUnwraps += 1
        #endif
        let key = try deriveKey(password: password, salt: slot.salt, iterations: slot.iterations, cooperative: cooperative)
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
