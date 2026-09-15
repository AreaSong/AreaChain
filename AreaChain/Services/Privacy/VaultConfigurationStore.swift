import Foundation

protocol VaultConfigurationStorage {
    func load() throws -> PrivacyConfiguration?
    func save(_ configuration: PrivacyConfiguration) throws
    func loadPendingSystemKeyIDs() throws -> Set<UUID>
    func savePendingSystemKeyIDs(_ ids: Set<UUID>) throws
}

final class FileVaultConfigurationStore: VaultConfigurationStorage {
    let url: URL

    init(url: URL = URL.applicationSupportDirectory.appending(path: "areachain-privacy.json")) {
        self.url = url
    }

    func load() throws -> PrivacyConfiguration? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
            guard size < 65_536 else { throw PrivacyError.corruptData }
            let data = try Data(contentsOf: url)
            guard data.count < 65_536 else { throw PrivacyError.corruptData }
            let value = try JSONDecoder().decode(PrivacyConfiguration.self, from: data)
            try value.validate()
            return value
        } catch let error as PrivacyError {
            throw error
        } catch {
            throw PrivacyError.storageFailure
        }
    }

    func save(_ configuration: PrivacyConfiguration) throws {
        try configuration.validate()
        try write(JSONEncoder().encode(configuration), to: url)
    }

    private var pendingKeysURL: URL { url.appendingPathExtension("pending-system-keys") }

    func loadPendingSystemKeyIDs() throws -> Set<UUID> {
        guard FileManager.default.fileExists(atPath: pendingKeysURL.path) else { return [] }
        do {
            let size = (try FileManager.default.attributesOfItem(atPath: pendingKeysURL.path)[.size] as? NSNumber)?.intValue ?? 0
            guard size < 65_536 else { throw PrivacyError.corruptData }
            let data = try Data(contentsOf: pendingKeysURL)
            guard data.count < 65_536 else { throw PrivacyError.corruptData }
            return try JSONDecoder().decode(Set<UUID>.self, from: data)
        } catch { throw PrivacyError.storageFailure }
    }

    func savePendingSystemKeyIDs(_ ids: Set<UUID>) throws {
        try write(JSONEncoder().encode(ids), to: pendingKeysURL)
    }

    private func write(_ data: Data, to destination: URL) throws {
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let temporary = destination.deletingLastPathComponent().appending(path: ".areachain-key-\(UUID().uuidString).tmp")
            defer { try? FileManager.default.removeItem(at: temporary) }
            try data.write(to: temporary, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary, options: .usingNewMetadataOnly)
            } else {
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
        } catch {
            throw PrivacyError.storageFailure
        }
    }
}

/// 测试与预览不读取真实钥匙串或隐私配置文件。
final class MemoryVaultConfigurationStore: VaultConfigurationStorage {
    var value: PrivacyConfiguration?
    var saveError: Error?
    var loadError: Error?
    var pendingSystemKeyIDs: Set<UUID> = []
    var pendingSaveError: Error?

    init(_ value: PrivacyConfiguration? = nil) { self.value = value }
    func load() throws -> PrivacyConfiguration? {
        if let loadError { throw loadError }
        return value
    }
    func save(_ configuration: PrivacyConfiguration) throws {
        if let saveError { throw saveError }
        try configuration.validate()
        value = configuration
    }
    func loadPendingSystemKeyIDs() throws -> Set<UUID> { pendingSystemKeyIDs }
    func savePendingSystemKeyIDs(_ ids: Set<UUID>) throws {
        if let pendingSaveError { throw pendingSaveError }
        pendingSystemKeyIDs = ids
    }
}
