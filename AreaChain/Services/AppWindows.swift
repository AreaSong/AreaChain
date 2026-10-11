import AppKit
import SwiftUI

@MainActor
enum AppWindows {
    /// 注入的工作台主视图构造器，由 App 启动时或 Features 协调层注册
    static var workspaceViewProvider: (@MainActor () -> AnyView)?
    static var diaryWindowsProvider: (@MainActor () -> [NSWindow])?
    /// 剪贴板小窗。关工作台时不能把它当成杂散窗口关掉。
    static var clipboardWindowProvider: (@MainActor () -> [NSWindow])?

    /// 测试替换这两处，避免为路由断言激活应用或创建窗口。
    static var activateForOpening: @MainActor () -> Void = { becomeActive() }
    static var showWorkspaceWindow: @MainActor () -> Void = { PanelWindowController.workspace.show() }

    @MainActor struct WorkspaceOpening {
        let navigation: WorkspaceNavigation
        var dismissOverlay: () -> Void
        var activate: () -> Void
        var show: () -> Void

        static var live: Self {
            .init(navigation: .shared, dismissOverlay: { StatusItemController.shared.close() },
                  activate: activateForOpening, show: showWorkspaceWindow)
        }
    }

    static func openWorkspace(tab: WorkspaceTab = .dashboard, inspecting taskID: UUID? = nil, dayKey: String? = nil,
                              opening: WorkspaceOpening? = nil) {
        let opening = opening ?? .live
        opening.dismissOverlay()
        opening.activate()
        opening.navigation.revealTab(tab, inspecting: taskID, dayKey: dayKey)
        opening.show()
    }

    /// 应用菜单、⌘, 和浮层「设置」都进入工作台设置页。
    static func openSettings(opening: WorkspaceOpening? = nil) {
        openWorkspace(tab: .settings, opening: opening)
    }

    static func openControlsPreview(localeID: String, dark: Bool) {
        activateForOpening()
        ControlsPreviewWindowController.shared.show(localeID: localeID, dark: dark)
    }

    static func revealWorkspace(opening: WorkspaceOpening? = nil) {
        let opening = opening ?? .live
        opening.dismissOverlay()
        opening.activate()
        opening.show()
    }

    static func openDiary() {
        openWorkspace(tab: .diary)
    }

    static func openCalendar() {
        openWorkspace(tab: .calendar)
    }

