import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct QuadrantPreviewOverlayTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionAnchorAndFullTitleForwarding(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = QuadrantPreviewStateProbe()
        probe.excerpt = QuadrantPreviewTestSupport.sixLines
        let direct = support.window(QuadrantPreviewSample(probe: probe), locale: locale, scheme: scheme,
            size: CGSize(width: 340, height: 240))
        try await SystemPageHost.settle(direct)
        let height = try QuadrantPreviewTestSupport.frame(direct).height
        SystemPageHost.release(direct)
        for size in [CGSize(width: 320, height: 240), CGSize(width: 640, height: 420)] {
            for upward in [false, true] {
                for right in [false, true] {
                    try await check(support, scenario: (locale, scheme, size, height), upward: upward, right: right)
                }
            }
        }
    }

    private func check(_ support: SettingsButtonTestSupport,
                       scenario: (locale: String, scheme: ColorScheme, size: CGSize, height: CGFloat),
                       upward: Bool, right: Bool) async throws {
        let probe = QuadrantPreviewStateProbe()
        probe.excerpt = QuadrantPreviewTestSupport.sixLines
        let size = scenario.size
        let anchor = CGRect(x: right ? size.width - 42 : 12, y: upward ? size.height - 36 : 16, width: 30, height: 20)
        let origin = CGPoint(x: min(anchor.minX, size.width - 268),
            y: upward ? anchor.minY - 6 - scenario.height : anchor.maxY + 6)
        let reference = support.window(QuadrantPositionedPreviewSample(probe: probe, origin: origin, size: size),
            locale: scenario.locale, scheme: scenario.scheme, size: size)
        try await SystemPageHost.settle(reference)
        let expected = try RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(reference))
        SystemPageHost.release(reference)
        let window = support.window(QuadrantPreviewSample(probe: probe, anchor: anchor, size: size),
            locale: scenario.locale, scheme: scenario.scheme, size: size)
        defer { SystemPageHost.release(window) }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await RowBubbleTestSupport.move(NSPoint(x: size.width - 2, y: size.height - 2), in: window)
        let rect = try QuadrantPreviewTestSupport.frame(window, probe: probe)
        // 原标识传播到文字/提示，AX 框不等于外壳。实际 260pt 几何由直接生产布局与整图证明。
        #expect(abs(rect.minX - origin.x - 8) < 1)
        #expect(try expected == RowBubbleTestSupport.bytes(OverlaySurfaceTestSupport.bitmap(window)))
        let surface = CGRect(x: origin.x, y: size.height - origin.y - scenario.height,
            width: 260, height: scenario.height)
        #expect(surface.contains(rect) && surface.minX >= 0 && surface.maxX <= size.width)
        QuadrantPreviewTestSupport.assertText(window, probe: probe, locale: scenario.locale, copied: false)
        try QuadrantPreviewTestSupport.record(window,
            name: "overlay-\(scenario.locale)-\(scenario.scheme)-\(Int(size.width))-\(upward)-\(right)", frame: surface, probe: probe)
        try await RowBubbleTestSupport.move(NSPoint(x: surface.midX, y: surface.midY), in: window)
        #expect(probe.hovers.last == true, "\(scenario.locale)/\(scenario.scheme) \(size) up=\(upward) right=\(right)")
        try await SurfaceEventTestSupport.click(NSPoint(x: surface.midX, y: surface.midY), in: window)
        #expect(probe.copies == [probe.title] && probe.title != probe.excerpt)
        QuadrantPreviewTestSupport.assertText(window, probe: probe, locale: scenario.locale, copied: true)
        try await RowBubbleTestSupport.move(NSPoint(x: size.width - 2, y: size.height - 2), in: window)
        #expect(probe.hovers.last == false)
        try await SystemPageHost.settle(window)
        #expect(probe.copies.count == 1 && probe.appearances == 1)
    }
}
