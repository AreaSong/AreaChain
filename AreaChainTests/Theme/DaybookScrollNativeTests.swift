import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct DaybookScrollNativeTests {
    @Test(arguments: 0..<5)
    func mountingAndUpdates(form: Int) async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        for upstream in [ScrollIndicatorVisibility.visible, .hidden, .automatic] {
            let state = ScrollContractState()
            let window = makeWindow(ScrollContractHost(state: state, form: form).scrollIndicators(upstream))
            defer { SystemPageHost.release(window) }
            try await SystemPageHost.settle(window)
            let scroll = try #require(ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }.first)
            let overlay = try #require(scroll.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }.first)
            #expect(scroll.hasVerticalScroller == (form >= 3 && upstream != .hidden))
            let identity = ObjectIdentifier(scroll)
            let overlayIdentity = ObjectIdentifier(overlay)
            ScrollNativeEvidence.record(window, label: "form\(form)-initial")
            for progress in [0.0, 0.5, 1.0] {
                let height = try #require(scroll.documentView).bounds.height
                scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, height - scroll.contentSize.height) * progress))
                scroll.reflectScrolledClipView(scroll.contentView)
                try await SystemPageHost.settle(window)
                ScrollNativeEvidence.record(window, label: "form\(form)-programmatic-\(progress)")
            }
            let offset = scroll.contentView.bounds.origin
            state.revision += 1
            try await SystemPageHost.settle(window)
            #expect(scroll.contentView.bounds.origin == offset)
            for count in [120, 3, 0, 100] {
                state.count = count
                try await SystemPageHost.settle(window)
                let scrolls = ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }
                #expect(scrolls.count == 1)
                #expect(scrolls.first.map(ObjectIdentifier.init) == identity)
                #expect(scroll.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }.map(ObjectIdentifier.init)
                    == [overlayIdentity])
                ScrollNativeEvidence.record(window, label: "form\(form)-count\(count)")
                if count < 4 {
                    let knob = try #require(Mirror(reflecting: overlay).children
                        .first { $0.label == "currentKnobRect" }?.value as? NSRect)
                    #expect(knob == .zero)
                }
            }
            #expect(state.mounts == 1)
            let originalWidth = scroll.bounds.width
            window.setContentSize(NSSize(width: 260, height: 200))
            window.contentView?.layoutSubtreeIfNeeded()
            try await SystemPageHost.settle(window)
            #expect(scroll.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }.count == 1)
            #expect(overlay.frame == DaybookFloatingScrollerOverlay.calculateFrame(for: scroll))
            // 原垂直 ScrollView 沿内容取宽，外部 frame 不承诺将其横向拉伸。
            #expect(window.contentView?.bounds.width == 260)
            #expect(scroll.bounds.size == NSSize(width: originalWidth, height: 200))
        }
    }

    @Test(arguments: [0, 5])
    func knobDragUsesWindowDispatch(form: Int) async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let window = makeWindow(ScrollContractHost(state: ScrollContractState(), form: form))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        try await Task.sleep(for: .milliseconds(400))
        let scroll = try #require(ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }.first)
        let overlay = try #require(scroll.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }.first)
        let knob = try #require(Mirror(reflecting: overlay).children
            .first { $0.label == "currentKnobRect" }?.value as? NSRect)
        #expect(!knob.isEmpty)
        #expect(overlay.alphaValue >= 0.05)
        for (type, delta) in [(NSEvent.EventType.leftMouseDown, 0.0), (.leftMouseDragged, 35.0), (.leftMouseUp, 35.0)] {
            let point = overlay.convert(NSPoint(x: knob.midX, y: knob.midY + delta), to: nil)
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            window.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
        #expect(window.isKeyWindow && NSApp.isActive)
        #expect(scroll.contentView.bounds.minY > 0)
        ScrollNativeEvidence.record(window, label: "window-dispatched-knob-drag-form\(form)")
    }

    private func makeWindow<V: View>(_ content: V) -> NSWindow {
        let hosting = NSHostingView(rootView: content)
        hosting.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 240),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentView = hosting
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

}

@MainActor @Observable
private final class ScrollContractState {
    var count = 100
    var revision = 0
    var mounts = 0
}

private struct ScrollContractHost: View {
    var state: ScrollContractState
    var form: Int

    var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<state.count, id: \.self) { index in
                    Text("Synthetic \(index) / \(state.revision)").frame(height: 24)
                }
            }
            .onAppear { state.mounts += 1 }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder var body: some View {
        switch form {
        case 0: content.daybookScroll()
        case 1: content.daybookScroll(featherEdges: false)
        case 2: content.daybookScroll(featherEdges: true)
        case 3: content.daybookScroll(featherHeight: 13)
        case 4: content.daybookScroll(featherEdges: false, featherHeight: 13)
        default:
            // 原 A 装配仅冻结在测试中，和生产入口同场比较窗口事件。
            content.scrollIndicators(.hidden)
                .background(DaybookScrollerConfigurator())
                .modifier(DaybookScrollEdgeFeatherModifier(enabled: false))
        }
    }
}

@MainActor
enum ScrollNativeEvidence {
    static func views(_ window: NSWindow) -> [NSView] {
        func descend(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descend) }
        return window.contentView.map(descend) ?? []
    }

    static func record(_ window: NSWindow, label: String) {
        let nodes = views(window)
        let scrolls = nodes.compactMap { $0 as? NSScrollView }
        let configs = nodes.compactMap { $0 as? DaybookScrollerHostNSView }
        let edges = nodes.compactMap { $0 as? DaybookScrollEdgeObserverNSView }
        let counts = scrolls.map { $0.subviews.filter { $0 is DaybookFloatingScrollerOverlay }.count }
        print("SCROLL_NATIVE \(label) scrolls=\(scrolls.count) configs=\(configs.count) overlays=\(counts) edges=\(edges.count)")
        for (index, scroll) in scrolls.enumerated() {
            print("SCROLL_NATIVE target=\(index) origin=\(scroll.contentView.bounds.origin) size=\(scroll.contentSize) "
                + "document=\(scroll.documentView?.bounds.size ?? .zero) system=\(scroll.hasVerticalScroller)/\(scroll.hasHorizontalScroller) "
                + "alpha=\(scroll.verticalScroller?.alphaValue ?? -1)")
        }
        for edge in edges {
            edge.checkEdges()
            let state = Mirror(reflecting: edge).children.filter { $0.label == "lastTop" || $0.label == "lastBottom" }
                .map { "\($0.label ?? "")=\($0.value)" }.joined(separator: ",")
            print("SCROLL_NATIVE feather \(state)")
        }
    }
}
