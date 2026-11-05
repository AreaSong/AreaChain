import AppKit
import Observation
import SwiftUI

/// 全应用独立窗口注册表：统一管理存活窗口、最近激活窗口、Dock 激活策略与多维度窗口查找。
@MainActor
@Observable
final class WindowRegistry {
    static let shared = WindowRegistry()
    static let windowDidResignKeyNotification = Notification.Name("AreaChain.BaseWindowDidResignKey")

    private(set) var windows: [BaseWindow] = []
    private(set) var lastActivatedWindowID: String?
    private(set) var lastResignedWindowID: String?
    private(set) var currentActivationPolicy: NSApplication.ActivationPolicy = .accessory
    @ObservationIgnored var activationPolicyHandler: (@MainActor (NSApplication.ActivationPolicy) -> Void)?
    @ObservationIgnored var ordersFrontOnOpen: Bool = true

    init(
        activationPolicyHandler: (@MainActor (NSApplication.ActivationPolicy) -> Void)? = nil
    ) {
        self.activationPolicyHandler = activationPolicyHandler
    }

    /// 当前处于打开或可见状态的受管窗口列表。
    var openWindows: [BaseWindow] {
        windows.filter { window in
            if let hosted = window.hostedWindow {
                return window.isOpen || hosted.isVisible || hosted.isMiniaturized
            }
            return window.isOpen
        }
    }

    /// 当前最近激活的存活窗口；若无记录则回退到最后注册的窗口。
    var lastActivatedWindow: BaseWindow? {
        if let activeID = lastActivatedWindowID,
           let matched = windows.first(where: { $0.windowID == activeID }) {
            return matched
        }
        return windows.last
    }

    func register(_ window: BaseWindow) {
        if let index = windows.firstIndex(where: { $0 === window || $0.windowID == window.windowID }) {
            windows[index] = window
        } else {
            windows.append(window)
        }
        if lastActivatedWindowID == nil {
            lastActivatedWindowID = window.windowID
        }
        updateActivationPolicy()
    }

    func unregister(_ window: BaseWindow) {
        windows.removeAll { $0 === window || $0.windowID == window.windowID }
        if lastActivatedWindowID == window.windowID {
            lastActivatedWindowID = windows.last?.windowID
        }
        updateActivationPolicy()
    }

    func markActivated(_ window: BaseWindow) {
        register(window)
        lastActivatedWindowID = window.windowID
        updateActivationPolicy()
    }

    func notifyWindowDidResignKey(_ window: BaseWindow) {
        lastResignedWindowID = window.windowID
        NotificationCenter.default.post(
            name: Self.windowDidResignKeyNotification,
            object: window,
            userInfo: [
                "windowID": window.windowID,
                "category": window.windowCategory
            ]
        )
    }

    /// 当存在打开的独立窗口时切换为 .regular 显示 Dock 图标，全部关闭后自动回退为 .accessory。
    func updateActivationPolicy() {
        let hasOpenWindow = windows.contains { $0.isOpen }
        let nextPolicy: NSApplication.ActivationPolicy = hasOpenWindow ? .regular : .accessory
        currentActivationPolicy = nextPolicy
        activationPolicyHandler?(nextPolicy)
    }

    /// 按 windowID、窗口类型、标题关键词或 1 基序号查找目标窗口；不传参取最近激活窗口，传 "all" 批量匹配。
    func resolveWindows(target: String? = nil, category: String? = nil) -> [BaseWindow] {
        let candidates: [BaseWindow]
        if let category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidates = windows.filter { Self.matchesCategory($0.windowCategory, query: category) }
        } else {
            candidates = windows
        }
        guard !candidates.isEmpty else { return [] }

        let query = target?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if query.isEmpty {
            if let activeID = lastActivatedWindowID,
               let activeMatch = candidates.first(where: { $0.windowID == activeID }) {
                return [activeMatch]
            }
            return candidates.last.map { [$0] } ?? []
        }

        let lowered = query.lowercased()
        if lowered == "all" || query == "*" || query == "全部" {
            return candidates
        }

        if let exactID = candidates.first(where: { $0.windowID.caseInsensitiveCompare(query) == .orderedSame }) {
            return [exactID]
        }

