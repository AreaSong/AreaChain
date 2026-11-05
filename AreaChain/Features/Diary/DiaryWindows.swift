import AppKit
import SwiftData
import SwiftUI

enum DiaryCloseChoice { case save, discard, cancel }

@MainActor
final class DiaryWindows {
    static let shared = DiaryWindows()
    private var controllers: [UUID: DiaryWindowController] = [:]
    var hostedWindows: [NSWindow] { controllers.values.map(\.window) }
    /// 统一搜索的小窗置顶／关闭只作用于已打开的窗口，不新建。
    var openControllers: [DiaryWindowController] { Array(controllers.values) }

    @discardableResult
    func open(entry: DiaryEntry, context: ModelContext, activate: Bool = true) -> DiaryWindowController {
        let existing = controllers.values.first { $0.session.entryID == entry.id }
        let controller = existing ?? makeController(DiaryEditorSession(source: .entry(entry), context: context))
        controller.show(activate: activate)
        return controller
    }

    @discardableResult
    func openDraft(
        _ draft: BoardComposerDraft, dayKey: String, context: ModelContext,
        activate: Bool = true, onTransferred: () -> Void = {}
    ) -> DiaryWindowController {
        let existing = controllers.values.first { $0.session.sourceDraftID == draft.id }
        let controller = existing ?? makeController(DiaryEditorSession(source: .draft(draft, dayKey: dayKey), context: context))
        // 窗口先持有草稿再清空来源；关闭菜单栏不会销毁长文编辑会话。
        onTransferred()
        controller.show(activate: activate)
        return controller
    }

    private func makeController(_ session: DiaryEditorSession) -> DiaryWindowController {
        let controller = DiaryWindowController(session: session)
        controllers[session.id] = controller
        controller.onClose = { [weak self] in self?.controllers.removeValue(forKey: session.id) }
        return controller
    }

    func confirmTermination(composer: BoardComposerSession, context: ModelContext) -> Bool {
        for controller in controllers.values where controller.session.hasUnsavedChanges {
            guard controller.window.attachedSheet == nil else {
                controller.window.makeKeyAndOrderFront(nil)
                return false
            }
            controller.show()
            let response = DiaryWindowController.closeAlert().runModal()
            guard DiaryWindowController.canClose(controller.session, choice: DiaryWindowController.choice(response)) else { return false }
        }
        guard composer.diary.hasContent else { return true }
        let session = DiaryEditorSession(source: .draft(composer.diary, dayKey: DayClock.shared.todayKey), context: context)
        let response = DiaryWindowController.closeAlert().runModal()
        guard DiaryWindowController.canClose(session, choice: DiaryWindowController.choice(response)) else { return false }
        composer.diary = BoardComposerDraft()
        return true
    }
}

@MainActor
final class DiaryWindowController: BaseWindow {
    let session: DiaryEditorSession
    let window: NSWindow
    var onClose: (() -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var preferenceObservation: PreferenceObservation?

    override var windowID: String { "window.diary.\(session.id.uuidString)" }
    override var windowCategory: String { "diary" }
    override var windowTitle: String { session.plainWindowTitle(locale: AppPreferences.shared.resolvedLocale) }
    override var minimumContentSize: NSSize { NSSize(width: 360, height: 300) }
    override var defaultContentSize: NSSize { NSSize(width: 480, height: 440) }
    override var minSize: NSSize { minimumContentSize }
    override var defaultSize: NSSize { defaultContentSize }

    override func hasUnsavedChanges() -> Bool {
        session.hasUnsavedChanges
    }

    init(session: DiaryEditorSession) {
        self.session = session
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false
        )
        super.init()
        attachHostedWindow(window)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.minSize = NSSize(width: 360, height: 300)
        window.delegate = self
        window.level = .normal
        window.identifier = NSUserInterfaceItemIdentifier("diary.window." + session.id.uuidString)
        let root = DiaryWindowView(
            session: session,
            onPin: { [weak self] in self?.setPinned(!session.isWindowPinned) },
            onStateChange: { [weak self] in self?.refreshChrome() }
        )
        .modelContainer(session.context.container)
        .environment(\.modelContext, session.context)
        .appChrome()
        window.contentView = NSHostingView(rootView: root)
        window.center()
        refreshChrome()
        observeChanges()
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    override func openWindow() {
        show()
    }

    func show(activate: Bool = true) {
        session.refresh()
        attachHostedWindow(window)
        registry.markActivated(self)
        if activate {
            StatusItemController.shared.close()
            AppWindows.becomeActive()
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    override func setPinned(_ pinned: Bool) {
        session.isWindowPinned = pinned
        super.setPinned(pinned)
        // 只改变窗口层级，不复用记录 isPinned，也不重新激活应用或抢焦点。
        window.level = pinned ? .floating : .normal
    }

    override func windowDidBecomeKey(_ notification: Notification) {
        super.windowDidBecomeKey(notification)
        session.refresh()
    }

    override func windowDidResignKey(_ notification: Notification) {
        super.windowDidResignKey(notification)
        session.mask()
    }

    override func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard session.hasUnsavedChanges else { return true }
        guard sender.attachedSheet == nil else { return false }
        Self.closeAlert().beginSheetModal(for: sender) { [weak self] response in
            guard let self, Self.canClose(session, choice: Self.choice(response)) else { return }
            window.close()
        }
        return false
    }

    override func windowWillClose(_ notification: Notification) {
        session.mask()
        preferenceObservation?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        window.contentView = nil
        detachHostedWindow()
        super.windowWillClose(notification)
        registry.unregister(self)
        onClose?()
        AppWindows.resignIfIdle(closing: window)
    }

    static func canClose(_ session: DiaryEditorSession, choice: DiaryCloseChoice) -> Bool {
        switch choice {
        case .save: return session.save()
        case .discard: return true
        case .cancel: return false
        }
    }

    static func choice(_ response: NSApplication.ModalResponse) -> DiaryCloseChoice {
        switch response {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }

    static func closeAlert() -> NSAlert {
        let locale = AppPreferences.shared.resolvedLocale
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.string("diary.window.close.title", locale: locale)
        alert.informativeText = L10n.string("diary.window.close.message", locale: locale)
        alert.addButton(withTitle: L10n.string("common.save", locale: locale))
        alert.addButton(withTitle: L10n.string("diary.window.discard", locale: locale))
        alert.addButton(withTitle: L10n.string("alert.cancel", locale: locale))
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        return alert
    }

    private func refreshChrome() {
        window.title = session.plainWindowTitle(locale: AppPreferences.shared.resolvedLocale)
        window.isDocumentEdited = session.hasUnsavedChanges
    }

    private func observeChanges() {
        preferenceObservation = PreferenceObservation(preferences: AppPreferences.shared,
            consumer: .diaryWindow, presentation: { [weak self] in self?.refreshChrome() },
            legacy: { [weak self] in self?.session.refresh(); self?.refreshChrome() })
        for name in [Notification.Name.boardDidChange, NSApplication.didResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if name == NSApplication.didResignActiveNotification { self.session.mask() }
                    else { self.session.refresh(); self.refreshChrome() }
                }
            })
        }
    }
}
