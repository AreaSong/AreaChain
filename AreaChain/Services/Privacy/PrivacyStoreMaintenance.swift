import Foundation
import SQLite3
import SwiftData

/// 更新正文列不足以清除 SQLite 空闲页/WAL。清理标记先于转换落盘，崩溃后仍可重试重建。
enum PrivacyStoreMaintenance {
    static func marker(for url: URL) -> URL { url.appendingPathExtension("privacy-cleanup") }

    @MainActor static func storeURL(_ context: ModelContext) -> URL? {
        context.container.configurations.first(where: { !$0.isStoredInMemoryOnly })?.url
    }

    @MainActor static func mark(_ context: ModelContext) throws {
        guard let url = storeURL(context) else { return }
        try Data("AreaChain privacy cleanup v1".utf8).write(to: marker(for: url), options: .atomic)
    }

    @MainActor static func isPending(_ context: ModelContext) -> Bool {
        guard let url = storeURL(context) else { return false }
        return FileManager.default.fileExists(atPath: marker(for: url).path)
    }

    @MainActor static func request(_ context: ModelContext) {
        guard let url = storeURL(context) else { return }
        PrivacyVault.shared.changed()
        Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(350))
            if (try? finish(at: url)) != nil {
                await MainActor.run { PrivacyVault.shared.changed() }
            }
        }
    }

    @discardableResult
    @MainActor static func performOnlineCleanupIfPossible(for context: ModelContext) -> Bool {
        guard let url = storeURL(context), isPending(context) else { return false }
        do {
            try finish(at: url)
            PrivacyVault.shared.changed()
            return true
        } catch {
            return false
        }
    }

    /// 只操作当前容器的已知库路径；不读取标记中的路径，也不清理用户的其他备份。
    static func finish(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: marker(for: url).path) else { return }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db else {
            if let db { sqlite3_close(db) }
            throw PrivacyError.storageFailure
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1_000)
        guard sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil) == SQLITE_OK,
              sqlite3_exec(db, "VACUUM;", nil, nil, nil) == SQLITE_OK,
              sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil) == SQLITE_OK else {
            throw PrivacyError.storageFailure
        }
        try FileManager.default.removeItem(at: marker(for: url))
    }
}
