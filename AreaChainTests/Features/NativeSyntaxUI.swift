import AppKit
import Testing

/// 从实际无障碍树取得控件位置，避免测试把浮层方向或行高写死。
@MainActor
enum NativeSyntaxUI {
    static func center(_ identifier: String, in window: NSWindow) throws -> NSPoint {
        let rect = try frame(identifier, in: window)
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    static func frame(_ identifier: String, in window: NSWindow) throws -> CGRect {
        for element in elements(in: window.contentView) where id(element) == identifier {
            if let view = element as? NSView, view.identifier?.rawValue == identifier,
               view.window === window, !view.bounds.isEmpty {
                return view.convert(view.bounds, to: nil)
            }
            if let accessible = element as? NSAccessibilityProtocol, !accessible.accessibilityFrame().isEmpty {
                return window.convertFromScreen(accessible.accessibilityFrame())
            }
            if element.responds(to: NSSelectorFromString("accessibilityFrame")),
               let value = element.value(forKey: "accessibilityFrame") as? NSValue,
               !value.rectValue.isEmpty {
                return window.convertFromScreen(value.rectValue)
            }
        }
        let nodes = elements(in: window.contentView)
        let labels = nodes.compactMap(id)
        Issue.record("没有找到可见控件：\(identifier)；已有标识：\(labels)")
        throw CocoaError(.coderValueNotFound)
    }

    static func identifiers(in window: NSWindow) -> Set<String> {
        Set(elements(in: window.contentView).compactMap(id))
    }

    private static func id(_ element: NSObject) -> String? {
        if let view = element as? NSView, let id = view.identifier?.rawValue, id.hasPrefix("syntax.") { return id }
        if let accessible = element as? NSAccessibilityProtocol, let id = accessible.accessibilityIdentifier() {
            return id
        }
        let selector = NSSelectorFromString("accessibilityIdentifier")
        guard element.responds(to: selector) else { return nil }
        return element.perform(selector)?.takeUnretainedValue() as? String
    }

    private static func elements(in root: NSView?) -> [NSObject] {
        guard let root else { return [] }
        var queue: [NSObject] = [root]
        var result: [NSObject] = []
        var visited: Set<ObjectIdentifier> = []
        let selector = NSSelectorFromString("accessibilityChildren")
        while let element = queue.popLast() {
            guard visited.insert(ObjectIdentifier(element)).inserted else { continue }
            result.append(element)
            if let view = element as? NSView { queue.append(contentsOf: view.subviews) }
            if element.responds(to: selector),
               let children = element.perform(selector)?.takeUnretainedValue() as? [Any] {
                queue.append(contentsOf: children.compactMap { $0 as? NSObject })
            }
        }
        return result
    }
}
