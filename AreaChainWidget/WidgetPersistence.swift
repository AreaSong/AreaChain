import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.areachain.app.widget", category: "Persistence")

/// 为小组件提供轻量、只读或有限交互的 ModelContainer 访问
enum WidgetPersistence {
    static let appGroupIdentifier = "group.com.areachain.app"
    static let storeFileName = "areachain.store"

    static var baseContainerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return url
        }
        return URL.applicationSupportDirectory
    }

    static func readLanguagePreference() -> String? {
        let file = baseContainerURL.appending(path: "language.pref")
        if let data = try? Data(contentsOf: file),
           let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            return str
        }
        return nil
    }

    /// 智能解析当前活跃的数据库路径：
    /// 优先使用与构建环境相符的路径；若两者均存在，选择最新修改的 store 文件，避免调试/发布环境切换时读到空库
    static var storeURL: URL {
        let debugStore = baseContainerURL.appending(path: "debug").appending(path: storeFileName)
        let rootStore = baseContainerURL.appending(path: storeFileName)

        let debugExists = FileManager.default.fileExists(atPath: debugStore.path)
        let rootExists = FileManager.default.fileExists(atPath: rootStore.path)

        if debugExists && rootExists {
            let debugDate = (try? FileManager.default.attributesOfItem(atPath: debugStore.path)[.modificationDate] as? Date) ?? .distantPast
            let rootDate = (try? FileManager.default.attributesOfItem(atPath: rootStore.path)[.modificationDate] as? Date) ?? .distantPast
            let chosen = debugDate >= rootDate ? debugStore : rootStore
            logger.debug("Both stores exist. Chosen newer store: \(chosen.path, privacy: .public)")
            return chosen
        }

        if debugExists {
            return debugStore
        }
        if rootExists {
            return rootStore
        }

        #if DEBUG
        return debugStore
        #else
        return rootStore
        #endif
    }

    static func makeContainer() -> ModelContainer? {
        let schema = Schema(WidgetSchema.models)
        let targetURL = storeURL
        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            logger.error("Target store file does not exist at: \(targetURL.path, privacy: .public)")
            return nil
        }
        let config = ModelConfiguration("areachain", schema: schema, url: targetURL)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            return container
        } catch {
            logger.error("Failed to initialize ModelContainer: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
