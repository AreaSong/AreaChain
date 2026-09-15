import CryptoKit
import Foundation

extension PrivacyVault {
    func create(password: String?, systemUnlock: Bool) async throws {
        try beginMethodChange()
        defer { endMethodChange() }
        guard state == .unconfigured, configuration == nil else { throw PrivacyError.corruptData }
        guard password != nil || systemUnlock else { throw PrivacyError.lastMethod }
        let token = try beginAuthentication()
        defer { endAuthentication(token) }
        try await cleanupObsoleteSystemKeys()
        guard generation == token, !Task.isCancelled else { throw PrivacyError.staleOperation }
        let id = UUID()
        let data = try VaultCrypto.randomBytes(count: 32)
        let slot = try await makePasswordSlot(password, key: data, vaultID: id)
        guard generation == token, !Task.isCancelled else { throw PrivacyError.staleOperation }
        let verification = try VaultCrypto.seal(Data(id.uuidString.utf8), key: SymmetricKey(data: data),
                                                context: "verification:\(id.uuidString)")
        let systemID = systemUnlock ? UUID() : nil
        var committed = false
        do {
            if let systemID { try await createSystemRoute(data, id: systemID, token: token) }
            guard generation == token, !Task.isCancelled else { throw PrivacyError.staleOperation }
            let config = PrivacyConfiguration(vaultID: id, passwordSlot: slot,
                                              systemKeyID: systemID, verification: verification)
            try persist(config)
            committed = true
            if let systemID { try forgetSystemKey(systemID) }
            try finishAuthentication(data, configuration: config, token: token)
        } catch {
            // 配置一旦提交，取消只能重新锁定，不能删除持久化配置依赖的唯一密钥。
            if committed { lock() }
            else if let systemID { try await discardUncommittedSystemKey(systemID) }
            throw error
        }
    }

    func changePassword(to password: String) async throws {
        try beginMethodChange()
        defer { endMethodChange() }
        var config = try requireFreshAuthentication()
        let token = try beginAuthentication()
        defer { endAuthentication(token) }
        let data = try keys.dataKey(vaultID: config.vaultID)
        config.passwordSlot = try await makePasswordSlot(password, key: data, vaultID: config.vaultID)
        guard generation == token, isUnlocked, !Task.isCancelled else { throw PrivacyError.staleOperation }
        try persist(config)
    }

    func enableSystemUnlock() async throws {
        try beginMethodChange()
        defer { endMethodChange() }
        var config = try requireFreshAuthentication()
        try await cleanupObsoleteSystemKeys()
        guard config.systemKeyID == nil else { return }
        let token = try beginAuthentication()
        defer { endAuthentication(token) }
        let data = try keys.dataKey(vaultID: config.vaultID)
        let id = UUID()
        do {
            try await createSystemRoute(data, id: id, token: token)
            guard generation == token, isUnlocked, !Task.isCancelled else { throw PrivacyError.staleOperation }
            config.systemKeyID = id
            try persist(config)
            try forgetSystemKey(id)
        } catch {
            try await discardUncommittedSystemKey(id)
            throw error
        }
    }

    func disableSystemUnlock(masterPassword: String) async throws {
        try beginMethodChange()
        defer { endMethodChange() }
        guard let original = configuration, original.passwordSlot != nil else { throw PrivacyError.lastMethod }
        // 必须实际验证保留下来的主密码，而非仅检查“曾设置过”。
        try await unlockWithPassword(masterPassword)
        guard let id = original.systemKeyID else { return }
        var updated = original
        updated.systemKeyID = nil
        try rememberSystemKey(id)
        try persist(updated)
        do {
            try await systemKeys.remove(id: id)
        } catch {
            do { try persist(original) }
            catch { lock(); throw PrivacyError.storageFailure }
            throw error
        }
        try forgetSystemKey(id)
    }

    func removePassword(reason: String) async throws {
        try beginMethodChange()
        defer { endMethodChange() }
        guard configuration?.systemKeyID != nil else { throw PrivacyError.lastMethod }
        try await unlockWithSystem(reason: reason)
        var updated = try requireFreshAuthentication()
        updated.passwordSlot = nil
        try persist(updated)
    }

    func setIdleSeconds(_ seconds: Int) throws {
        try beginMethodChange()
        defer { endMethodChange() }
        var updated = try requireFreshAuthentication()
        updated.idleSeconds = seconds
        try updated.validate()
        try persist(updated)
    }

    private func makePasswordSlot(_ password: String?, key: Data, vaultID: UUID) async throws -> PasswordKeySlot? {
        guard let password else { return nil }
        return try await Task.detached(priority: .userInitiated) {
            try VaultCrypto.wrap(key, password: password, vaultID: vaultID)
        }.value
    }

    private func createSystemRoute(_ data: Data, id: UUID, token: UInt64) async throws {
        guard generation == token, !Task.isCancelled else { throw PrivacyError.staleOperation }
        try rememberSystemKey(id)
        guard generation == token, !Task.isCancelled else { throw PrivacyError.staleOperation }
        try await systemKeys.create(data, id: id)
        guard generation == token, !Task.isCancelled else { throw PrivacyError.staleOperation }
        let reason = L10n.string("privacy.unlock.reason", locale: .current)
        let verified = try await systemKeys.read(id: id, reason: reason)
        guard generation == token, !Task.isCancelled else { throw PrivacyError.staleOperation }
        guard verified == data else { throw PrivacyError.corruptData }
    }
}
