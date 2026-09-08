import AppKit
import SwiftData
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var container: ModelContainer?
    private var didAttach = false

    func attach(container: ModelContainer) {
        self.container = container
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.image = NSImage(systemSymbolName: "book.closed.fill", accessibilityDescription: "AreaChain")
            item.button?.imagePosition = .imageLeading
            item.button?.target = self
            item.button?.action = #selector(toggle)
            statusItem = item
        }
        if popover == nil {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
            popover.contentSize = DaybookTheme.popoverSize
            self.popover = popover
        }
        refreshCount()
        guard !didAttach else { return }
        didAttach = true
        NotificationCenter.default.addObserver(
            forName: .toggleBoardPopover,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.toggle()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .boardDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCount()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .appPreferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCount()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                DayClock.shared.refresh()
                self?.refreshCount()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .pasteClipboardCapture,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let container = self?.container else { return }
                ClipboardCapture.ingest(container: container)
            }
        }
    }

    private(set) var lastKnownHeight: CGFloat = DaybookTheme.popoverHeight

    func updatePopoverHeight(_ newHeight: CGFloat) {
        guard let popover, popover.isShown else { return }
        if abs(popover.contentSize.height - DaybookTheme.popoverHeight) > 1 {
            popover.contentSize = DaybookTheme.popoverSize
        }
    }

    func close() {
        popover?.performClose(nil)
    }

    @objc func toggle() {
        guard let button = statusItem?.button, let popover, let container else { return }
        if popover.isShown {
            close()
            return
        }
        let hosting = NSHostingController(
            rootView: MenuBarPopoverView()
                .appChrome()
                .modelContainer(container)
        )
        hosting.safeAreaRegions = []
        let fitting = hosting.view.fittingSize
        let initialHeight = min(
            max(fitting.height > 0 ? fitting.height : lastKnownHeight, DaybookTheme.popoverMinHeight),
            DaybookTheme.popoverMaxHeight
        )
        lastKnownHeight = initialHeight
        popover.contentSize = NSSize(
            width: DaybookTheme.popoverWidth,
            height: initialHeight
        )
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
        button.title = count > 0 ? "今\(count)" : "今"
        let locale = AppPreferences.shared.resolvedLocale
        button.toolTip = count > 0
            ? L10n.string("a11y.app.remaining \(count)", locale: locale)
            : L10n.string("a11y.app", locale: locale)
    }
}
