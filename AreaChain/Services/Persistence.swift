import Foundation
import SwiftData

enum Persistence {
    static func makeContainer() -> ModelContainer {
        let schema = Schema(AreaChainSchema.models)
        let configuration = ModelConfiguration("areachain", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            resetStore(named: "areachain")
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("无法打开本地数据：\(error)")
            }
        }
    }

    private static func resetStore(named name: String) {
        let base = URL.applicationSupportDirectory
        let extras = ["", "-shm", "-wal"]
        for extra in extras {
            let url = base.appending(path: "\(name).store\(extra)")
            try? FileManager.default.removeItem(at: url)
        }
    }
}
