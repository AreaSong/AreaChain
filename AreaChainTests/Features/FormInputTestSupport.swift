import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 只操作隔离宿主的原生编辑器；不读写系统剪贴板，不模拟真人输入法。
@MainActor
enum FormInputTestSupport {
    typealias Native = SettingsButtonTestSupport

    static func fields(in window: NSWindow) -> [NSTextField] {
        Native.elements(window.contentView).compactMap { $0 as? NSTextField }.filter(\.isEditable)
    }

    static func release(_ host: NSWindow) {
        if let sheet = host.attachedSheet {
            host.endSheet(sheet)
            SystemPageHost.release(sheet)
        }
        SystemPageHost.release(host)
    }

    static func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(30)) }
        try #require(condition())
    }

    static func sheet(in host: NSWindow) async throws -> NSWindow {
        try await wait { host.attachedSheet != nil }
        let sheet = try #require(host.attachedSheet)
        try await NativeSyntaxUI.prepareFocus(in: sheet)
        try await SystemPageHost.settle(sheet)
        return sheet
    }

    static func editor(_ field: NSTextField, in window: NSWindow) async throws -> NSTextView {
        try await Native.reveal(field, in: window)
        try Native.assertBounds([field], in: window)
        try #require(window.isKeyWindow)
        let rect = try Native.frame(field, in: window)
        // NSTextField 的 mouseDown 会等待 mouseUp，必须先排队完整点击。
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: rect.midX, y: rect.midY),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.postEvent(event, atStart: false)
        }
        try await SystemPageHost.settle(window)
        return try #require(field.currentEditor() as? NSTextView)
    }

    static func enter(_ text: String, into field: NSTextField, in window: NSWindow) async throws {
        let editor = try await editor(field, in: window)
        editor.insertText(text, replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        try await SystemPageHost.settle(window)
        #expect(field.stringValue == text)
    }

    static func key(_ code: UInt16, text: String, flags: NSEvent.ModifierFlags = [], in window: NSWindow) async throws {
        try #require(window.isKeyWindow)
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
        NSApp.sendEvent(event)
        try await SystemPageHost.settle(window)
    }

    static func labels(in window: NSWindow) -> [String] {
        Native.elements(window.contentView).flatMap { node in
            ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].compactMap {
                Native.value(node, $0) as? String
            }
        }
    }

    static func addButton(nextTo field: NSTextField, in window: NSWindow, locale: String = "en") throws -> NSObject {
        let title = L10n.string("clipboard.add", locale: Locale(identifier: locale))
        let rect = try Native.frame(field, in: window)
        let matches = try Native.buttons(in: window).filter {
            let label = Native.value($0, "accessibilityLabel") as? String
            let name = Native.value($0, "accessibilityTitle") as? String
            let buttonFrame = try Native.frame($0, in: window)
            return (label == title || name == title) && abs(buttonFrame.midY - rect.midY) < 12
        }
        #expect(matches.count == 1)
        return try #require(matches.first)
    }

    static func describeFocus(in window: NSWindow) -> String {
        if let field = fields(in: window).first(where: { $0.currentEditor() === window.firstResponder }) {
            return field.placeholderString ?? "field"
        }
        return String(describing: type(of: window.firstResponder))
    }
}
