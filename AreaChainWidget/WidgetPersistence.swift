import Foundation
import SwiftData

/// 为小组件提供轻量、只读或有限交互的 ModelContainer 访问
enum WidgetPersistence {
    static let appGroupIdentifier = "group.com.areachain.app"

    static let storeFileName = "areachain.store"

    static var containerURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? URL.applicationSupportDirectory
        #if DEBUG
        return base.appending(path: "debug", directoryHint: .isDirectory)
        #else
        return base
        #endif
    }

    static var storeURL: URL {
        containerURL.appending(path: storeFileName)
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