        let indexToken = query.hasPrefix("#") ? String(query.dropFirst()) : query
        if let oneBasedIndex = Int(indexToken), oneBasedIndex >= 1, oneBasedIndex <= candidates.count {
            return [candidates[oneBasedIndex - 1]]
        }

        if category == nil {
            let categoryMatches = candidates.filter { Self.matchesCategory($0.windowCategory, query: query) }
            if !categoryMatches.isEmpty {
                return categoryMatches
            }
        }

        return candidates.filter { $0.windowTitle.localizedCaseInsensitiveContains(query) }
    }

    func findWindow(target: String? = nil, category: String? = nil) -> BaseWindow? {
        resolveWindows(target: target, category: category).first
    }

    func window(forID id: String) -> BaseWindow? {
        windows.first { $0.windowID.caseInsensitiveCompare(id) == .orderedSame }
    }

    func windows(inCategory category: String) -> [BaseWindow] {
        windows.filter { Self.matchesCategory($0.windowCategory, query: category) }
    }

    private static func matchesCategory(_ windowCategory: String, query: String) -> Bool {
        if windowCategory.caseInsensitiveCompare(query) == .orderedSame { return true }
        let lowerCategory = windowCategory.lowercased()
        let lowerQuery = query.lowercased()
        if lowerQuery == "quick" && lowerCategory == "quickentry" { return true }
        if lowerQuery == "preview" && lowerCategory == "controlspreview" { return true }
        if lowerQuery == "viewer" && lowerCategory == "attachmentviewer" { return true }
        return false
    }

    @discardableResult
    func closeWindows(target: String? = nil, category: String? = nil, force: Bool = false) -> Int {
        let targets = resolveWindows(target: target, category: category)
        var closedCount = 0
        for window in targets where window.closeWindow(force: force) {
            closedCount += 1
        }
        return closedCount
    }

    @discardableResult
    func setPinned(_ pinned: Bool, target: String? = nil, category: String? = nil) -> Int {
        let targets = resolveWindows(target: target, category: category)
        var updated = 0
        for window in targets where window.supportsPinning {
            window.setPinned(pinned)
            updated += 1
        }
        return updated
    }

    func reset() {
        let snapshot = windows
        for window in snapshot {
            _ = window.closeWindow(force: true)
        }
        windows.removeAll()
        lastActivatedWindowID = nil
        lastResignedWindowID = nil
        updateActivationPolicy()
    }
}

/// 全软件所有独立窗口（三栏工作台、手记小窗、剪贴板小窗、极速速记窗、图片查看窗、控件预览窗）的唯一窗体基类。
@MainActor
class BaseWindow: NSObject, NSWindowDelegate {
    let registry: WindowRegistry
    private(set) var hostedWindow: NSWindow?
    private(set) var isPinned: Bool = false
    private(set) var isOpen: Bool = false
    private var isClosingInternally = false
    private var createdByBaseOpenWindow = false

    init(registry: WindowRegistry? = nil) {
        let resolvedRegistry = registry ?? .shared
        self.registry = resolvedRegistry
        super.init()
        resolvedRegistry.register(self)
    }

    // MARK: - 子类可重载属性与契约

    var windowID: String {
        "window.base.\(ObjectIdentifier(self).hashValue)"
    }

    var windowCategory: String {
        "general"
    }

    var windowTitle: String {
        ""
    }

    var defaultSize: NSSize {
        NSSize(width: 480, height: 360)
    }

    var minSize: NSSize {
        NSSize(width: 320, height: 240)
    }

    var defaultContentSize: NSSize {
        defaultSize
    }

    var minimumContentSize: NSSize {
        minSize
    }

    var supportsPinning: Bool {
        true
    }

    var styleMask: NSWindow.StyleMask {
        [.titled, .closable, .miniaturizable, .resizable]
    }

    func hasUnsavedChanges() -> Bool {
        false
    }

    func confirmCloseIfUnsaved() -> Bool {
        true
    }

    func makeRootView() -> AnyView {
        AnyView(EmptyView())
    }

    // MARK: - 宿主窗口挂载与卸载

    func attachHostedWindow(_ window: NSWindow?) {
        createdByBaseOpenWindow = false
        hostedWindow = window
        isOpen = window != nil
        registry.register(self)
    }

