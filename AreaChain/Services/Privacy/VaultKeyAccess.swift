import CryptoKit
import Foundation

/// 同步文件读取也必须经过这一道锁；后台解密结束时再核对代次，拒绝锁定后的迟到结果。
final class VaultKeyAccess: @unchecked Sendable {
    static let shared = VaultKeyAccess()
    private let mutex = NSLock()
    private var key: SymmetricKey?
    private var vaultID: UUID?
    private var generation: UInt64 = 0

    func install(_ data: Data, vaultID: UUID) {
        mutex.lock()
        defer { mutex.unlock() }
        generation &+= 1
        key = SymmetricKey(data: data)
        self.vaultID = vaultID
    }

    func clear() {
        mutex.lock()
        defer { mutex.unlock() }
        generation &+= 1
        key = nil
        vaultID = nil
    }

    func withKey<T>(vaultID: UUID, _ work: (SymmetricKey) throws -> T) throws -> T {
        mutex.lock()
        guard self.vaultID == vaultID, let key else {
            mutex.unlock()
            throw PrivacyError.locked
        }
        let token = generation
        mutex.unlock()
        let value = try work(key)
        mutex.lock()
        defer { mutex.unlock() }
        guard generation == token, self.key != nil else { throw PrivacyError.staleOperation }
        return value
    }

    func dataKey(vaultID: UUID) throws -> Data {
        try withKey(vaultID: vaultID) { $0.withUnsafeBytes { Data($0) } }
    }

    func seal(_ data: Data, vaultID: UUID, context: String) throws -> Data {
        try withKey(vaultID: vaultID) { try VaultCrypto.seal(data, key: $0, context: context) }
    }

    func open(_ data: Data, vaultID: UUID, context: String) throws -> Data {
        try withKey(vaultID: vaultID) { try VaultCrypto.open(data, key: $0, context: context) }
    }
}
