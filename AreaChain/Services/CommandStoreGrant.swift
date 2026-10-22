import Foundation
import SwiftData

/// 合并批 M-6：统一搜索写入环境在正式版的唯一放行凭据。
/// 没有凭据时环境保持隔离装配的原门槛：内存库、关闭自动保存、非 default 的私有事件中心。
/// 凭据只放行签发时的同一个 context（正式版即主容器的 mainContext，与原界面写入同一处）；
/// 干净 context、无外层事务、保存成功才发布等检查照旧在每次准备／提交前执行，不因凭据放宽。
/// 签发只允许出现在 UnifiedSearchProductionAssembly（check_workflow 的 unified-search-assembly 守卫）。
@MainActor struct CommandStoreGrant {
    private let context: ObjectIdentifier

    private init(context: ModelContext) { self.context = ObjectIdentifier(context) }

    static func production(_ context: ModelContext) -> CommandStoreGrant { .init(context: context) }

    /// center 为 nil 表示该环境不发布事件（例如只写剪贴板的复制）。
    static func admits(_ context: ModelContext, center: NotificationCenter?, grant: CommandStoreGrant?) -> Bool {
        if let grant { return grant.context == ObjectIdentifier(context) }
        return (center.map { $0 !== NotificationCenter.default } ?? true)
            && !context.autosaveEnabled && !context.container.configurations.isEmpty
            && context.container.configurations.allSatisfy(\.isStoredInMemoryOnly)
    }
}
