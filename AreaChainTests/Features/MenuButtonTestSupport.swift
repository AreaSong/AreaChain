import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 复用真实菜单的追踪通知和事件队列；取回的菜单仅供明确标注的动作派发测试。
@MainActor
enum MenuButtonTestSupport {
    typealias Native = SettingsButtonTestSupport

    static func menus(in window: NSWindow) -> [NSObject] {
        Native.elements(window.contentView).filter {
            ["AXMenuButton", "AXPopUpButton"].contains(Native.value($0, "accessibilityRole") as? String ?? "")
        }.sorted { left, right in
            let lhs = (try? Native.frame(left, in: window)) ?? .zero
            let rhs = (try? Native.frame(right, in: window)) ?? .zero
            return abs(lhs.midY - rhs.midY) > 4 ? lhs.midY > rhs.midY : lhs.minX < rhs.minX
        }
    }

    static func title(_ node: NSObject) -> String {
        (Native.value(node, "accessibilityLabel") ?? Native.value(node, "accessibilityTitle")) as? String ?? ""
    }

    static func labels(in window: NSWindow) -> String {
        Native.elements(window.contentView).compactMap {
            (Native.value($0, "accessibilityLabel") ?? Native.value($0, "accessibilityTitle")
                ?? Native.value($0, "accessibilityValue")) as? String
        }.joined(separator: "\n")
    }

    static func menu(_ key: String, locale: String = "en", in window: NSWindow) throws -> NSObject {
        let text = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        return try #require(menus(in: window).first { title($0) == text }, "未找到菜单：\(key)")
    }

    /// 鼠标位置分别落在文字、图标或公共边距内，Escape 必须由系统追踪循环消费。
    static func openAndEscape(_ node: NSObject, xFraction: CGFloat = 0.5, yFraction: CGFloat = 0.5,
                              in window: NSWindow) async throws -> NSMenu {
        try Native.assertBounds([node], in: window)
        try #require(window.isKeyWindow)
        let rect = try Native.frame(node, in: window)
        let point = NSPoint(x: rect.minX + rect.width * xFraction, y: rect.minY + rect.height * yFraction)
        var tracked: NSMenu?
        var ended = false
        let center = NotificationCenter.default
        let begin = center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil) { note in
            MainActor.assumeIsolated { tracked = note.object as? NSMenu }
        }
        let end = center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { ended = true }
        }
        defer { center.removeObserver(begin); center.removeObserver(end) }
        NSApp.postEvent(try mouse(.leftMouseUp, at: point, in: window), atStart: false)
        NSApp.postEvent(try #require(NSEvent.keyEvent(
            with: .keyDown, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false, keyCode: 53
        )), atStart: false)
        NSApp.sendEvent(try mouse(.leftMouseDown, at: point, in: window))
        try await SystemPageHost.settle(window)
        #expect(ended, "Escape 应结束系统菜单追踪")
        return try #require(tracked, "原生菜单未开始追踪")
    }

    static func mouse(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow,
                      flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
    }

    static func dispatch(_ title: String, occurrence: Int = 0, in menu: NSMenu) throws {
        let matches = menu.items.indices.filter { menu.items[$0].title == title && menu.items[$0].action != nil }
        let index = try #require(matches.dropFirst(occurrence).first, "未找到真实菜单动作：\(title)")
        #expect(menu.items[index].isEnabled)
        menu.performActionForItem(at: index)
    }

    static func localized(_ key: String, _ locale: String) -> String {
        L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
    }

    static func assertTextWidth(_ node: NSObject, in window: NSWindow) throws {
        let rect = try Native.frame(node, in: window)
        let width = (title(node) as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width
        #expect(rect.width >= width + 10, "菜单文字与公共水平边距不能压成图标宽度")
        // 系统菜单 AX 高度与 SwiftUI 标签提议高度不同；点击边界按原生实际矩形核验。
    }

    /// 此页面只改查询、选择与列表检查日；不切页，避免 selectedTab 的连带重置。
    static func preserveListingNavigation() -> () -> Void {
        let nav = WorkspaceNavigation.shared
        let query = nav.allItemsQuery
        let selected = nav.selectedTaskIDs
        let anchor = nav.selectionAnchorID
        let focused = nav.selectedTaskID
        let reference = nav.inspectedReference
        let inspector = nav.isInspectorPresented
        let usesDays = nav.usesListedCheckDays
        let days = nav.routineCompletionDays
        return {
            nav.allItemsQuery = query
            nav.selectAllTasks(in: anchor.map { [$0] } ?? [])
            nav.selectedTaskIDs = selected
            nav.selectedTaskID = focused
            nav.inspectedReference = reference
            nav.isInspectorPresented = inspector
            if usesDays { nav.replaceListedCheckDays(days) } else { nav.clearListedCheckDays() }
        }
    }
}
