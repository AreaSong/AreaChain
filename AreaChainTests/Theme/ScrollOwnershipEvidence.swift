import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
enum ScrollOwnershipEvidence {
    static func window<V: View>(_ content: V, locale: String, size: NSSize) -> NSWindow {
        let hosting = NSHostingView(rootView: content.environment(\.locale, Locale(identifier: locale))
            .environment(\.workspaceEmbedded, true)
            .environment(\.colorScheme, locale == "en" ? .light : .dark)
            .transaction { $0.disablesAnimations = true })
        hosting.safeAreaRegions = []
        let window = NSWindow(contentRect: .init(origin: .zero, size: size),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentView = hosting
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    static func knob(_ overlay: DaybookFloatingScrollerOverlay) throws -> NSRect {
        try #require(Mirror(reflecting: overlay).children.first { $0.label == "currentKnobRect" }?.value as? NSRect)
    }

    static func drag(_ target: NSScrollView, among targets: [NSScrollView], in window: NSWindow, label: String) async throws {
        try #require(window.isKeyWindow && NSApp.isActive, "焦点未就绪，停止滑块事件")
        let overlay = try #require(target.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }.first)
        overlay.flash()
        try await Task.sleep(for: .milliseconds(250))
        let knob = try knob(overlay)
        try #require(!knob.isEmpty && overlay.alphaValue >= 0.05)
        let start = overlay.convert(.init(x: knob.midX, y: knob.midY), to: nil)
        let root = try #require(window.contentView)
        let hit = root.hitTest(root.superview?.convert(start, from: nil) ?? start)
        try #require(hit === overlay, "窗口命中必须为该列自有浮层：\(label)")
        let others = targets.filter { $0 !== target }
        let offsets = others.map { $0.contentView.bounds.origin }
        let before = target.contentView.bounds.origin
        for (type, delta) in [(NSEvent.EventType.leftMouseDown, 0.0), (.leftMouseDragged, 30.0), (.leftMouseUp, 30.0)] {
            try #require(window.isKeyWindow && NSApp.isActive)
            let point = overlay.convert(.init(x: knob.midX, y: knob.midY + delta), to: nil)
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            window.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
        #expect(target.contentView.bounds.minY > before.y)
        #expect(others.map { $0.contentView.bounds.origin } == offsets)
        print("SCROLL_WINDOW_KNOB \(label) target=\(ScrollNativeEvidence.identity(target)) "
            + "overlay=\(ScrollNativeEvidence.identity(overlay)) knob=\(knob) before=\(before) "
            + "after=\(target.contentView.bounds.origin) othersUnchanged=\(others.map { $0.contentView.bounds.origin } == offsets)")
    }
}
