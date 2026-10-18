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

    /// 获取指定环境的数据库文件路径：
    /// - isDebug: true 时读取开发测试沙盒路径（debug/areachain.store）
    /// - isDebug: false 时读取正式生产数据路径（areachain.store）
    static func storeURL(isDebug: Bool) -> URL {
        if isDebug {
            return baseContainerURL.appending(path: "debug").appending(path: storeFileName)
        } else {
            return baseContainerURL.appending(path: storeFileName)
        }
    }

    /// 兼容未传 isDebug 时的默认路径（按编译条件区分）
    static var storeURL: URL {
        #if DEBUG
        return storeURL(isDebug: true)
        #else
        return storeURL(isDebug: false)
        #endif
    }

    static func makeContainer(isDebug: Bool? = nil) -> ModelContainer? {
        let schema = Schema(WidgetSchema.models)
        let resolvedIsDebug: Bool
        if let explicit = isDebug {
            resolvedIsDebug = explicit
        } else {
            #if DEBUG
            resolvedIsDebug = true
            #else
            resolvedIsDebug = false
            #endif
        }
        let targetURL = storeURL(isDebug: resolvedIsDebug)
        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            logger.error("Target store file does not exist at: \(targetURL.path, privacy: .public)")
            return nil
        }
        let config = ModelConfiguration(resolvedIsDebug ? "areachain-debug" : "areachain", schema: schema, url: targetURL)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            return container
        } catch {
            logger.error("Failed to initialize ModelContainer (isDebug=\(resolvedIsDebug)): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
