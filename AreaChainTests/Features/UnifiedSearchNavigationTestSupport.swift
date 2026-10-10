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
    var saves = 0
    var publications = 0
    private var observers: [NSObjectProtocol] = []
    var window: NSWindow?
    var context: ModelContext { data.context }
    let day = "2026-10-07"

    init(handoff provided: HandoffFixture? = nil) throws {
        data = try TaskContentQueryFixture()
        todo = data.todo("needle parent")
        todo.dayKey = day
        child = data.child(todo, title: "needle child")
        routine = DailyRoutine(title: "needle routine", sortOrder: 0, createdDayKey: "2026-09-01")
        data.context.insert(routine)
        try data.context.save()
        handoff = try provided ?? HandoffFixture(sourcePage: .overview)
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
        observers.append(NotificationCenter.default.addObserver(forName: ModelContext.willSave,
            object: data.context, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.saves += 1 } })
        observers.append(NotificationCenter.default.addObserver(forName: .privacyWillLock,
            object: vault, queue: .main) { [weak self] note in
                MainActor.assumeIsolated { self?.privacy.post(name: note.name, object: note.object) }
            })
        observers.append(model.addObserver(forName: .boardDidChange, object: nil,
            queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.publications += 1 } })
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

    func start(style: Int = 0, controller external: UnifiedSearchController? = nil, unified: Bool = true,
               attachments: AttachmentStore? = nil) async throws {
        if let external {
            controller = external
            external.navigationRouter = router
            try external.session.resumeDisplay(expecting: external.buffer.lease)
            _ = try await external.readObjectSource()
        } else { _ = try await read() }
        var host = hostContext
        host.attachments = attachments
        let root = MainSplitWorkspaceView(navigation: navigation, search: unified ? controller : nil, hostContext: host)
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
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.minSize = DaybookMetrics.Window.workspaceMinSize
        if style >= 2 { window.setFrame(NSRect(origin: .zero, size: DaybookMetrics.Window.workspaceMinSize), display: true) }
        window.appearance = NSAppearance(named: style % 2 == 1 ? .darkAqua : .aqua)
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        self.window = window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await settle()
    }

    var field: NSTextField {
        get throws {
            try #require(SettingsButtonTestSupport.elements(window?.contentView).compactMap { $0 as? NSTextField }
                .first { $0.cell is UnifiedSearchFieldCell })
        }
    }
    var editor: NSTextView { get throws { try #require(try field.currentEditor() as? NSTextView) } }
    func typeNative(_ text: String) async throws {
        controller.inputFocused = true
        window?.makeFirstResponder(try field)
        try await settle()
        let editor = try editor
        editor.insertText(text, replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await settle()
    }
    func key(_ code: UInt16, _ text: String, flags: NSEvent.ModifierFlags = []) async throws {
        let window = try #require(window)
        try #require(window.isKeyWindow)
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
        NSApp.sendEvent(event)
        try await settle()
    }
    func click(_ id: String) async throws {
        let window = try #require(window)
        let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id
        })
        try await SettingsButtonTestSupport.reveal(node, in: window)
        try await SettingsButtonTestSupport.click(node, in: window)
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
        try #require(page.snapshot.visible.contains(object))
        controller.browse(.init(version: page.snapshot.version, action: .activate(object)), source: controller.buffer)
        controller.browse(.init(version: page.snapshot.version, action: .open(inputEditing: false)), source: controller.buffer)
        await controller.navigationTask?.value
        try await settle()
    }
    func snapshot(_ name: String) async throws {
        let view = try #require(window?.contentView)
        view.layoutSubtreeIfNeeded()
        let image = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: image)
        let png = try #require(image.representation(using: .png, properties: [:]))
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-NM1-QA")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try png.write(to: root.appending(path: name + ".png"))
        print("NM1_SCREENSHOT " + root.appending(path: name + ".png").path)
        if navigation.isInspectorPresented {
            // 系统 inspector 的整窗缓存是材质占位；同一真实抽屉另作原生内容证据，不冒充系统窗口截图。
            let detailRoot = TaskDetailDrawer(taskID: Binding(get: { self.navigation.selectedTaskID }, set: { self.navigation.selectedTaskID = $0 }))
                .modelContainer(data.container).environment(\.modelContext, context).environment(prefs)
                .environment(\.workspaceHostContext, hostContext)
                .environment(\.locale, Locale(identifier: "en"))
                .preferredColorScheme(.light)
            let detailWindow = NSWindow(contentViewController: NSHostingController(rootView: detailRoot))
            detailWindow.isReleasedWhenClosed = false
            detailWindow.setContentSize(NSSize(width: 360, height: 800))
            detailWindow.orderFront(nil)
            try await SystemPageHost.settle(detailWindow)
            let actual = try #require(detailWindow.contentView)
            let detail = try #require(actual.bitmapImageRepForCachingDisplay(in: actual.bounds))
            actual.cacheDisplay(in: actual.bounds, to: detail)
            let bytes = try #require(detail.representation(using: .png, properties: [:]))
            try bytes.write(to: root.appending(path: name + "-inspector.png"))
            detailWindow.orderOut(nil)
            detailWindow.contentViewController = nil
        }
    }

    func stop() {
        controller.detach()
        session.detach()
        if let window {
            window.makeFirstResponder(nil)
            window.orderOut(nil)
            window.styleMask.remove(.fullSizeContentView)
            window.contentViewController = nil
        }
        window = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer); model.removeObserver(observer) }
        observers = []
    }
}
