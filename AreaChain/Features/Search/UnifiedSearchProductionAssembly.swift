import AppKit
import SwiftData

/// 合并批 M-6：正式版统一搜索的系统副作用。全部只在用户执行对应指令时才被调用：
/// 装配、启动和开关切换都不调用其中任何一项，因此不会触发通知、日历或辅助功能授权。
@MainActor struct UnifiedSearchProductionEffects {
    /// 保存成功后的提醒／日历／小组件刷新，与原界面 `BoardEvents.Dependencies.production` 同一路径。
    var refresh: (_ includeCalendar: Bool) -> Void
    var calendarSyncEnabled: () -> Bool
    /// 指令确实设了提醒并保存成功之后才调用；与原界面 `DayBoardMutations.requestReminderAccessIfNeeded` 同一入口。
    var requestReminderAccess: (Int?) -> Void
    /// 待办转习惯后的日历刷新（ItemConversionService 原默认）。
    var refreshCalendar: () -> Void
    var clipboardWriter: any ClipboardTextWriting
    /// 剪贴板历史复制／粘贴（粘贴到其他应用需辅助功能权限，只在执行 clipboard 指令时询问）。
    var clipboardActions: () -> ClipboardHistoryActions?
    /// 窗口、浮层、小窗、退出与立即锁定；nil 表示未装配。
    var system: () -> WorkspaceSystemCommands?
    var sourceBundleID: () -> String
    /// 菜单栏打开结果时先显示工作台（收起浮层、激活、显示同一窗口），再在工作台里打开。
    var revealWorkspace: () -> Void
}

/// 唯一装配点的全部输入。正式版取共享单例（见 UnifiedSearchProduction.liveServices），
/// 测试注入内存容器、隔离保险箱、临时目录与 fake 副作用——两者走同一份装配代码。
@MainActor struct UnifiedSearchProductionServices {
    var context: ModelContext
    /// 事件中心：正式版为 default（原界面监听 boardDidChange、保险箱发锁定事件的同一中心）。
    var center: NotificationCenter
    var vault: PrivacyVault
    var preferences: AppPreferences
    var navigation: WorkspaceNavigation
    var drafts: EditDrafts
    var filters: BoardFilterSession
    var clipboard: ClipboardHistorySession
    var clipboardStore: ClipboardHistoryStore
    var shortcuts: ShortcutStore
    var attachments: AttachmentStore
    var attachmentRoot: URL
    /// 为真时工作台各页附件读写保持原生产语义（共享目录、可解码私密附件），只有统一搜索自己的查阅走普通读取。
    var productionAttachments: Bool
    var calendar: Calendar = .current
    var now: () -> Date = { Date() }
    var today: () -> String
    var effects: UnifiedSearchProductionEffects
}

/// 合并批 M-6：正式版里唯一构造统一搜索（协调者、读取会话、各指令适配器与规格、页面宿主、导航路由、控制器）的地方。
/// check_workflow 的 unified-search-assembly 守卫保证生产代码只在本文件与 +Commands 扩展里构造这些类型。
/// 开关关闭时 `make` 返回 nil，宿主走原有旧搜索；协调者可由上一次装配传入，保留未提交的草稿与计划。
@MainActor final class UnifiedSearchProductionAssembly {
    static let workspaceHost = "workspace"
    static let menubarHost = "menubar"
    let services: UnifiedSearchProductionServices
    let coordinator: CommandHandoffCoordinator
    let router: WorkspaceSearchRouter
    let hostContext: WorkspaceHostContext
    let reads: ContentQueryProductionReads
    private(set) var workspace: UnifiedSearchController!
    private(set) var menubar: UnifiedSearchController!
    private var handoffTask: Task<Void, Never>?
    /// 每个控制器的长文托管；宿主关闭（开关关闭或装配销毁）时逐个 discard。
    private(set) var escrows: [CommandLongTextEscrow] = []
    /// 读取会话的失焦来源：视图自己调用 loseFocus，这里只给出不会被外部投递的私有中心。
    private let focus = NotificationCenter()
    private let focusObject = NSObject()
    private static let focusLost = Notification.Name("areachain.unifiedSearch.production.focusLost")

    static func make(enabled: Bool, services: () -> UnifiedSearchProductionServices,
                     coordinator: CommandHandoffCoordinator? = nil) -> UnifiedSearchProductionAssembly? {
        guard enabled else { return nil }
        return try? UnifiedSearchProductionAssembly(services: services(), coordinator: coordinator)
    }