    func detachHostedWindow() {
        hostedWindow = nil
        isOpen = false
        isPinned = false
        registry.updateActivationPolicy()
    }

    func markWindowClosedInRegistry() {
        isOpen = false
        registry.updateActivationPolicy()
    }

    // MARK: - 基类统一窗口操作

    func openWindow() {
        let isCreating = hostedWindow == nil
        if isCreating {
            createdByBaseOpenWindow = true
            let clampedInitialSize = NSSize(
                width: max(defaultContentSize.width, minimumContentSize.width),
                height: max(defaultContentSize.height, minimumContentSize.height)
            )
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: clampedInitialSize),
                styleMask: styleMask,
                backing: .buffered,
                defer: false
            )
            window.identifier = NSUserInterfaceItemIdentifier(windowID)
            window.minSize = minimumContentSize
            window.contentMinSize = minimumContentSize
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.delegate = self
            window.level = (supportsPinning && isPinned) ? .floating : .normal
            let hosting = NSHostingController(rootView: makeRootView())
            hosting.sizingOptions = []
            window.contentViewController = hosting
            window.setContentSize(clampedInitialSize)
            hostedWindow = window
            centerOnActiveScreen()
        }
        syncWindowChrome()
        isOpen = true
        registry.markActivated(self)
        guard let window = hostedWindow else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        if registry.ordersFrontOnOpen {
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderBack(nil)
        }
    }

    @discardableResult
    func closeWindow(force: Bool = false) -> Bool {
        if !force && hasUnsavedChanges() {
            guard confirmCloseIfUnsaved() else { return false }
        }
        isClosingInternally = true
        defer { isClosingInternally = false }
        if let window = hostedWindow {
            if createdByBaseOpenWindow {
                tearDownHostedWindow(window)
            }
            window.orderOut(nil)
        }
        if createdByBaseOpenWindow {
            hostedWindow = nil
            registry.unregister(self)
        }
        isOpen = false
        isPinned = false
        registry.updateActivationPolicy()
        return true
    }

    func setPinned(_ pinned: Bool) {
        guard supportsPinning else {
            isPinned = false
            hostedWindow?.level = .normal
            return
        }
        isPinned = pinned
        hostedWindow?.level = pinned ? .floating : .normal
    }

    @discardableResult
    func togglePin() -> Bool {
        setPinned(!isPinned)
        return isPinned
    }

    func resize(width: CGFloat, height: CGFloat) {
        let clamped = NSSize(
            width: max(width, minimumContentSize.width),
            height: max(height, minimumContentSize.height)
        )
        hostedWindow?.minSize = minimumContentSize
        hostedWindow?.contentMinSize = minimumContentSize
        hostedWindow?.setContentSize(clamped)
    }

    func centerOnActiveScreen() {
        guard let window = hostedWindow else { return }
        AppWindows.centerWindow(window, size: window.frame.size)
    }

    func syncWindowChrome() {
        guard let window = hostedWindow else { return }
        window.title = windowTitle
        window.minSize = minimumContentSize
        window.contentMinSize = minimumContentSize
        window.isDocumentEdited = hasUnsavedChanges()
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if hasUnsavedChanges() {
            return confirmCloseIfUnsaved()
        }
        return true
    }

    func windowDidBecomeKey(_ notification: Notification) {
        registry.markActivated(self)
    }

    func windowDidResignKey(_ notification: Notification) {
        registry.notifyWindowDidResignKey(self)
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosingInternally else { return }
        if createdByBaseOpenWindow {
            if let closing = notification.object as? NSWindow, closing === hostedWindow {
                tearDownHostedWindow(closing)
            }
            hostedWindow = nil
            registry.unregister(self)
        }
        isOpen = false
        isPinned = false
        registry.updateActivationPolicy()
    }

    private func tearDownHostedWindow(_ window: NSWindow) {
        window.makeFirstResponder(nil)
        if let host = window.contentViewController as? NSHostingController<AnyView> {
            host.rootView = AnyView(EmptyView())
            host.view.layoutSubtreeIfNeeded()
        }
        window.contentViewController = nil
        window.contentView = nil
        window.delegate = nil
    }
}
