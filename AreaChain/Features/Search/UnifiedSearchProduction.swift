import Foundation
import Observation

/// 合并批 M-6：“新版搜索与指令”开关的唯一运行时入口。开关开时持有唯一装配；关时销毁装配、两个宿主回到旧搜索。
/// 关闭只撤销控制器、读取会话与长文托管（明文不留）；协调者保留，未提交的草稿与计划在重新打开后仍在，
/// 不会自动执行。装配本身不读库、不申请任何系统权限；只有执行对应指令时才可能触发授权。
@Observable @MainActor final class UnifiedSearchProduction {
    static let shared = UnifiedSearchProduction()
    private(set) var assembly: UnifiedSearchProductionAssembly?
    /// 每次重建装配都 +1；宿主用它重新挂载，避免把已 detach 的控制器留在视图里。
    private(set) var generation: UInt64 = 0
    /// 开关开着但装配失败：宿主仍走旧搜索，设置“搜索”分节据此给一句不阻塞的说明；之后任一偏好变化会重试。
    private(set) var assemblyFailed = false
    @ObservationIgnored private var makeServices: (() -> UnifiedSearchProductionServices)?
    @ObservationIgnored private var preferences: AppPreferences?
    @ObservationIgnored private var retained: CommandHandoffCoordinator?
    @ObservationIgnored private var observer: NSObjectProtocol?
    /// 构造入口；只有测试替换它来模拟装配失败，正式版恒为唯一装配点。
    @ObservationIgnored var assemble: (UnifiedSearchProductionServices, CommandHandoffCoordinator?)
        -> Result<UnifiedSearchProductionAssembly, Error> = { UnifiedSearchProductionAssembly.attempt(services: $0, coordinator: $1) }

    /// 正式版由 AppDelegate 在 application 分支调用一次；测试可以构造自己的实例并注入 fake 服务。
    func start(preferences: AppPreferences, center: NotificationCenter = .default,
               makeServices: @escaping () -> UnifiedSearchProductionServices) {
        self.preferences = preferences
        self.makeServices = makeServices
        if let observer { center.removeObserver(observer) }
        observer = center.addObserver(forName: .appPreferencesDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
        sync()
    }

    /// 按当前偏好对齐：开→（重）建装配；关→销毁装配并让工作台回到旧搜索的展示状态。
    func sync() {
        guard let preferences, let makeServices else { return }
        if preferences.unifiedSearchEnabled {
            guard assembly == nil else { return }
            assembly = try? assemble(makeServices(), retained).get()
            assemblyFailed = assembly == nil
            if let assembly {
                retained = assembly.coordinator
                // 工作台已打开时切到新搜索：按协调者当前查询决定是否显示结果，不把空查询当成搜索页。
                assembly.services.navigation.searchPresentation =
                    (try? assembly.coordinator.host(UnifiedSearchProductionAssembly.workspaceHost).session.query.showsResults) ?? false
            }
        } else if let assembly {
            assembly.discard()
            self.assembly = nil
        } else {
            assemblyFailed = false
            return
        }
        generation &+= 1
    }

    func controller(for hostID: String) -> UnifiedSearchController? { assembly?.controller(for: hostID) }

    /// 只供测试收尾：停止观察并销毁装配，不改偏好。
    func stop(center: NotificationCenter = .default) {
        if let observer { center.removeObserver(observer) }
        observer = nil
        assembly?.discard()
        assembly = nil
        assemblyFailed = false
        retained = nil
        preferences = nil
        makeServices = nil
    }
}
