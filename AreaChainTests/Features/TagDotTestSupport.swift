import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 直接挂载两个生产消费者；只用合成内存标签，不复制行或拆开合并辅助语义。
@MainActor
final class TagDotTestSupport {
    typealias Native = SettingsButtonTestSupport
    let fixture: Native
    let tags: [TagItem]
    let todo: TodoItem
    let restoreNavigation: () -> Void
    let oldTag = WorkspaceNavigation.shared.selectedTagID
    let oldTab = WorkspaceNavigation.shared.selectedTab
    let pointer = NSEvent.mouseLocation

    var context: ModelContext { fixture.container.mainContext }

    init() throws {
        fixture = try Native(isolatedPreferences: true)
        restoreNavigation = MenuButtonTestSupport.preserveListingNavigation()
        tags = ["Short QA", String(repeating: "合成长标签 Synthetic ", count: 5),
                DiaryMemoTags.password, DiaryMemoTags.idea, DiaryMemoTags.journal]
            .enumerated().map { TagItem(name: $0.element, sortOrder: $0.offset) }
        todo = TodoItem(title: "Synthetic tagged item", dayKey: "2026-10-04", tagIDs: tags[0].id.uuidString)
        tags.forEach { context.insert($0) }
        context.insert(todo)
        try context.save()
        WorkspaceNavigation.shared.selectedTagID = nil
    }

    func cleanup() {
        WorkspaceNavigation.shared.revealTab(oldTab)
        WorkspaceNavigation.shared.selectedTagID = oldTag
        restoreNavigation()
        RowBubbleTestSupport.warp(pointer)
        fixture.cleanup()
    }

    func window(sidebar: Bool, locale: String, scheme: ColorScheme, wide: Bool) -> NSWindow {
        let size = NSSize(width: sidebar ? (wide ? 260 : 220) : (wide ? 720 : 480), height: 760)
        if sidebar {
            return fixture.window(WorkspaceSidebarView(navigation: .shared, tags: tags, todos: [todo]),
                                  locale: locale, scheme: scheme, size: size)
        }
        return fixture.window(TagManagementPage(), locale: locale, scheme: scheme, size: size)
    }

    static func table(_ window: NSWindow) throws -> NSTableView {
        try #require(Native.elements(window.contentView).compactMap { $0 as? NSTableView }.first)
    }

    static func text(_ node: NSObject) -> String {
        for key in ["accessibilityLabel", "accessibilityValue", "accessibilityTitle"] {
            if let string = Native.value(node, key) as? String, !string.isEmpty { return string }
        }
        return ""
    }

    static func row(_ tag: TagItem, sidebar: Bool, in window: NSWindow) throws -> NSObject {
        let matches = Native.elements(window.contentView).filter {
            let role = Native.value($0, "accessibilityRole") as? String
            let label = text($0)
            return sidebar ? role == "AXButton" && label == tag.name
                : label.contains(", \(tag.name),") || label.contains("、\(tag.name)、")
        }
        try #require(matches.count == 1, "必须唯一定位原合并行：\(tag.name)，命中 \(matches.count)")
        return try #require(matches.first)
    }

