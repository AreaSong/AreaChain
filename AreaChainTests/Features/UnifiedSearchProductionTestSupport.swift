import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-6：唯一装配点的测试输入。与正式版走同一份 UnifiedSearchProductionAssembly，只是参数不同：
/// 内存容器（mainContext，保持自动保存，与正式版同形）、私有事件中心、隔离保险箱、临时附件与剪贴板目录、计数 fake 副作用。
/// 不读写真实用户库、真实附件目录、真实剪贴板历史或真实钥匙串；不发系统授权。
@MainActor final class ProductionEffectsProbe {
    var refreshes: [Bool] = []
    var reminderRequests: [Int?] = []
    var calendarRefreshes = 0
    var reveals = 0
    var copied: [String] = []
    var clipboardActions: ClipboardHistoryActions?
    var system: WorkspaceSystemCommands?
    var total: Int {
        refreshes.count + reminderRequests.count + calendarRefreshes + reveals + copied.count
    }

    final class Writer: ClipboardTextWriting {
        weak var probe: ProductionEffectsProbe?
        func write(_ text: String) throws { probe?.copied.append(text) }
    }
    let writer = Writer()

    var effects: UnifiedSearchProductionEffects {
        writer.probe = self
        return .init(refresh: { [unowned self] in refreshes.append($0) }, calendarSyncEnabled: { false },
                     requestReminderAccess: { [unowned self] in reminderRequests.append($0) },
                     refreshCalendar: { [unowned self] in calendarRefreshes += 1 }, clipboardWriter: writer,
                     // 两个工厂在装配时取一次（构造依赖、不调用系统）；用例需要时注入自己的 fake。
                     clipboardActions: { [unowned self] in clipboardActions }, system: { [unowned self] in system },
                     sourceBundleID: { "com.areachain.m6.test" }, revealWorkspace: { [unowned self] in reveals += 1 })
    }
}

@MainActor final class UnifiedSearchProductionFixture {
    /// 与 N-M1 夹具同理：视图图可能比夹具活得久，容器保活到进程结束。
    private static var retainedContainers: [ModelContainer] = []
    static let today = "2026-10-22"
    let container: ModelContainer
    let center = NotificationCenter()
    let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
    let defaults: UserDefaults
    let preferences: AppPreferences
    let navigation: WorkspaceNavigation
    let probe = ProductionEffectsProbe()
    let root: URL
    let clipboard: ClipboardHistorySession
    let shortcuts: ShortcutStore
    var saves = 0
    private var observers: [NSObjectProtocol] = []
    var context: ModelContext { container.mainContext }

    /// container 为 nil 时新建内存容器；原生测试可传入自己的内存容器，让页面与统一搜索共用同一 mainContext（与正式版同形）。
    /// navigation 为 nil 时用独立导航；挂在 `.shared` 工作台上的旧测试传 `.shared`，让结果页的展示状态写到同一导航。
    init(container existing: ModelContainer? = nil, navigation: WorkspaceNavigation? = nil) throws {
        self.navigation = navigation ?? WorkspaceNavigation(boardSelection: BoardSelection())
        container = try existing ?? ModelContainer(for: Schema(AreaChainSchema.models),
                                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        Self.retainedContainers.append(container)
        defaults = try #require(UserDefaults(suiteName: "AreaChain.M6." + UUID().uuidString))
        preferences = AppPreferences(defaults: defaults)
        root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-M6-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        clipboard = ClipboardHistorySession(store: .init(root: root.appending(path: "clipboard-session")), defaults: defaults,
            pasteboard: nil, gate: .init(isTrusted: { false }, prompt: {}, sendCommandV: {}))
        shortcuts = ShortcutStore(defaults: defaults, center: HotKeyCenter(defaults: defaults,
            registration: .init(register: { _, _ in false }, unregister: { _ in })))
        observers.append(NotificationCenter.default.addObserver(forName: ModelContext.willSave, object: container.mainContext,
            queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.saves += 1 } })
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    func services(productionAttachments: Bool = false) -> UnifiedSearchProductionServices {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return .init(context: context, center: center, vault: vault, preferences: preferences, navigation: navigation,
                     drafts: EditDrafts(), filters: BoardFilterSession(), clipboard: clipboard,
                     clipboardStore: ClipboardHistoryStore(root: root.appending(path: "clipboard")), shortcuts: shortcuts,
                     attachments: AttachmentStore(keys: VaultKeyAccess(), root: root.appending(path: "attachments")),
                     attachmentRoot: root.appending(path: "attachments"),
                     pasteboard: NSPasteboard(name: .init("AreaChain.M6." + UUID().uuidString)),
                     productionAttachments: productionAttachments,
                     calendar: calendar, now: { DayKey.date(dayKey: Self.today, minutes: 720, calendar: calendar)! },
                     today: { Self.today }, effects: probe.effects)
    }

    func assembly() throws -> UnifiedSearchProductionAssembly {
        try UnifiedSearchProductionAssembly.attempt(services: services()).get()
    }

    @discardableResult func insert<T: PersistentModel>(_ model: T) throws -> T {
        context.insert(model)
        try context.save()
        return model
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

/// 收尾批 M-7：旧底栏搜索删除后，菜单栏原生测试经同一唯一装配挂接统一搜索；装配失败时测试直接失败，不静默退回。
@MainActor final class MenuBarUnifiedSearchProbe {
    let fixture: UnifiedSearchProductionFixture
    let production = UnifiedSearchProduction()

    init(container: ModelContainer) throws {
        fixture = try UnifiedSearchProductionFixture(container: container)
        production.start(center: fixture.center, makeServices: { [fixture] in fixture.services() })
        try #require(production.assembly != nil)
    }

    var controller: UnifiedSearchController {
        get throws { try #require(production.assembly?.menubar) }
    }

    /// 经控制器的原输入事件写入查询（光标在末尾）；非空查询等到首批结果发布，宿主再按“正在搜索”切换中部。
    func type(_ text: String) async throws {
        let controller = try controller
        _ = controller.edit(.init(source: controller.buffer, text: text,
                                  selection: NSRange(location: text.utf16.count, length: 0)))
        guard !text.isEmpty else { return }
        for _ in 0..<100 where (try? controller.session.presentation()) == nil { try await Task.sleep(for: .milliseconds(20)) }
    }

    func stop() {
        production.stop(center: fixture.center)
        fixture.cleanup()
    }
}
