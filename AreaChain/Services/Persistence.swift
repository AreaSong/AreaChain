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
        sanitizeSqliteStoreIfNeeded()
        let schema = Schema(AreaChainSchema.models)
        let disk = ModelConfiguration("areachain", schema: schema)
        do {
            let container = try ModelContainer(for: schema, configurations: [disk])
            return PersistenceSession(container: container, isFallback: false, openError: nil)
        } catch {
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                let container = try ModelContainer(for: schema, configurations: [memory])
                return PersistenceSession(
                    container: container,
                    isFallback: true,
                    openError: error.localizedDescription
                )
            } catch {
                fatalError("无法打开内存库：\(error)")
            }
        }
    }

    static func resetStoreOnDisk() {
        let base = URL.applicationSupportDirectory
        for extra in ["", "-shm", "-wal"] {
            let url = base.appending(path: "areachain.store\(extra)")
            try? FileManager.default.removeItem(at: url)
        }
        AttachmentStore.resetDirectory()
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