    static func assertRow(_ tag: TagItem, sidebar: Bool, locale: String, in window: NSWindow) throws {
        let node = try row(tag, sidebar: sidebar, in: window)
        let frame = try Native.frame(node, in: window)
        try Native.assertBounds([node], in: window)
        if sidebar {
            #expect(text(node) == tag.name)
            let children = Native.value(node, "accessibilityChildren") as? [NSObject] ?? []
            #expect(children.isEmpty, "装饰色点不应增加可朗读子元素")
        } else {
            let key = "tags.color.\(tag.resolvedColorToken.rawValue)"
            let color = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
            #expect(text(node).components(separatedBy: color).count == 2, "原颜色名称在合并行中只出现一次")
            #expect(text(node).contains(L10n.format("tags.usage.count", locale: Locale(identifier: locale),
                                                    tag.sortOrder == 0 ? 1 : 0)))
        }
        let size: CGFloat = sidebar ? 8 : 10
        let dot = NSRect(x: frame.minX, y: frame.midY - size / 2, width: size, height: size)
        try assertDot(rect: dot, in: window)
    }

    static func assertDot(rect: NSRect, in window: NSWindow) throws {
        let view = try #require(window.contentView)
        let bitmap = try OverlaySurfaceTestSupport.bitmap(window)
        let point = view.convert(NSPoint(x: rect.midX, y: rect.midY), from: nil)
        let y = view.isFlipped ? point.y : view.bounds.height - point.y
        let color = try #require(bitmap.colorAt(x: Int(point.x * CGFloat(bitmap.pixelsWide) / view.bounds.width),
            y: Int(y * CGFloat(bitmap.pixelsHigh) / view.bounds.height))?.usingColorSpace(.deviceRGB))
        // 实际实色区域核对直径；颜色等价由同宿主旧/新完整 PNG 对照，避免跨色彩空间比较原始分量。
        let scale = CGFloat(bitmap.pixelsWide) / view.bounds.width
        let center = NSPoint(x: point.x * scale, y: y * scale)
        for horizontal in [true, false] {
            let extent = Int(rect.width * scale)
            let matches = (-extent...extent).filter { offset in
                let sample = bitmap.colorAt(x: Int(center.x) + (horizontal ? offset : 0),
                    y: Int(center.y) + (horizontal ? 0 : offset))?.usingColorSpace(.deviceRGB)
                guard let sample else { return false }
                return abs(sample.redComponent - color.redComponent) < 0.025
                    && abs(sample.greenComponent - color.greenComponent) < 0.025
                    && abs(sample.blueComponent - color.blueComponent) < 0.025
            }
            #expect(CGFloat(matches.count) >= (rect.width - 1) * scale && CGFloat(matches.count) <= rect.width * scale + 1,
                    "色点实际横纵直径应为 \(rect.width)pt，实色像素数 \(matches.count)")
        }
    }

    static func color(_ tag: TagItem, sidebar: Bool, in window: NSWindow) throws -> [Int] {
        let frame = try Native.frame(row(tag, sidebar: sidebar, in: window), in: window)
        let view = try #require(window.contentView)
        let point = view.convert(NSPoint(x: frame.minX + (sidebar ? 4 : 5), y: frame.midY), from: nil)
        let bitmap = try OverlaySurfaceTestSupport.bitmap(window)
        let y = view.isFlipped ? point.y : view.bounds.height - point.y
        let color = try #require(bitmap.colorAt(x: Int(point.x * CGFloat(bitmap.pixelsWide) / view.bounds.width),
            y: Int(y * CGFloat(bitmap.pixelsHigh) / view.bounds.height))?.usingColorSpace(.deviceRGB))
        return [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
    }

    static func record(_ window: NSWindow, name: String) throws {
        let phase = ProcessInfo.processInfo.environment["AREACHAIN_TAG_DOT_PHASE"] ?? "current"
        let prefix = "9e-\(phase)-\(name)"
        try OverlaySurfaceTestSupport.record(window, name: prefix)
        let entries = try Native.elements(window.contentView).compactMap { node -> [String: String]? in
            guard let role = Native.value(node, "accessibilityRole") as? String,
                  !text(node).isEmpty else { return nil }
            return ["role": role, "text": text(node), "frame": NSStringFromRect(try Native.frame(node, in: window))]
        }.sorted { ($0["text"] ?? "") < ($1["text"] ?? "") }
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainSurfaceQA")
        try JSONSerialization.data(withJSONObject: entries, options: [.sortedKeys, .prettyPrinted])
            .write(to: directory.appending(path: prefix + "-rows.json"))
        print("TAG_DOT \(prefix) evidence=\(directory.path)")
    }

    static func mouse(_ point: NSPoint, in window: NSWindow, count: Int = 1) async throws {
        try #require(window.isKeyWindow && NSApp.isActive)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: count, pressure: 1))
            NSApp.postEvent(event, atStart: false)
        }
        try await SystemPageHost.settle(window)
    }
}
