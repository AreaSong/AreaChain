import Foundation
import Observation

/// 统一搜索的唯一运行时入口（合并批 M-6 接入，收尾批 M-7 起是工作台与菜单栏唯一的搜索）。启动时建立唯一装配；
/// 装配失败时两个宿主的搜索框显示一句不阻塞的说明，应用其余部分照常，之后任一偏好变化都会重试。
/// 装配本身不读库、不申请任何系统权限；只有执行对应指令时才可能触发授权。
@Observable @MainActor final class UnifiedSearchProduction {
    static let shared = UnifiedSearchProduction()
    private(set) var assembly: UnifiedSearchProductionAssembly?
    /// 每次重建装配都 +1；宿主用它重新挂载，避免把已 detach 的控制器留在视图里。
    private(set) var generation: UInt64 = 0
    /// 已启动但装配失败：宿主搜索框据此显示不可用说明。
    private(set) var assemblyFailed = false
    @ObservationIgnored private var makeServices: (() -> UnifiedSearchProductionServices)?
    @ObservationIgnored private var observer: NSObjectProtocol?
    /// 构造入口；只有测试替换它来模拟装配失败，正式版恒为唯一装配点。
    @ObservationIgnored var assemble: (UnifiedSearchProductionServices, CommandHandoffCoordinator?)
        -> Result<UnifiedSearchProductionAssembly, Error> = { UnifiedSearchProductionAssembly.attempt(services: $0, coordinator: $1) }

    /// 正式版由 AppDelegate 在 application 分支调用一次；测试可以构造自己的实例并注入 fake 服务。
    func start(center: NotificationCenter = .default, makeServices: @escaping () -> UnifiedSearchProductionServices) {
        self.makeServices = makeServices
        if let observer { center.removeObserver(observer) }
        observer = center.addObserver(forName: .appPreferencesDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.retryIfNeeded() }
        }
        retryIfNeeded()
    }

    /// 还没有装配时（首次启动或上次失败）建立装配；已有装配时什么也不做。
    func retryIfNeeded() {
        guard assembly == nil, let makeServices else { return }
        assembly = try? assemble(makeServices(), nil).get()
        assemblyFailed = assembly == nil
        guard let assembly else { return }
        // 工作台已打开时接上新搜索：按协调者当前查询决定是否显示结果，不把空查询当成搜索页。
        assembly.services.navigation.searchPresentation =
            (try? assembly.coordinator.host(UnifiedSearchProductionAssembly.workspaceHost).session.query.showsResults) ?? false
        generation &+= 1
    }

    func controller(for hostID: String) -> UnifiedSearchController? { assembly?.controller(for: hostID) }

    /// 只供测试收尾：停止观察并销毁装配。
    func stop(center: NotificationCenter = .default) {
        if let observer { center.removeObserver(observer) }
        observer = nil
        assembly?.discard()
        assembly = nil
        assemblyFailed = false
        makeServices = nil
    }
}
