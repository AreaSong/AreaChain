import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 设置消费者共用原生宿主；偏好和模型均隔离，不挂载会启动系统查询的 SettingsView。
@MainActor
final class SettingsButtonTestSupport {
    private static var retained: [ModelContainer] = []
    let suite = "areachain.settings.buttons.\(UUID())"
    let defaults: UserDefaults
    let prefs: AppPreferences
    let container: ModelContainer
    private let previousAppearance: NSAppearance?
    private let isolatedPreferences: Bool
    let preferenceCenter: NotificationCenter
    let preferenceEffects: LocalPreferenceEffects

    init(isolatedPreferences: Bool = false) throws {
        try #require(ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
        self.isolatedPreferences = isolatedPreferences
        preferenceCenter = isolatedPreferences ? NotificationCenter() : .default
        preferenceEffects = isolatedPreferences
            ? LocalPreferenceEffects(applyAppearance: { _ in }, post: { [preferenceCenter] in preferenceCenter.post($0) })
            : .live
        previousAppearance = NSApp.appearance
        defaults = try #require(UserDefaults(suiteName: suite))
        container = try ModelContainer(for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        prefs = AppPreferences(defaults: defaults, effects: preferenceEffects)
        Self.retained.append(container)
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
        if !isolatedPreferences { NSApp.appearance = previousAppearance }
    }

    func window<V: View>(_ content: V, locale: String = "en", scheme: ColorScheme = .light,
                         size: NSSize = NSSize(width: 420, height: 560), suppliedWindow: NSWindow? = nil) -> NSWindow {
        SystemPageHost.window(content.environment(prefs), container: container, scheme: scheme,
                              locale: locale, size: size, prefs: prefs, suppliedWindow: suppliedWindow)
    }

    static func value(_ node: NSObject, _ name: String) -> Any? {
        let selector = NSSelectorFromString(name)
        return node.responds(to: selector) ? node.perform(selector)?.takeUnretainedValue() : nil
    }

    static func elements(_ root: NSView?) -> [NSObject] {
        guard let root else { return [] }
        var queue: [NSObject] = [root]
        var visited = Set<ObjectIdentifier>()
        var result: [NSObject] = []
        while let node = queue.popLast() {
            guard visited.insert(ObjectIdentifier(node)).inserted else { continue }
            result.append(node)
            if let view = node as? NSView { queue.append(contentsOf: view.subviews) }
            if let children = value(node, "accessibilityChildren") as? [NSObject] {
                queue.append(contentsOf: children)
            }
        }
        return result
    }

    static func buttons(in window: NSWindow) -> [NSObject] {
        elements(window.contentView).filter { value($0, "accessibilityRole") as? String == "AXButton" }
    }

    static func button(_ key: String, locale: String = "en", in window: NSWindow) throws -> NSObject {
        let title = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        return try #require(buttons(in: window).first {
            value($0, "accessibilityIdentifier") as? String == key
                || value($0, "accessibilityLabel") as? String == title
                || value($0, "accessibilityTitle") as? String == title
        }, "未找到生产按钮：\(key)")
    }

    static func frame(_ node: NSObject, in window: NSWindow) throws -> CGRect {
        let screen = try #require(node.value(forKey: "accessibilityFrame") as? NSValue).rectValue
        return window.convertFromScreen(screen)
    }

    static func assertBounds(_ nodes: [NSObject], in window: NSWindow) throws {
        let bounds = try #require(window.contentView).bounds
        let frames = try nodes.map { try frame($0, in: window) }
        for rect in frames {
            #expect(rect.width > 0 && rect.height > 0)
            #expect(rect.minX >= 0 && rect.maxX <= bounds.width)
            #expect(rect.minY >= 0 && rect.maxY <= bounds.height)
        }
        for index in frames.indices {
            for other in frames.dropFirst(index + 1) {
                #expect(!frames[index].intersects(other), "相邻按钮重叠")
            }
        }
    }

    static func click(_ node: NSObject, in window: NSWindow) async throws {
        try assertBounds([node], in: window)
        try #require(window.isKeyWindow)
        let rect = try frame(node, in: window)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: rect.midX, y: rect.midY),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
    }

    static func reveal(_ node: NSObject, in window: NSWindow) async throws {
        let rect = try frame(node, in: window)
        let scrolls = elements(window.contentView).compactMap { $0 as? NSScrollView }
        for scroll in scrolls {
            guard let document = scroll.documentView else { continue }
            document.scrollToVisible(document.convert(rect, from: nil))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        try await SystemPageHost.settle(window)
    }

    static func key(_ code: UInt16, flags: NSEvent.ModifierFlags = [], in window: NSWindow) async throws {
        try #require(window.isKeyWindow)
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
        NSApp.postEvent(event, atStart: false)
        try await SystemPageHost.settle(window)
    }

    static func snapshot(_ window: NSWindow, name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainButtonConsumersQA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appending(path: "settings-\(name).png"))
    }
}
