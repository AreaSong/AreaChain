import AppKit
import Testing

/// E 补验专用诊断；不改变共享 helper 的时序、焦点或坐标政策。
@MainActor
enum SurfaceEventTestSupport {
    static func note(_ message: String) {
        print("SURFACE_EVENT \(message)")
    }

    static func describe(_ window: NSWindow) {
        let editor = window.firstResponder as? NSTextView
        note("window=\(window.windowNumber) key=\(NSApp.keyWindow === window) visible=\(window.isVisible) "
             + "active=\(NSApp.isActive) bundle=\(Bundle.main.bundleIdentifier ?? "nil") "
             + "foreground=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil") "
             + "responder=\(window.firstResponder.map { String(describing: type(of: $0)) } ?? "nil") "
             + "marked=\(editor?.hasMarkedText() ?? false)")
    }

    static func click(_ point: NSPoint, in window: NSWindow, delivery: String = "send") async throws {
        try #require(window.isKeyWindow && window.isVisible && NSApp.isActive)
        describe(window)
        let root = try #require(window.contentView)
        let local = root.convert(point, from: nil)
        let hit = root.hitTest(root.superview?.convert(point, from: nil) ?? point)
        note("point window=\(point) content=\(local) screen=\(window.convertPoint(toScreen: point)) "
             + "hit=\(hit.map { String(describing: type(of: $0)).components(separatedBy: "<")[0] } ?? "nil") bounds=\(root.bounds)")
        var received: [NSEvent.EventType] = []
        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
            MainActor.assumeIsolated {
                if event.window === window {
                    received.append(event.type)
                    note("received \(event.type) window=\(event.windowNumber) point=\(event.locationInWindow)")
                }
            }
            return event
        }
        defer { if let monitor { NSEvent.removeMonitor(monitor) } }
        let start = ProcessInfo.processInfo.systemUptime
        for (index, type) in [NSEvent.EventType.leftMouseDown, .leftMouseUp].enumerated() {
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: start + Double(index) * 0.05, windowNumber: window.windowNumber,
                context: nil, eventNumber: index + 1, clickCount: 1, pressure: index == 0 ? 1 : 0))
            note("\(delivery) \(type) window=\(event.windowNumber) point=\(event.locationInWindow) time=\(event.timestamp)")
            if delivery == "queue" { NSApp.postEvent(event, atStart: false) }
            else { NSApp.sendEvent(event) }
        }
        try await SystemPageHost.settle(window)
        #expect(received == [.leftMouseDown, .leftMouseUp])
    }
}
