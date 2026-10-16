import Foundation

/// 管理主应用与小组件扩展之间的 App Group 共享存储容器与平滑迁移。
enum AppGroup {
    /// 共享应用组标识
    static let identifier = "group.com.areachain.app"
    static let storeFileName = "areachain.store"

    /// 共享容器基础根目录；未配置或沙盒限制时回退到 applicationSupportDirectory
    static var baseContainerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        return URL.applicationSupportDirectory
    }

    /// 当前环境使用的目录根（Debug 版独立放置于 debug/ 子目录，Release 版直接在根目录）
    static var containerURL: URL {
        #if DEBUG
        let url = baseContainerURL.appending(path: "debug", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
        #else
        return baseContainerURL
        #endif
    }

    /// 当前环境使用的数据库路径
    static var storeURL: URL {
        containerURL.appending(path: storeFileName)
    }

    static func writeLanguagePreference(_ language: String) {
        let file = baseContainerURL.appending(path: "language.pref")
        try? language.data(using: .utf8)?.write(to: file, options: .atomic)
    }

    /// 首次启用 App Group 时平滑迁移已有数据（仅正式版迁移真实生产数据；Debug 版保持独立纯净，不复制真实手记）
    static func migrateStoreIfNeeded() {
        #if !DEBUG
        guard let groupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            return
        }
        let oldDir = URL.applicationSupportDirectory
        let oldStore = oldDir.appending(path: "areachain.store")
        let prodStore = groupDir.appending(path: storeFileName)

        try? FileManager.default.createDirectory(at: groupDir, withIntermediateDirectories: true)

        // 仅正式版将旧应用沙盒内的数据迁移至 App Group 根目录
        if FileManager.default.fileExists(atPath: oldStore.path) && !FileManager.default.fileExists(atPath: prodStore.path) {
            let filenames = [
                "areachain.store",
                "areachain.store-shm",
                "areachain.store-wal",
                "areachain.store.privacy-cleanup",
                CalendarSyncStorage.ledgerFilename
            ]
            for name in filenames {
                let src = oldDir.appending(path: name)
                let dst = groupDir.appending(path: name)
                if FileManager.default.fileExists(atPath: src.path) && !FileManager.default.fileExists(atPath: dst.path) {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        }
        #endif
    }
}
