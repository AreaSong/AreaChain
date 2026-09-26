import AppKit
import SwiftData
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let shared = StatusItemController()

    /// 注入的菜单栏浮层视图构造器，由 App 层或 Features 协调层注册
    var popoverViewProvider: (@MainActor () -> AnyView)?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var container: ModelContainer?
    private var didAttach = false
    private var globalEventMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?

    func attach(container: ModelContainer) {
        self.container = container
        setupStatusItemButton()
        setupPopover()
        refreshCount()
        guard !didAttach else { return }
        didAttach = true
        observeBoardEvents()
        observeDayClock()
        observeFocusTimer()
    }

    private func setupStatusItemButton() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: MenuBarStatusImage.itemWidth)
        if let button = item.button {
            MenuBarStatusImage.apply(to: button, status: nil, locale: AppPreferences.shared.resolvedLocale)
        }
        item.button?.target = self
        item.button?.action = #selector(toggle)
        statusItem = item
    }

    private func setupPopover() {
        guard popover == nil else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = DaybookMetrics.Window.popoverSize
        self.popover = popover
    }

    private func observeBoardEvents() {
        let center = NotificationCenter.default
        center.addObserver(forName: .toggleBoardPopover, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.toggle() }
        }
        center.addObserver(forName: .boardDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshCount() }
        }
        center.addObserver(forName: .appPreferencesDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshCount() }
        }
        center.addObserver(forName: .pasteClipboardCapture, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let container = self?.container else { return }
                ClipboardCapture.ingest(container: container)
            }
        }
    }

    private func observeDayClock() {
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                DayClock.shared.refresh()
                self?.refreshCount()
            }
        }
    }

    private func observeFocusTimer() {
        NotificationCenter.default.addObserver(forName: .focusTimerDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCount()
            }
        }
    }

    func close() {
        popover?.performClose(nil)
        stopDismissMonitors()
    }

    @objc func toggle() {
        guard let button = statusItem?.button, let popover, container != nil else { return }
        if popover.isShown {
            close()
            return
        }
        guard let provider = popoverViewProvider else {
            assertionFailure("StatusItemController.popoverViewProvider must be registered before toggle()")
            return
        }
        let hosting = NSHostingController(rootView: provider())
        hosting.safeAreaRegions = []
        hosting.view.frame = NSRect(origin: .zero, size: DaybookMetrics.Window.popoverSize)
        popover.contentSize = DaybookMetrics.Window.popoverSize
        popover.contentViewController = hosting
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startDismissMonitors()
        NotificationCenter.default.post(name: .focusCapture, object: nil)
    }

    func popoverDidClose(_ notification: Notification) {
        stopDismissMonitors()
        refreshCount()
    }

    private func startDismissMonitors() {
        stopDismissMonitors()

        // 1. 全局监听屏幕任意外部区域的点击（桌面、其他 App 窗口等），点击即自动收起
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let popover = self.popover, popover.isShown else { return }
            // 若点击落在状态栏按钮本身，交由按钮自己的 action 处理，避免与 toggle 循环冲突
            if let button = self.statusItem?.button, let window = button.window {
                let mouseLocation = NSEvent.mouseLocation
                let buttonScreenRect = window.convertToScreen(button.bounds)
                if buttonScreenRect.contains(mouseLocation) {
                    return
                }
            }
            Task { @MainActor in
                self.close()
            }
        }

        // 2. 监听应用失去激活状态（如切换应用），自动收起
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.close()
            }
        }
    }

    private func stopDismissMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            resignActiveObserver = nil
        }
    }

    private func refreshCount() {
        guard let container, let button = statusItem?.button else { return }
        let context = container.mainContext
        guard let routines = try? context.fetch(FetchDescriptor<DailyRoutine>()),
              let todos = try? context.fetch(FetchDescriptor<TodoItem>()),
              let checks = try? context.fetch(FetchDescriptor<RoutineCheck>()) else {
            MutationFeedback.shared.reportFailure()
            return
        }
        let status = MenuBarStatus.forDay(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: DayClock.shared.todayKey
        )
        let locale = AppPreferences.shared.resolvedLocale
        MenuBarStatusImage.apply(to: button, status: status, locale: locale)
    }
}
