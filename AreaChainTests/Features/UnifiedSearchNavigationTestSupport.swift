import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchNavigationFixture {
    let data: TaskContentQueryFixture
    let handoff: HandoffFixture
    let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
    let drafts = EditDrafts()
    let privacy = NotificationCenter()
    let model = NotificationCenter()
    let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
    let todo: TodoItem
    let child: SubtaskItem
    let routine: DailyRoutine
    let session: ContentQueryReadSession
    let prefs: AppPreferences
    let hostContext: WorkspaceHostContext
    let router: WorkspaceSearchRouter
    var controller: UnifiedSearchController!
    var reads = 0
    var allows = true
    var window: NSWindow?
    var context: ModelContext { data.context }
    let day = "2026-10-07"

    init() throws {
        data = try TaskContentQueryFixture()
        todo = data.todo("needle parent")
        todo.dayKey = day
        child = data.child(todo, title: "needle child")
        routine = DailyRoutine(title: "needle routine", sortOrder: 0, createdDayKey: "2026-09-01")
        data.context.insert(routine)
        try data.context.save()
        handoff = try HandoffFixture(sourcePage: .overview)
        try handoff.send(.query(.setInput("needle")))
        session = try ContentQueryReadSession(vault: vault, coordinator: handoff.coordinator,
            ownership: handoff.owned().lease.ownership,
            notifications: .init(privacy: privacy, model: model, focus: NotificationCenter(),
                                 focusLost: Notification.Name("nm1.focus"), focusObject: NSObject()))
        session.install()
        let defaults = try #require(UserDefaults(suiteName: "AreaChain.NM1." + UUID().uuidString))
        prefs = AppPreferences(defaults: defaults)
        let clipboard = ClipboardHistorySession(store: .init(root: FileManager.default.temporaryDirectory
            .appending(path: "AreaChain-NM1-clipboard-" + UUID().uuidString)), defaults: defaults, pasteboard: nil,
            gate: .init(isTrusted: { false }, prompt: {}, sendCommandV: {}))
        let shortcuts = ShortcutStore(defaults: defaults, center: HotKeyCenter(defaults: defaults,
            registration: .init(register: { _, _ in false }, unregister: { _ in })))
        hostContext = .init(navigation: navigation, drafts: drafts, filters: BoardFilterSession(),
                            vault: vault, clipboard: clipboard, shortcuts: shortcuts)
        router = WorkspaceSearchRouter(navigation: navigation,
            objects: WorkspaceObjectNavigation(context: data.context, calendar: .current, allows: { _ in true }))
        controller = UnifiedSearchController(session: session, coordinator: handoff.coordinator,
            buffer: .init(lease: try handoff.owned().lease, version: 0, text: "needle"),
            read: { [weak self] in
                guard let self else { throw WorkspaceOpenFailure.unavailable }
                return try await self.read()
            }, recordOpen: { _ in Issue.record("装配路由不能落到意图通知") })
        controller.navigationRouter = router
    }

    @discardableResult func read() async throws -> ContentQueryReadEffect {
        reads += 1
        let handle = try session.prepare { query in
            var batch = TaskFamilyContentQueryReader(context: context).read(session: query, requestID: UUID(),
                observation: RoutineContentQueryFixture.observation(day)).batch
            batch.facts.metadata = .init(tagNames: [:], privateTagIDs: [])
            batch.facts.routine.scheduleEvidence += [.init(routineID: routine.id,
                interval: .init(lowerBound: day, upperBound: day), rule: .weekdays(WeekdayMask.all),
                source: .synthetic(reference: "nm1-isolated"))]
            return batch
        }
        try session.evaluate(handle)
        return try await session.publish(handle)
    }

    func start(style: Int = 0) async throws {
        _ = try await read()
        let root = MainSplitWorkspaceView(navigation: navigation, search: controller, hostContext: hostContext)
            .modelContainer(data.container).environment(\.modelContext, context).environment(prefs)
            .environment(\.locale, Locale(identifier: style < 2 ? "en" : "zh-Hans"))
            .preferredColorScheme(style % 2 == 1 ? .dark : .light)
            .transaction { $0.disablesAnimations = true }
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(DaybookMetrics.Window.workspaceSize)
        window.minSize = DaybookMetrics.Window.workspaceMinSize
        if style >= 2 { window.setFrame(NSRect(origin: .zero, size: DaybookMetrics.Window.workspaceMinSize), display: true) }
        window.appearance = NSAppearance(named: style % 2 == 1 ? .darkAqua : .aqua)
        self.window = window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await settle()
    }

    func settle() async throws { if let window { try await SystemPageHost.settle(window) } }
    func enter(_ text: String) async throws {
        _ = controller.edit(.init(source: controller.buffer, text: text, selection: .init(location: text.utf16.count, length: 0)))
        try await settle()
    }
    func go(_ path: String) async throws {
        try await enter(path)
        controller.intent(.open, source: controller.buffer)
        await controller.navigationTask?.value
        try await settle()
    }
    func back() async throws {
        let ticket = try #require(controller.returnSearch)
        await controller.returnToSearch(ticket.id)
        try await settle()
    }
    func open(_ object: CommandObjectReference) async throws {
        let page = try session.presentation().pagination
        controller.browse(.init(version: page.snapshot.version, action: .activate(object)), source: controller.buffer)
        controller.browse(.init(version: page.snapshot.version, action: .open(inputEditing: false)), source: controller.buffer)
        await controller.navigationTask?.value
        try await settle()
    }
    func snapshot(_ name: String) throws {
        let view = try #require(window?.contentView)
        view.layoutSubtreeIfNeeded()
        let image = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: image)
        let png = try #require(image.representation(using: .png, properties: [:]))
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-NM1-QA")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try png.write(to: root.appending(path: name + ".png"))
        print("NM1_SCREENSHOT " + root.appending(path: name + ".png").path)
    }
    func stop() {
        controller.detach()
        if let window {
            window.makeFirstResponder(nil)
            window.orderOut(nil)
            window.styleMask.remove(.fullSizeContentView)
            window.contentViewController = nil
        }
        window = nil
    }
}
