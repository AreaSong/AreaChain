import Foundation

/// 管理主应用与小组件扩展之间的 App Group 共享存储容器与平滑迁移。
enum AppGroup {
    /// 共享应用组标识
    static let identifier = "group.com.areachain.app"

    #if DEBUG
    /// 开发调试环境下使用独立的数据库文件名
    static let storeFileName = "areachain-debug.store"
    #else
    /// 正式发布生产环境下使用标准数据库文件名
    static let storeFileName = "areachain.store"
    #endif

    /// 共享容器根目录；未配置或沙盒限制时回退到 applicationSupportDirectory
    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        return URL.applicationSupportDirectory
    }

    /// 当前环境使用的数据库路径（Debug 模式独立于 Release）
    static var storeURL: URL {
        containerURL.appending(path: storeFileName)
    }

    /// 首次启用 App Group 或首次启动 Debug 时，平滑迁移或克隆已有数据，保证零丢失且数据隔离。
    static func migrateStoreIfNeeded() {
        guard let groupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            return
        }
        let oldDir = URL.applicationSupportDirectory
        let oldStore = oldDir.appending(path: "areachain.store")
        let prodStore = groupDir.appending(path: "areachain.store")
        let currentStore = groupDir.appending(path: storeFileName)

        try? FileManager.default.createDirectory(at: groupDir, withIntermediateDirectories: true)

        // 1. 迁移旧 applicationSupportDirectory 到 App Group 共享目录
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

        // 2. Debug 模式下首次启动如果 areachain-debug.store 为空，自动从正式库克隆一份初始底稿
        #if DEBUG
        if !FileManager.default.fileExists(atPath: currentStore.path) {
            let source = FileManager.default.fileExists(atPath: prodStore.path)
                ? prodStore
                : (FileManager.default.fileExists(atPath: oldStore.path) ? oldStore : nil)
            if let source {
                try? FileManager.default.copyItem(at: source, to: currentStore)
                for ext in ["-shm", "-wal"] {
                    let srcExt = source.appendingPathExtension(ext)
                    let dstExt = currentStore.appendingPathExtension(ext)
                    if FileManager.default.fileExists(atPath: srcExt.path) && !FileManager.default.fileExists(atPath: dstExt.path) {
                        try? FileManager.default.copyItem(at: srcExt, to: dstExt)
                    }
                }
            }
        }
        #endif
    }
}
