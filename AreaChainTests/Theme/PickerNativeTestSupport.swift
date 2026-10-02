import AppKit
import Testing
@testable import AreaChain

@MainActor
enum PickerNativeTestSupport {
    typealias Native = SettingsButtonTestSupport

    /// 原生辅助操作派发，只证明 AXPress 可打开菜单，不等于真人 VoiceOver 验收。
    static func accessibilityOpenAndEscape(_ node: NSObject, in window: NSWindow) async throws {
        let action = NSSelectorFromString("accessibilityPerformPress")
        try #require(node.responds(to: action))
        var began = false
        var ended = false
        var tracked: NSMenu?
        let escape = try key(code: 53, chars: "\u{1B}", in: window)
        let center = NotificationCenter.default
        let begin = center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil) { note in
            MainActor.assumeIsolated {
                began = true
                tracked = note.object as? NSMenu
                NSApp.postEvent(escape, atStart: false)
            }
        }
        let end = center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { ended = true }
        }
        defer {
            tracked?.cancelTracking()
            center.removeObserver(begin)
            center.removeObserver(end)
        }
        _ = node.perform(action)
        let deadline = ContinuousClock.now + .seconds(3)
        while !ended, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(40)) }
        try #require(began && ended)
    }

    /// 合成 NSEvent 由系统菜单追踪循环处理；不是菜单项 action 派发或真人输入。
    static func keyboardSelection(_ node: NSObject, moveDown: Bool, in window: NSWindow) async throws {
        let rect = try Native.frame(node, in: window)
        let point = NSPoint(x: rect.midX, y: rect.midY)
        var began = false
        var ended = false
        let center = NotificationCenter.default
        let begin = center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { began = true }
        }
        let end = center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { ended = true }
        }
        defer { center.removeObserver(begin); center.removeObserver(end) }
        NSApp.postEvent(try MenuButtonTestSupport.mouse(.leftMouseUp, at: point, in: window), atStart: false)
        if moveDown { NSApp.postEvent(try key(code: 125, chars: "\u{F701}", in: window), atStart: false) }
        NSApp.postEvent(try key(code: 36, chars: "\r", in: window), atStart: false)
        NSApp.sendEvent(try MenuButtonTestSupport.mouse(.leftMouseDown, at: point, in: window))
        try await SystemPageHost.settle(window)
        #expect(began && ended)
    }

    static func key(code: UInt16, chars: String, in window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code))
    }
}
