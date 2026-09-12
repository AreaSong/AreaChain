import Foundation
import SwiftData
import SQLite3

struct PersistenceSession {
    var container: ModelContainer
    var isFallback: Bool
    var openError: String?
}

enum Persistence {
    static let session: PersistenceSession = makeSession()

    static func makeSession() -> PersistenceSession {
        let schema = Schema(AreaChainSchema.models)
        // App.init 早于 AppDelegate 的测试保护；测试宿主不得先触碰真实磁盘库。
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return memorySession(schema: schema, openError: nil)
        }
        sanitizeSqliteStoreIfNeeded()
        let disk = ModelConfiguration("areachain", schema: schema)
        do {
            let container = try ModelContainer(for: schema, configurations: [disk])
            return PersistenceSession(container: container, isFallback: false, openError: nil)
        } catch {
            return memorySession(schema: schema, openError: error.localizedDescription)
        }
    }

    private static func memorySession(schema: Schema, openError: String?) -> PersistenceSession {
        do {
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            return PersistenceSession(container: container, isFallback: openError != nil, openError: openError)
        } catch {
            fatalError("无法打开内存库：\(error)")
        }
    }

    static func resetStoreOnDisk(
        removeItem: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    ) {
        let base = URL.applicationSupportDirectory
        // 同步基线属于被重置的数据集，不能随旧任务绑定遗留到新库。
        let filenames = ["areachain.store", "areachain.store-shm", "areachain.store-wal", CalendarSyncStorage.ledgerFilename]
        for filename in filenames {
            try? removeItem(base.appending(path: filename))
        }
        try? removeItem(AttachmentStore.directory())
    }

    private static func sanitizeSqliteStoreIfNeeded() {
        let base = URL.applicationSupportDirectory
        let dbURL = base.appending(path: "areachain.store")
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return }
        var db: OpaquePointer?
        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
            sqlite3_exec(db, "UPDATE ZTODOITEM SET ZNOTES = '' WHERE ZNOTES IS NULL;", nil, nil, nil)
            sqlite3_exec(db, "UPDATE ZDAILYROUTINE SET ZNOTES = '' WHERE ZNOTES IS NULL;", nil, nil, nil)
            sqlite3_close(db)
        }
    }
}
