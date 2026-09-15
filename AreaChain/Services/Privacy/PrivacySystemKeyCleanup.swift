import Foundation

extension PrivacyVault {
    /// 日志先于钥匙串写入；崩溃或撤销失败后仍能找到未提交的系统凭据。
    func rememberSystemKey(_ id: UUID) throws {
        try reloadPendingSystemKeyIDs()
        try persistPendingSystemKeyIDs(pendingSystemKeyIDs.union([id]))
    }

    func forgetSystemKey(_ id: UUID) throws {
        guard pendingSystemKeyIDs.contains(id) else { return }
        try persistPendingSystemKeyIDs(pendingSystemKeyIDs.subtracting([id]))
    }

    func discardUncommittedSystemKey(_ id: UUID) async throws {
        guard pendingSystemKeyIDs.contains(id) else { return }
        do {
            guard try recordedSystemKeyID() != id else { return }
            try await systemKeys.remove(id: id)
            try forgetSystemKey(id)
        } catch { throw PrivacyError.systemCleanupPending }
    }

    func cleanupObsoleteSystemKeys() async throws {
        try reloadPendingSystemKeyIDs()
        for id in pendingSystemKeyIDs {
            if try recordedSystemKeyID() == id {
                // 可能在提交配置后、删除日志前退出：当前有效的密钥绝不能被清理。
                try forgetSystemKey(id)
            } else {
                try await discardUncommittedSystemKey(id)
            }
        }
    }

    func retrySystemKeyCleanup() async throws {
        try beginMethodChange()
        defer { endMethodChange() }
        guard state != .unavailable else { throw issue ?? .storageFailure }
        if isConfigured { _ = try requireFreshAuthentication() }
        try await cleanupObsoleteSystemKeys()
    }

    private func recordedSystemKeyID() throws -> UUID? {
        let stored = try store.load()
        try stored?.validate()
        return stored?.systemKeyID
    }
}
