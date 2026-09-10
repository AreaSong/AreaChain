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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "book.closed.fill", accessibilityDescription: "AreaChain")
        item.button?.imagePosition = .imageLeading
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
        popover.contentSize = DaybookTheme.popoverSize
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
    }

    @objc func toggle() {
        guard let button = statusItem?.button, let popover, let _ = container else { return }
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
        hosting.view.frame = NSRect(origin: .zero, size: DaybookTheme.popoverSize)
        popover.contentSize = DaybookTheme.popoverSize
        popover.contentViewController = hosting
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NotificationCenter.default.post(name: .focusCapture, object: nil)
    }

    func popoverDidClose(_ notification: Notification) {
        refreshCount()
    }

    private func refreshCount() {
        guard let container, let button = statusItem?.button else { return }
        let context = ModelContext(container)
        let routines = (try? context.fetch(FetchDescriptor<DailyRoutine>())) ?? []
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        let checks = (try? context.fetch(FetchDescriptor<RoutineCheck>())) ?? []
        let count = DayBoardLogic.todayBadgeCount(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: DayClock.shared.todayKey
        )
        let locale = AppPreferences.shared.resolvedLocale
        let mark = L10n.string("menubar.today.mark", locale: locale)
        button.title = count > 0 ? "\(mark)\(count)" : mark
        button.toolTip = count > 0
            ? L10n.string("a11y.app.remaining \(count)", locale: locale)
            : L10n.string("a11y.app", locale: locale)
    }
}
