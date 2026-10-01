import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookButtonInteractionTests {
    @Test(arguments: [false, true])
    func disabledButtonsRejectMouseAndShortcut(disabled: Bool) async throws {
        var actions = 0
        let content = HStack {
            DaybookIconButton(systemName: "trash", label: "alert.trash.move", role: .destructive) { actions += 1 }
                .accessibilityIdentifier("button.icon")
            Button("common.save") { actions += 1 }
                .buttonStyle(DaybookButtonStyle(.prominent))
                .accessibilityIdentifier("button.text")
            CommandReturnButton(enabled: true, label: "common.save") { actions += 1 }
                .keyboardShortcut(.return, modifiers: .command)
        }.disabled(disabled).padding()
        let window = window(content)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for id in ["button.icon", "button.text", "syntax.commandReturn.button"] {
            try click(NativeSyntaxUI.center(id, in: window), in: window)
            try await SystemPageHost.settle(window)
        }
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36
        ))
        _ = window.performKeyEquivalent(with: event)
        try await SystemPageHost.settle(window)
        #expect(actions == (disabled ? 0 : 4))
        #expect(accessibilityLabel("button.icon", in: window) == L10n.string("alert.trash.move", locale: Locale(identifier: "en")))
    }

    @Test(arguments: ["zh-Hans", "en"], [false, true])
    func galleryRenders(locale: String, dark: Bool) async throws {
        let window = window(DaybookControlsPreview(localeID: locale, dark: dark, longLabels: true),
                            size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        try await SystemPageHost.settle(window)
        let name = L10n.string("dev.controls.sample", locale: Locale(identifier: locale))
        #expect(name != "dev.controls.sample")
        #expect(SystemPageHost.labels(in: window).contains(name))
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AreaChainButtonQA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("buttons-\(locale)-\(dark ? "dark" : "light").png"))
    }

    /// 通过测试环境变量保留窗口供人工交互；默认只做挂载，不影响日常测试耗时。
    @Test func interactiveGallery() async throws {
        let window = window(DaybookControlsPreview(), size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        window.title = "Daybook Controls — Buttons (QA)"
        try await NativeSyntaxUI.prepareFocus(in: window)
        let seconds = min(600, max(0, Int(ProcessInfo.processInfo.environment["AREACHAIN_CONTROLS_PREVIEW_SECONDS"] ?? "0") ?? 0))
        let deadline = ContinuousClock.now + .seconds(seconds)
        while window.isVisible && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func window<Content: View>(_ content: Content, size: NSSize = NSSize(width: 400, height: 160)) -> NSWindow {
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        let host = NSHostingView(rootView: content.environment(\.locale, Locale(identifier: "en")))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setContentSize(size)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func accessibilityLabel(_ identifier: String, in window: NSWindow) -> String? {
        guard let root = window.contentView else { return nil }
        var queue: [NSObject] = [root]
        var visited = Set<ObjectIdentifier>()
        while let node = queue.popLast() {
            guard visited.insert(ObjectIdentifier(node)).inserted else { continue }
            func value(_ name: String) -> Any? {
                let selector = NSSelectorFromString(name)
                return node.responds(to: selector) ? node.perform(selector)?.takeUnretainedValue() : nil
            }
            if value("accessibilityIdentifier") as? String == identifier,
               let name = (value("accessibilityLabel") ?? value("accessibilityTitle")) as? String {
                return name
            }
            if let view = node as? NSView { queue.append(contentsOf: view.subviews) }
            if let children = value("accessibilityChildren") as? [NSObject] { queue.append(contentsOf: children) }
        }
        return nil
    }

    private func click(_ point: NSPoint, in window: NSWindow) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            NSApp.sendEvent(event)
        }
    }
}
