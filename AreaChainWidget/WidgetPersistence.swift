import Foundation
import SwiftData

/// 为小组件提供轻量、只读或有限交互的 ModelContainer 访问
enum WidgetPersistence {
    static let appGroupIdentifier = "group.com.areachain.app"

    #if DEBUG
    static let storeFileName = "areachain-debug.store"
    #else
    static let storeFileName = "areachain.store"
    #endif

    static var storeURL: URL {
        let groupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? URL.applicationSupportDirectory
        return groupDir.appending(path: storeFileName)
    }

    static func makeContainer() -> ModelContainer? {
        let schema = Schema(WidgetSchema.models)
        let targetURL = storeURL
        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            return nil
        }
        let config = ModelConfiguration("areachain", schema: schema, url: targetURL)
        return try? ModelContainer(for: schema, configurations: [config])
    }
}
