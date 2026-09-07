import Foundation
import SwiftData

struct PersistenceSession {
    var container: ModelContainer
    var isFallback: Bool
    var openError: String?
}

enum Persistence {
    static let session: PersistenceSession = makeSession()

    static func makeSession() -> PersistenceSession {
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
    }
}
