import Foundation
import LocalAuthentication
import Security

protocol SystemVaultKeyStorage: Sendable {
    func create(_ data: Data, id: UUID) async throws
    func read(id: UUID, reason: String) async throws -> Data
    func remove(id: UUID) async throws
    func cancel()
}

final class SystemVaultKeyStore: SystemVaultKeyStorage, @unchecked Sendable {
    private let service: String
    private let onFailure: @Sendable (OSStatus) -> Void
    private let mutex = NSLock()
    private var contexts: [UUID: LAContext] = [:]

    init(service: String = (Bundle.main.bundleIdentifier ?? "com.areachain.app") + ".private-vault",
         onFailure: @escaping @Sendable (OSStatus) -> Void = { _ in }) {
        self.service = service
        self.onFailure = onFailure
    }

    func create(_ data: Data, id: UUID) async throws {
        guard data.count == 32 else { throw PrivacyError.corruptData }
        try await Task.detached(priority: .userInitiated) { [self] in
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, &error
            ) else { throw PrivacyError.systemUnavailable }
            var query = baseQuery(id)
            query[kSecAttrAccessControl as String] = access
            query[kSecValueData as String] = data
            query[kSecAttrLabel as String] = "AreaChain private notes"
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else { throw failure(status) }
        }.value
    }

    func read(id: UUID, reason: String) async throws -> Data {
        let context = LAContext()
        context.localizedReason = reason
        context.touchIDAuthenticationAllowableReuseDuration = 0
        let token = UUID()
        register(context, token: token)
        defer { unregister(token); context.invalidate() }
        return try await Task.detached(priority: .userInitiated) { [self] in
            var query = baseQuery(id)
            query[kSecUseAuthenticationContext as String] = context
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data, data.count == 32 else {
                throw failure(status)
            }
            return data
        }.value
    }

    func remove(id: UUID) async throws {
        try await Task.detached(priority: .userInitiated) { [self] in
            let status = SecItemDelete(baseQuery(id) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw failure(status) }
        }.value
    }

    func cancel() {
        mutex.lock()
        let active = Array(contexts.values)
        mutex.unlock()
        active.forEach { $0.invalidate() }
    }

    /// 仅查询随机且不存在的条目；禁止交互，不读取任何现有凭据，也不写入测试密钥。
    func availabilityStatus() -> OSStatus {
        var query = baseQuery(UUID())
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil)
    }

    private func baseQuery(_ id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false
        ]
    }

    private func register(_ context: LAContext, token: UUID) {
        mutex.lock()
        defer { mutex.unlock() }
        contexts[token] = context
    }

    private func unregister(_ token: UUID) {
        mutex.lock()
        defer { mutex.unlock() }
        contexts[token] = nil
    }

    private func failure(_ status: OSStatus) -> PrivacyError {
        // 隔离验收只接收错误码，不暴露凭据或系统错误随附的私密上下文。
        onFailure(status)
        if status == errSecUserCanceled { return .cancelled }
        // 不把系统错误的任意文本写进日志；缺少签名权限也不能退回无访问控制的钥匙串。
        return .systemUnavailable
    }
}
