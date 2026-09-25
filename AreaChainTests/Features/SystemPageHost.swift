import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
enum SystemPageHost {
    static func window<Content: View>(
        _ content: Content,
        container: ModelContainer,
        scheme: ColorScheme,
        locale: String,
        size: NSSize,
        embedded: Bool = true
    ) -> NSWindow {
        let root = content
            .modelContainer(container)
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.workspaceEmbedded, embedded)
            .environment(AppPreferences.shared)
            .preferredColorScheme(scheme)
            .frame(width: size.width, height: size.height)
            .transaction { $0.disablesAnimations = true }
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        let hosting = NSHostingView(rootView: root)
        hosting.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
        window.setContentSize(size)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    static func settle(_ window: NSWindow) async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    static func release(_ window: NSWindow) {
        window.makeFirstResponder(nil)
        window.orderOut(nil)
        window.contentView = nil
    }

    static func labels(in window: NSWindow) -> String {
        elements(in: window.contentView).compactMap { element in
            (element as? NSAccessibilityProtocol)?.accessibilityLabel()
        }.joined(separator: "\n")
    }

    static func identifiers(in window: NSWindow) -> Set<String> {
        var ids = Set(elements(in: window.contentView).compactMap(identifier))
        for element in elements(in: window.contentView) {
            guard let value = (element as? NSAccessibilityProtocol)?.accessibilityValue() as? String,
                  value.contains(".") else { continue }
            ids.formUnion(value.split(separator: " ").map(String.init))
        }
        return ids
    }

    static func assertContained(_ identifiers: [String], in window: NSWindow) throws {
        let view = try #require(window.contentView)
        let bounds = view.bounds
        var frames: [String: CGRect] = [:]
        for element in elements(in: view) {
            guard let id = identifier(element), identifiers.contains(id) else { continue }
            let frame = frame(of: element, in: view, window: window)
            guard frame.width > 1, frame.height > 1, frame.intersects(bounds) else { continue }
            #expect(frame.minX >= -2 && frame.maxX <= bounds.maxX + 2, "控件超出横向范围：\(id)")
            frames[id] = frame
        }
        let keys = frames.keys.sorted()
        for index in keys.indices {
            for other in keys.dropFirst(index + 1) {
                let left = frames[keys[index]]!
                let right = frames[other]!
                if left.contains(right) || right.contains(left) { continue }
                let overlap = left.intersection(right)
                #expect(overlap.width < 4 || overlap.height < 4, "控件重叠：\(keys[index]) / \(other)")
            }
        }
    }

    private static func frame(of element: NSObject, in view: NSView, window: NSWindow) -> CGRect {
        if let child = element as? NSView, child.window === window, !child.bounds.isEmpty {
            return child.convert(child.bounds, to: view)
        }
        if let accessible = element as? NSAccessibilityProtocol {
            let screen = accessible.accessibilityFrame()
            if !screen.isEmpty { return view.convert(window.convertFromScreen(screen), from: nil) }
        }
        return .zero
    }

    private static func identifier(_ element: NSObject) -> String? {
        if let accessible = element as? NSAccessibilityProtocol, let id = accessible.accessibilityIdentifier(), !id.isEmpty {
            return id
        }
        return nil
    }

    private static func elements(in root: NSView?) -> [NSObject] {
        guard let root else { return [] }
        var queue: [NSObject] = [root]
        var result: [NSObject] = []
        var visited: Set<ObjectIdentifier> = []
        while let element = queue.popLast() {
            guard visited.insert(ObjectIdentifier(element)).inserted else { continue }
            result.append(element)
            if let view = element as? NSView { queue.append(contentsOf: view.subviews) }
            if let accessible = element as? NSAccessibilityProtocol {
                queue.append(contentsOf: (accessible.accessibilityChildren() ?? []).compactMap { $0 as? NSObject })
            }
        }
        return result
    }
}
