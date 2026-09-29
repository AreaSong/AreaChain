import AppKit
import SwiftUI

@MainActor
final class ClipboardHistoryPanel: NSObject, NSWindowDelegate {
    static let shared = ClipboardHistoryPanel()

    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?
    private var isClosing = false
    private var hotkeyObserver: NSObjectProtocol?
    private let size = NSSize(width: 380, height: 460)

    var isKey: Bool { panel?.isKeyWindow == true }
    var hostedWindow: NSWindow? { panel }

    func install() {
        guard hotkeyObserver == nil else { return }
        hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .showClipboardHistory,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ClipboardHistoryPanel.shared.toggle()
            }
        }
        ClipboardHistoryKeys.install()
    }

    func toggle() {
        if panel?.isVisible == true {
            closeReturning()
            return
        }
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }
        let window = ensurePanel()
        window.setFrame(frameNearCursor(), display: false)
        applyLevel()
        AppWindows.becomeActive()
        window.makeKeyAndOrderFront(nil)
    }

    func setStaysOnTop(_ enabled: Bool) {
        ClipboardHistorySession.shared.setPanelStaysOnTop(enabled)
        applyLevel()
    }

    func applyLevel() {
        panel?.level = ClipboardHistorySession.shared.panelStaysOnTop ? .floating : .normal
    }

    func closeReturning() {
        guard !isClosing else { return }
        isClosing = true
        let app = previousApp
        panel?.orderOut(nil)
        if let app, app.bundleIdentifier != Bundle.main.bundleIdentifier {
            app.activate()
        }
        AppWindows.resignIfIdle(closing: panel)
        isClosing = false
    }

    func windowWillClose(_ notification: Notification) {
        AppWindows.resignIfIdle(closing: panel)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isFloatingPanel = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.hasShadow = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.delegate = self
        window.contentView = NSHostingView(rootView:
            ClipboardHistoryPanelView()
                .environment(\.locale, AppPreferences.shared.resolvedLocale)
                .appChrome()
        )
        panel = window
        applyLevel()
        return window
    }

    private func frameNearCursor() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: mouse.x, y: mouse.y, width: size.width, height: size.height)
        if ClipboardHistorySession.shared.panelAnchor == .center {
            let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
            return NSRect(origin: origin, size: size)
        }
        var origin = NSPoint(x: mouse.x, y: mouse.y - size.height - DaybookSpacing.sm)
        if origin.x + size.width > visible.maxX { origin.x = visible.maxX - size.width }
        if origin.x < visible.minX { origin.x = visible.minX }
        if origin.y < visible.minY { origin.y = mouse.y + DaybookSpacing.sm }
        if origin.y + size.height > visible.maxY { origin.y = visible.maxY - size.height }
        return NSRect(origin: origin, size: size)
    }
}

private struct ClipboardHistoryPanelView: View {
    @Bindable var session = ClipboardHistorySession.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            HStack {
                Text("window.clipboard")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.primary)
                Spacer()
                DaybookIconButton(
                    systemName: session.panelStaysOnTop ? "pin.fill" : "pin",
                    label: session.panelStaysOnTop ? "clipboard.panel.unpin" : "clipboard.panel.pin",
                    size: .compact,
                    isActive: session.panelStaysOnTop
                ) {
                    ClipboardHistoryPanel.shared.setStaysOnTop(!session.panelStaysOnTop)
                }
                DaybookIconButton(systemName: "macwindow", label: "clipboard.openPage", size: .compact) {
                    ClipboardHistoryPanel.shared.closeReturning()
                    AppWindows.openWorkspace(tab: .clipboard)
                }
            }
            ClipboardHistoryBrowser(session: session, showsFooter: true, commitsOnClick: true) { id, plain, paste in
                ClipboardHistoryKeys.commit(id: id, plain: plain, paste: paste, inPanel: true)
            }
        }
        .padding(DaybookSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DaybookPalette.fill.page)
    }
}

/// 本地按键监视回调不能把 `NSEvent` 送进隔离闭包；先抄出按键事实。
private struct ClipboardKeySnapshot: Sendable {
    var keyCode: UInt16
    var characters: String
    var flags: UInt
    var firstResponderIsTextView: Bool
    var hasMarkedText: Bool