    init(services: UnifiedSearchProductionServices, coordinator existing: CommandHandoffCoordinator? = nil) throws {
        self.services = services
        coordinator = try existing ?? CommandHandoffCoordinator(pages: [
            services.navigation.queryContext(hostID: Self.workspaceHost, filters: services.filters.filters,
                                             calendar: services.calendar, pendingLane: .overdue),
            Self.menubarPage(services)])
        let objects = WorkspaceObjectNavigation(context: services.context, calendar: services.calendar, allows: { _ in true })
        router = WorkspaceSearchRouter(navigation: services.navigation, objects: objects)
        router.contents = WorkspaceContentSession(reader: .init(
            bodies: ContentQueryBodyReads(context: services.context, ordinaryOnly: true), vault: services.vault,
            attachments: services.attachments, attachmentRoot: services.attachmentRoot, navigation: objects))
        var host = WorkspaceHostContext(navigation: services.navigation, drafts: services.drafts, filters: services.filters,
                                        vault: services.vault, clipboard: services.clipboard, shortcuts: services.shortcuts,
                                        attachments: services.attachments)
        host.sharesProductionStorage = services.productionAttachments
        hostContext = host
        reads = ContentQueryProductionReads(context: services.context, clipboard: services.clipboardStore,
                                            calendar: services.calendar, now: services.now)
        workspace = try makeController(Self.workspaceHost)
        menubar = try makeController(Self.menubarHost)
    }

    static func menubarPage(_ services: UnifiedSearchProductionServices) -> ContentQueryPageContext {
        .init(location: .init(hostID: menubarHost, visitID: UUID().uuidString, reference: menubarHost),
              page: .today(services.filters.filters.tasks), todayKey: services.today(), calendar: services.calendar)
    }

    private func makeController(_ hostID: String) throws -> UnifiedSearchController {
        let owned = try coordinator.host(hostID)
        let session = try ContentQueryReadSession(vault: services.vault, reads: reads, coordinator: coordinator,
            ownership: owned.lease.ownership, notifications: .init(privacy: services.center, model: services.center,
                focus: focus, focusLost: Self.focusLost, focusObject: focusObject))
        session.install()
        let text: String
        if case .content(let content) = owned.session.query.input { text = content.source } else { text = "" }
        let commands = try makeCommands()
        let reads = reads, coordinator = coordinator
        let controller = UnifiedSearchController(session: session, coordinator: coordinator,
            buffer: .init(lease: owned.lease, version: 0, text: text),
            read: { [weak session] in
                guard let session else { throw ContentQueryReadSessionError.detached }
                return try await reads.read(session) { try coordinator.host(hostID).session.query }
            }, recordOpen: { [weak self] open in self?.continueInWorkspace(open) },
            settingBackend: .legacy(commands.settings), taskCreate: commands.taskCreate, taskTitle: commands.taskTitle,
            taskField: commands.taskField, taskChain: commands.taskChain, subtask: commands.subtask,
            routine: commands.routine, batch: commands.batch, multiPlan: commands.multiPlan, trash: commands.trash,
            taskCopy: commands.taskCopy, convert: commands.convert, simple: commands.simple, clipboard: commands.clipboard)
        // 导航路由与页面指令只操作工作台；菜单栏打开结果经 recordOpen 交给工作台（continueInWorkspace）。
        if hostID == Self.workspaceHost {
            controller.navigationRouter = router
            controller.pageCommands = makePageCommands()
        }
        if let escrow = commands.simple?.escrow { escrows.append(escrow) }
        return controller
    }

    /// 宿主关闭：撤销两个控制器的全部预览、读取与订阅，托管丢弃明文；协调者里的未提交草稿保留。
    func discard() {
        handoffTask?.cancel()
        handoffTask = nil
        for controller in [workspace, menubar].compactMap({ $0 }) {
            let ownership = controller.buffer.lease.ownership
            controller.detach()
            for escrow in escrows { escrow.discard(ownership) }
        }
        for escrow in escrows { escrow.revoke() }
        router.contents?.clear()
        services.navigation.searchPresentation = nil
    }

    /// 菜单栏没有工作台路由：先显示工作台，再用同一查询在工作台读取，命中同一对象后沿原导航打开。
    /// 菜单栏浮层随工作台显示而收起，所以不能在菜单栏会话里等待；工作台查询的页面上下文不同时可能不含该对象，此时只停在结果页。
    func continueInWorkspace(_ open: ContentQueryBrowseOpen) {
        guard let menubar else { return }
        let text = menubar.queryInputText
        handoffTask?.cancel()
        services.effects.revealWorkspace()
        handoffTask = Task { @MainActor [weak self] in
            guard let self, let workspace = self.workspace else { return }
            for _ in 0..<100 where self.router.host?.window?.isVisible != true {
                try? await Task.sleep(for: .milliseconds(20))
            }
            guard !Task.isCancelled, workspace.edit(.init(source: workspace.buffer, text: text,
                selection: NSRange(location: text.utf16.count, length: 0))) != nil else { return }
            for _ in 0..<150 where !Task.isCancelled {
                if let page = try? workspace.session.presentation().pagination, page.snapshot.visible.contains(open.object) {
                    workspace.browse(.init(version: page.snapshot.version, action: .activate(open.object)), source: workspace.buffer)
                    workspace.browse(.init(version: page.snapshot.version, action: .open(inputEditing: false)), source: workspace.buffer)
                    return
                }
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
    }

    func controller(for hostID: String) -> UnifiedSearchController? {
        hostID == Self.workspaceHost ? workspace : hostID == Self.menubarHost ? menubar : nil
    }
}
