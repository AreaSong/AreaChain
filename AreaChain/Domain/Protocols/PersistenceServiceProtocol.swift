import Foundation
import SwiftData

/// 持久化容器健康状态评估
struct PersistenceHealth: Equatable, Sendable {
    var isUsingMemoryFallback: Bool
    var openError: String?
    var isHealthy: Bool { !isUsingMemoryFallback && openError == nil }

    init(isUsingMemoryFallback: Bool, openError: String? = nil) {
        self.isUsingMemoryFallback = isUsingMemoryFallback
        self.openError = openError
    }
}

/// 核心持久化容器与会话生命周期管理契约
protocol PersistenceServiceProtocol: AnyObject, Sendable {
    /// 主 SwiftData 容器实例
    var container: ModelContainer { get }

    /// 主线程上下文便捷访问器
    @MainActor var mainContext: ModelContext { get }

    /// 评估持久化健康状态
    func checkHealth() -> PersistenceHealth

    /// 重置磁盘上的 SQLite 数据库与附件目录（危险操作，彻底清空）
    func resetStoreOnDisk() throws
}

extension PersistenceServiceProtocol {
    @MainActor
    var mainContext: ModelContext {
        container.mainContext
    }

    func isHealthy() -> Bool {
        checkHealth().isHealthy
    }
}
