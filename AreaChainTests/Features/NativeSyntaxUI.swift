import AppKit
import Testing

/// 从实际无障碍树取得控件位置，避免测试把浮层方向或行高写死。
@MainActor
enum NativeSyntaxUI {
    /// 只在场景开始前建立焦点；后续动作丢焦仍由原断言报告，不能自动抢回掩盖问题。
    static func prepareFocus(in window: NSWindow) async throws {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        // 等 key window 期间持续请求激活；其他前台应用抢走后只睡超时会假失败，最终仍要求 isKeyWindow。
        let deadline = ContinuousClock.now + .seconds(4)
        while ContinuousClock.now < deadline {
            requestKeyWindow(window)
            if NSApp.isActive && window.isVisible && window.isKeyWindow { break }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.main.async { continuation.resume() }
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        let foreground = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
        try #require(
            NSApp.activationPolicy() == .regular && NSApp.isActive && window.isVisible && window.isKeyWindow,
            """
            场景焦点未就绪：policy=\(NSApp.activationPolicy().rawValue)，\
            visible=\(window.isVisible)，key=\(window.isKeyWindow)，\
            active=\(NSApp.isActive)，foreground=\(foreground)
            """
        )
    }

    /// 只把窗口排到其他应用窗口之后并完成布局，不激活应用：纯程序化断言不需要前台，测试期间用户仍可操作电脑。
    /// 后台窗口不能再转前台发事件（macOS 14 起让出前台后抢不回来）；需要键鼠事件的套件整体走前台模式。
    /// 当前用例所在套件标了 `.backgroundWindow`：开窗辅助据此只排窗不激活，标签是唯一开关。
    static var inBackgroundSuite: Bool { Test.current?.tags.contains(.backgroundWindow) == true }

    static func prepareBackground(in window: NSWindow) async throws {
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        window.orderBack(nil)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        window.contentView?.layoutSubtreeIfNeeded()
        try #require(window.isVisible, "后台窗口未上屏")
    }

    private static func requestKeyWindow(_ window: NSWindow) {
        NSApp.activate()
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

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
        if let view = element as? NSView, let id = view.identifier?.rawValue,
           id.hasPrefix("syntax.") || id.hasPrefix("menubar.") { return id }
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

extension Tag {
    /// 整个套件只用程序化动作、窗口开在后台（不激活应用）：门禁把它放进可以边用电脑边跑的后台轮。
    /// 套件里只要有一个用例发键鼠事件，就不能打这个标签。
    @Tag static var backgroundWindow: Self
}
