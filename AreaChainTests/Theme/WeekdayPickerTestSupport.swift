import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 复用原隔离宿主和 AX 遍历；星期按完整名称/数值身份定位，不能按重复短字符定位。
@MainActor
enum WeekdayPickerTestSupport {
    typealias Native = SettingsButtonTestSupport

    static func day(_ weekday: Int, locale: String = "en", host: String? = nil,
                    in window: NSWindow) throws -> NSObject {
        let name = WeekdayMask.accessibilityName(weekday, locale: Locale(identifier: locale))
        let nodes = Native.buttons(in: window).filter {
            Native.value($0, "accessibilityLabel") as? String == name
                && (host == nil || HabitMonthTestSupport.belongs($0, to: host!))
        }
        try #require(nodes.count == 1, "星期完整名称必须在宿主内唯一：\(weekday) / \(host ?? "single")")
        return nodes[0]
    }

    static func days(locale: String = "en", in window: NSWindow) throws -> [NSObject] {
        try (1...7).map { try day($0, locale: locale, in: window) }
    }

    static func expectMask(_ mask: Int, allowsEmpty: Bool = false, locale: String = "en",
                           in window: NSWindow) throws {
        for weekday in 1...7 {
            let node = try day(weekday, locale: locale, in: window)
            let selected = allowsEmpty ? WeekdayMask.containsSelection(mask, weekday: weekday)
                : WeekdayMask.contains(mask, weekday: weekday)
            #expect(node.value(forKey: "accessibilitySelected") as? Bool == selected)
        }
    }

    static func press(_ node: NSObject) throws {
        let action = NSSelectorFromString("accessibilityPerformPress")
        try #require(node.responds(to: action))
        _ = node.perform(action)
    }

    static func bitmap(_ window: NSWindow) throws -> Data {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return Data(bytes: try #require(bitmap.bitmapData), count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }

    static func mouse(_ point: NSPoint, type: NSEvent.EventType, in window: NSWindow) async throws {
        try #require(window.isKeyWindow)
        let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        NSApp.sendEvent(event)
        try await SystemPageHost.settle(window)
    }

    static func replaceTitle(_ text: String, in window: NSWindow) async throws -> NSTextView {
        let fields = Native.elements(window.contentView).compactMap { $0 as? NSTextField }.filter(\.isEditable)
        let field = try #require(fields.first { $0.stringValue == "Synthetic habit" } ?? fields.first)
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText(text, replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
        return editor
    }

    static func copyContains(_ text: String, in window: NSWindow) -> Bool {
        Native.elements(window.contentView).contains { node in
            ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].contains { key in
                Native.value(node, key) as? String == text
            }
        }
    }
}