    var modifierFlags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: flags) }

    init(_ event: NSEvent) {
        keyCode = event.keyCode
        characters = (event.charactersIgnoringModifiers ?? "").lowercased()
        flags = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue
        let editor = event.window?.firstResponder as? NSTextView
        firstResponderIsTextView = editor != nil
        hasMarkedText = editor?.hasMarkedText() ?? false
    }
}

@MainActor
enum ClipboardHistoryKeys {
    private static var installed = false
    private static let upArrow: UInt16 = 126
    private static let downArrow: UInt16 = 125

    static func install() {
        guard !installed else { return }
        installed = true
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let snapshot = ClipboardKeySnapshot(event)
            let consumed = MainActor.assumeIsolated {
                handle(snapshot)
            }
            return consumed ? nil : event
        }
    }

    static func commit(id: UUID, plain: Bool, paste: Bool, inPanel: Bool) {
        let session = ClipboardHistorySession.shared
        guard session.stage(id, plainOnly: plain) == .copied else { return }
        guard paste else {
            if inPanel { ClipboardHistoryPanel.shared.closeReturning() }
            return
        }
        guard session.allowKeystroke(prompt: true) else {
            session.noticeKey = "clipboard.paste.needsAccess"
            if inPanel { ClipboardHistoryPanel.shared.closeReturning() }
            return
        }
        if inPanel {
            ClipboardHistoryPanel.shared.closeReturning()
        } else {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        // 先交还前台，再送 ⌘V，避免按键落进历史浮窗或搜索框。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            MainActor.assumeIsolated {
                session.sendPasteKeystroke()
            }
        }
    }

    private static func handle(_ event: ClipboardKeySnapshot) -> Bool {
        let panel = ClipboardHistoryPanel.shared
        let session = ClipboardHistorySession.shared
        let inPanel = panel.isKey
        let pageCanTakeKeys = session.pageOwnsKeys
            && !inPanel
            && WorkspaceNavigation.shared.selectedTab == .clipboard
            && (session.clipboardFieldFocused || !event.firstResponderIsTextView)
        guard inPanel || pageCanTakeKeys else { return false }
        if event.hasMarkedText { return false }
        let flags = event.modifierFlags
        if event.keyCode == UInt16(ShortcutKey.escape) {
            if !session.query.isEmpty {
                session.query = ""
                return true
            }
            if inPanel {
                panel.closeReturning()
                return true
            }
            return false
        }
        if event.keyCode == upArrow {
            session.moveSelection(by: -1)
            return true
        }
        if event.keyCode == downArrow {
            session.moveSelection(by: 1)
            return true
        }
        if event.keyCode == UInt16(ShortcutKey.returnKey) {
            guard let item = session.selectedOrFirst() else { return true }
            let plain = (flags.contains(.option) && flags.contains(.shift)) || session.plainByDefault
            commit(id: item.id, plain: plain, paste: flags.contains(.option), inPanel: inPanel)
            return true
        }
        if event.keyCode == UInt16(ShortcutKey.delete), flags.contains(.option), !flags.contains(.command) {
            if let item = session.selectedOrFirst() { session.delete(item.id) }
            return true
        }
        let chars = event.characters
        if chars == "p", flags.contains(.option), !flags.contains(.command), !flags.contains(.control) {
            if let item = session.selectedOrFirst() { session.togglePin(item.id) }
            return true
        }
        if let number = Int(chars), (1...9).contains(number),
           flags.contains(.command) || flags.contains(.option) {
            guard let item = session.item(atQuickIndex: number) else { return true }
            let plain = (flags.contains(.option) && flags.contains(.shift)) || session.plainByDefault
            commit(id: item.id, plain: plain, paste: flags.contains(.option), inPanel: inPanel)
            return true
        }
        if session.query.isEmpty,
           chars.count == 1,
           !flags.contains(.command),
           !flags.contains(.option),
           !flags.contains(.control),
           let pinned = session.items.first(where: { $0.pinKey == chars }) {
            commit(id: pinned.id, plain: session.plainByDefault, paste: false, inPanel: inPanel)
            return true
        }
        return false
    }
}
