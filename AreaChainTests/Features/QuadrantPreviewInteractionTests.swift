import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct QuadrantPreviewInteractionTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func nativeFeedbackUpdateAndRemount(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = QuadrantPreviewStateProbe()
        probe.excerpt = QuadrantPreviewTestSupport.sixLines
        let window = support.window(QuadrantPreviewSample(probe: probe), locale: locale, scheme: scheme,
            size: CGSize(width: 340, height: 240))
        defer { SystemPageHost.release(window) }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        let original = try QuadrantPreviewTestSupport.frame(window)
        let name = "feedback-\(locale)-\(scheme)"
        try record(window, probe: probe, name: name + "-normal")
        try await RowBubbleTestSupport.move(NSPoint(x: original.midX, y: original.midY), in: window)
        #expect(probe.hovers.last == true)
        try record(window, probe: probe, name: name + "-hover")
        try await SurfaceEventTestSupport.click(NSPoint(x: original.midX, y: original.midY), in: window)
        #expect(probe.copies == ["no-argument"])
        QuadrantPreviewTestSupport.assertText(window, probe: probe, locale: locale, copied: true)
        try record(window, probe: probe, name: name + "-copied")
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        #expect(probe.hovers.last == false)
        try await Task.sleep(for: .milliseconds(1300))
        QuadrantPreviewTestSupport.assertText(window, probe: probe, locale: locale, copied: false)
        #expect(try QuadrantPreviewTestSupport.frame(window) == original)
        #expect(probe.copies.count == 1 && probe.appearances == 1)
        try record(window, probe: probe, name: name + "-reset")
        try await updateAndRemount(window, probe: probe, locale: locale, name: name)
    }

    private func updateAndRemount(_ window: NSWindow, probe: QuadrantPreviewStateProbe,
                                  locale: String, name: String) async throws {
        let rect = try QuadrantPreviewTestSupport.frame(window)
        try await SurfaceEventTestSupport.click(NSPoint(x: rect.midX, y: rect.midY), in: window)
        probe.excerpt = "Updated 外部摘要"
        probe.showsHint = false
        try await SystemPageHost.settle(window)
        QuadrantPreviewTestSupport.assertText(window, probe: probe, locale: locale, copied: true)
        #expect(probe.appearances == 1 && probe.copies.count == 2)
        try await Task.sleep(for: .milliseconds(1300))
        QuadrantPreviewTestSupport.assertText(window, probe: probe, locale: locale, copied: false)
        try record(window, probe: probe, name: name + "-updated")
        let updated = try QuadrantPreviewTestSupport.frame(window)
        try await SurfaceEventTestSupport.click(NSPoint(x: updated.midX, y: updated.midY), in: window)
        probe.mounted = false
        try await SystemPageHost.settle(window)
        probe.mounted = true
        try await SystemPageHost.settle(window)
        QuadrantPreviewTestSupport.assertText(window, probe: probe, locale: locale, copied: false)
        #expect(probe.appearances == 2 && probe.copies.count == 3)
        try await Task.sleep(for: .milliseconds(1300))
        #expect(probe.copies.count == 3)
        try record(window, probe: probe, name: name + "-remounted")
    }

    @Test func nativeHitRegionExcludesCornerAndShadow() async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = QuadrantPreviewStateProbe()
        let window = support.window(QuadrantPreviewSample(probe: probe), size: CGSize(width: 340, height: 240))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        let rect = try QuadrantPreviewTestSupport.frame(window)
        for point in [NSPoint(x: rect.minX - 8, y: rect.midY), NSPoint(x: rect.maxX + 2, y: rect.midY),
                      NSPoint(x: rect.midX, y: rect.minY - 3), NSPoint(x: rect.minX + 0.5, y: rect.minY + 0.5)] {
            try await SurfaceEventTestSupport.click(point, in: window)
            #expect(probe.copies.isEmpty)
        }
        // 居中描边的内侧属于原圆角 contentShape，必须严格成功，不能以旧/新均失败作为兼容。
        try await SurfaceEventTestSupport.click(NSPoint(x: rect.minX + 1, y: rect.midY), in: window)
        #expect(probe.copies.count == 1)
        let current = try QuadrantPreviewTestSupport.frame(window)
        try await SurfaceEventTestSupport.click(NSPoint(x: current.midX, y: current.midY), in: window, delivery: "queue")
        #expect(probe.copies.count == 2)
    }

    private func record(_ window: NSWindow, probe: QuadrantPreviewStateProbe, name: String) throws {
        try QuadrantPreviewTestSupport.record(window, name: name,
            frame: QuadrantPreviewTestSupport.frame(window), probe: probe)
    }
}
