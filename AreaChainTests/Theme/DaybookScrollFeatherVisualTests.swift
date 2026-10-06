import AppKit
import ObjectiveC
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookScrollFeatherVisualTests {
    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func actualGradientAndUnchangedCenter(locale: String, reduced: Bool) async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let restoreMotion = try replaceMotionRead(reduced)
        defer { restoreMotion() }
        let state = FeatherTestState()
        let content = FeatherTestContent(state: state).background(Color.black)
        let window = ScrollOwnershipEvidence.window(content, locale: locale, size: .init(width: 300, height: 240))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        #expect(state.reduced == reduced)
        let scroll = try #require(ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }.first)
        let size = scroll.bounds.size
        for progress in [0.0, 0.5, 1.0] {
            let maximum = try #require(scroll.documentView).bounds.height - scroll.documentVisibleRect.height
            scroll.contentView.scroll(to: .init(x: 0, y: maximum * progress))
            try await Task.sleep(for: .milliseconds(250))
            let bitmap = try capture(window, name: "\(locale)-\(reduced)-\(progress)")
            let scale = CGFloat(bitmap.pixelsHigh) / 240
            let x = bitmap.pixelsWide / 2
            let red = try [1, 10, 120, 229, 238].map { y in
                try #require(bitmap.colorAt(x: x, y: Int(CGFloat(y) * scale))?.usingColorSpace(.deviceRGB)).redComponent
            }
            print("FEATHER_PIXELS \(locale) reduced=\(reduced) p=\(progress) red=\(red)")
            #expect(red[2] > 0.8 && abs(red[1] - red[2]) < 0.03 && abs(red[3] - red[2]) < 0.03)
            #expect(progress > 0 ? red[0] < red[2] * 0.65 : abs(red[0] - red[2]) < 0.03)
            #expect(progress < 1 ? red[4] < red[2] * 0.65 : abs(red[4] - red[2]) < 0.03)
            #expect(scroll.bounds.size == size && !scroll.hasVerticalScroller)
        }
    }

    @Test func directWheelAndWindowKnobAutomaticallyUpdate() async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let window = fixture.window(FeatherTestContent(state: FeatherTestState()),
            size: .init(width: 300, height: 240))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let scroll = try #require(ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }.first)
        let edge = try #require(ScrollNativeEvidence.views(window)
            .compactMap { $0 as? DaybookScrollEdgeObserverNSView }.first)
        let cg = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
            wheel1: -80, wheel2: 0, wheel3: 0))
        try #require(window.isKeyWindow && NSApp.isActive)
        scroll.scrollWheel(with: try #require(NSEvent(cgEvent: cg)))
        try await Task.sleep(for: .milliseconds(150))
        #expect(scroll.contentView.bounds.minY > 10)
        #expect(FeatherTestEvidence.state(edge) == [true, true])
        print("FEATHER_DIRECT_WHEEL offset=\(scroll.contentView.bounds.origin)")
        scroll.contentView.scroll(to: .zero)
        try await Task.sleep(for: .milliseconds(100))
        #expect(FeatherTestEvidence.state(edge) == [false, true])
        try await ScrollOwnershipEvidence.drag(scroll, among: [scroll], in: window, label: "feather-10E")
        #expect(FeatherTestEvidence.state(edge) == [true, true])
    }

    // 沿原 DaybookSegmentedMotionTests：仅替换测试进程公开 getter，不写系统偏好。
    private func replaceMotionRead(_ reduced: Bool) throws -> () -> Void {
        let method = try #require(class_getInstanceMethod(NSWorkspace.self,
            #selector(getter: NSWorkspace.accessibilityDisplayShouldReduceMotion)))
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

    private func capture(_ window: NSWindow, name: String) throws -> NSBitmapImageRep {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let directory = FileManager.default.temporaryDirectory.appending(path: "ScrollFeather10E")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: directory.appending(path: name + ".png"))
        print("FEATHER_CAPTURE \(directory.path)/\(name).png")
        return bitmap
    }
}