    static func becomeActive() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func resignIfIdle(closing: NSWindow? = nil) {
        hideStrayWindows(closing: closing)
        let leftover = panelWindows.contains { window in
            window !== closing && (window.isVisible || window.isMiniaturized)
        }
        if !leftover {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// 登记窗口以外的可见窗口不要当成「下一扇」留在前台。
    static func hideStrayWindows(closing: NSWindow? = nil) {
        let panels = Set(panelWindows.map { ObjectIdentifier($0) })
        for window in NSApp.windows {
            if window === closing { continue }
            if panels.contains(ObjectIdentifier(window)) { continue }
            guard window.canBecomeKey, window.level == .normal, window.isVisible else { continue }
            window.orderOut(nil)
        }
    }

    private static var panelWindows: [NSWindow] {
        [PanelWindowController.workspace.hostedWindow,
         ControlsPreviewWindowController.shared.hostedWindow].compactMap { $0 }
            + (diaryWindowsProvider?() ?? [])
            + (clipboardWindowProvider?() ?? [])
    }
}

@MainActor
final class PanelWindowController: NSObject, NSWindowDelegate {
    static let workspace = PanelWindowController(
        titleKey: "window.workspace",
        size: DaybookMetrics.Window.workspaceSize,
        minSize: DaybookMetrics.Window.workspaceMinSize,
        root: {
            AppWindows.workspaceViewProvider?() ?? AnyView(EmptyView())
        }
    )

    private let titleKey: String
    private let size: NSSize
    private let minSize: NSSize?
    private let root: @MainActor () -> AnyView
    private var window: NSWindow?
    private var preferenceObservation: PreferenceObservation?

    var hostedWindow: NSWindow? { window }

    init(
        titleKey: String,
        size: NSSize,
        minSize: NSSize? = nil,
        root: @escaping @MainActor () -> AnyView
    ) {
        self.titleKey = titleKey
        self.size = size
        self.minSize = minSize
        self.root = root
        super.init()
        preferenceObservation = PreferenceObservation(preferences: AppPreferences.shared,
            consumer: .windowChrome, presentation: { [weak self] in self?.refreshChrome() },
            legacy: { [weak self] in self?.refreshChrome() })
    }

    func show() {
        if window == nil {
            guard let provider = AppWindows.workspaceViewProvider else {
                assertionFailure("AppWindows.workspaceViewProvider must be registered before showing workspace")
                return
            }
            let hosting = NSHostingController(rootView: provider())
            let next = WorkspacePanelWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            next.contentViewController = hosting
            next.setContentSize(size)
            next.minSize = minSize ?? size
            next.titlebarAppearsTransparent = true
            next.titleVisibility = .hidden
            next.titlebarSeparatorStyle = .none
            next.toolbarStyle = .unified
            let toolbar = NSToolbar(identifier: "AreaChainWorkspaceToolbar")
            toolbar.showsBaselineSeparator = false
            next.toolbar = toolbar
            next.isMovableByWindowBackground = true
            next.isReleasedWhenClosed = false
            next.isRestorable = false
            next.delegate = self
            window = next
        }
        refreshChrome()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        AppWindows.resignIfIdle(closing: closing)
        DispatchQueue.main.async {
            AppWindows.resignIfIdle(closing: closing)
        }
    }

    private func refreshChrome() {
        window?.title = ""
        window?.titleVisibility = .hidden
    }
}

/// 支持通顶全尺寸内容视图（fullSizeContentView）下双击顶部 50pt 栏缩放/填满窗口
private final class WorkspacePanelWindow: NSWindow {
    private static let interactiveAnchorIDs: Set<String> = [
        "syntax.workspace.search.bounds",
        "syntax.workspace.actions.bounds",
        "syntax.workspace.help.bounds"
    ]

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, event.clickCount == 2,
           shouldZoomOnTitlebarDoubleClick(at: event.locationInWindow) {
            performTitlebarDoubleClickAction()
            return
        }
        super.sendEvent(event)
    }

    private func shouldZoomOnTitlebarDoubleClick(at point: NSPoint) -> Bool {
        guard let contentView else { return false }
        let distanceFromTop = contentView.bounds.height - point.y
        guard distanceFromTop >= 0, distanceFromTop <= 50 else { return false }
        // 避开左上角系统红绿灯按钮区域
        if point.x < 96 && distanceFromTop < 42 { return false }
        // 避开原生输入框与按钮控件
        if let hitView = contentView.hitTest(point), Self.isInteractiveAppKitControl(hitView) {
            return false
        }
        // 避开顶栏中的搜索区、右侧功能按钮区与帮助按钮
        if Self.hitsInteractiveAnchor(in: contentView, windowPoint: point) {
            return false
        }
        return true
    }

    private static func isInteractiveAppKitControl(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let node = current {
            if node is NSTextField || node is NSTextView || node is NSButton
                || node is NSPopUpButton || node is NSSegmentedControl {
                return true
            }
            current = node.superview
        }
        return false
    }

    private static func hitsInteractiveAnchor(in root: NSView, windowPoint: NSPoint) -> Bool {
        guard let id = root.identifier?.rawValue else {
            return root.subviews.contains { hitsInteractiveAnchor(in: $0, windowPoint: windowPoint) }
        }
        if interactiveAnchorIDs.contains(id) {
            let rectInWindow = root.convert(root.bounds, to: nil)
            if rectInWindow.contains(windowPoint) {
                return true
            }
        }
        return root.subviews.contains { hitsInteractiveAnchor(in: $0, windowPoint: windowPoint) }
    }

    private func performTitlebarDoubleClickAction() {
        let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
        if action == "Minimize" {
            performMiniaturize(nil)
        } else if action != "None" {
            zoom(nil)
        }
    }
}
