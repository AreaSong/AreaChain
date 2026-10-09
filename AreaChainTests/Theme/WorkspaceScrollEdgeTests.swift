import AppKit
import ObjectiveC
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WorkspaceScrollEdgeTests {
    @Test(arguments: [false, true])
    func topOnlyPolicyLeavesFixedControlsAndBottomOpaque(reduceTransparency: Bool) async throws {
        let restore = try replaceTransparencyRead(reduceTransparency)
        defer { restore() }
        let state = FeatherTestState()
        state.enabled = false
        let root = VStack(spacing: 0) {
            Rectangle().fill(Color.blue).frame(height: 40)
            FeatherTestContent(state: state)
        }
        .environment(\.daybookScrollTopEdge, true)
        .background(Color.black)
        let window = ScrollOwnershipEvidence.window(root, locale: "en", size: .init(width: 300, height: 240))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let edges = ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookScrollEdgeObserverNSView }
        #expect(edges.count == 1)
        let edge = try #require(edges.first)
        let scroll = try #require(edge.currentScrollView)
        let before = scroll.bounds
        for offset in [0.0, 100, 0] {
            scroll.contentView.scroll(to: .init(x: 0, y: offset))
            try await Task.sleep(for: .milliseconds(300))
            let bitmap = try capture(window)
            let scale = CGFloat(bitmap.pixelsHigh) / 240
            let x = bitmap.pixelsWide / 2
            func color(_ y: CGFloat) throws -> NSColor {
                try #require(bitmap.colorAt(x: x, y: Int(y * scale))?.usingColorSpace(.deviceRGB))
            }
            #expect(try color(20).blueComponent > 0.8)
            #expect(try color(120).redComponent > 0.8)
            #expect(try color(238).redComponent > 0.8)
            let top = try color(41).redComponent
            #expect(offset > 0 && !reduceTransparency ? top < 0.65 : top > 0.8)
            #expect(scroll.bounds == before)
            #expect(edge.currentScrollView === scroll)
        }
        state.height = 60
        try await SystemPageHost.settle(window)
        #expect(FeatherTestEvidence.state(edge) == [false, false])
        state.visible = false
        try await SystemPageHost.settle(window)
        #expect(edge.currentScrollView == nil)
    }

    private func capture(_ window: NSWindow) throws -> NSBitmapImageRep {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    private func replaceTransparencyRead(_ reduced: Bool) throws -> () -> Void {
        let method = try #require(class_getInstanceMethod(NSWorkspace.self,
            #selector(getter: NSWorkspace.accessibilityDisplayShouldReduceTransparency)))
        let block: @convention(block) (AnyObject) -> Bool = { _ in reduced }
        let replacement = imp_implementationWithBlock(block)
        let original = method_setImplementation(method, replacement)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                   object: NSWorkspace.shared)
        return {
            method_setImplementation(method, original)
            imp_removeBlock(replacement)
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                       object: NSWorkspace.shared)
        }
    }
}
