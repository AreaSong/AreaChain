import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct RowBubbleInteractionTests {
    @Test(arguments: [false, true], [false, true])
    func nativeFeedbackAndNilCallback(note: Bool, callback: Bool) async throws {
        for locale in ["en", "zh-Hans"] {
            for scheme in [ColorScheme.light, .dark] {
                try await feedback(note: note, callback: callback, locale: locale, scheme: scheme)
            }
        }
    }

    private func feedback(note: Bool, callback: Bool, locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = RowBubbleProbe()
        let window = support.window(RowBubbleSample(probe: probe, note: note, callback: callback)
            .transaction { $0.disablesAnimations = false }, locale: locale, scheme: scheme,
                                    size: NSSize(width: 340, height: 340))
        defer { SystemPageHost.release(window) }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        let rect = try NativeSyntaxUI.frame("syntax.bubble.sample", in: window)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let name = "native-\(note)-\(callback)-\(locale)-\(scheme)"
        try RowBubbleTestSupport.record(window, name: name + "-normal", probe: probe)
        try await RowBubbleTestSupport.move(center, in: window)
        #expect(probe.hovers.last == true)
        try RowBubbleTestSupport.record(window, name: name + "-hover", probe: probe)
        try await SurfaceEventTestSupport.click(center, in: window)
        try await Task.sleep(for: .milliseconds(180))
        #expect(probe.copies == (callback ? 1 : 0))
        #expect(RowBubbleTestSupport.copied(window, locale: locale) == callback)
        try RowBubbleTestSupport.record(window, name: name + "-copied-hover", probe: probe)
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        #expect(probe.hovers.last == false)
        #expect(RowBubbleTestSupport.copied(window, locale: locale) == callback)
        try RowBubbleTestSupport.record(window, name: name + "-copied", probe: probe)
        try await RowBubbleTestSupport.move(center, in: window)
        try await Task.sleep(for: .milliseconds(1500))
        #expect(!RowBubbleTestSupport.copied(window, locale: locale))
        #expect(probe.hovers.last == true && probe.appearances == 1)
        try RowBubbleTestSupport.record(window, name: name + "-reset-hover", probe: probe)
        try await remount(probe, window: window, center: center, callback: callback, scenario: (locale, name))
    }

    private func remount(_ probe: RowBubbleProbe, window: NSWindow, center: NSPoint, callback: Bool,
                         scenario: (locale: String, name: String)) async throws {
        probe.mounted = false
        try await SystemPageHost.settle(window)
        probe.mounted = true
        try await SystemPageHost.settle(window)
        #expect(probe.appearances == 2 && !RowBubbleTestSupport.copied(window, locale: scenario.locale))
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        try await RowBubbleTestSupport.move(center, in: window)
        try await SurfaceEventTestSupport.click(center, in: window)
        #expect(probe.copies == (callback ? 2 : 0))
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        try await Task.sleep(for: .milliseconds(1500))
        let pointer = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        #expect(!RowBubbleTestSupport.copied(window, locale: scenario.locale) && probe.hovers.last == false,
                "\(scenario.name) pointer=\(pointer) hovers=\(probe.hovers)")
        // 语言、主题与气泡类型必须进入文件名，避免后续场景覆盖复位证据。
        try RowBubbleTestSupport.record(window, name: scenario.name + "-reset-outside", probe: probe)
        try await SurfaceEventTestSupport.click(center, in: window)
        probe.mounted = false
        try await SystemPageHost.settle(window)
        probe.mounted = true
        try await SystemPageHost.settle(window)
        #expect(probe.appearances == 3 && !RowBubbleTestSupport.copied(window, locale: scenario.locale))
        #expect(probe.copies == (callback ? 3 : 0))
    }

    @Test(arguments: [false, true], [false, true])
    func nativeContentCornersArrowAndShadow(note: Bool, upward: Bool) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = RowBubbleProbe()
        let window = support.window(RowBubbleSample(probe: probe, note: note, upward: upward, shift: -36),
                                    size: NSSize(width: 340, height: 340))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let rect = try NativeSyntaxUI.frame("syntax.bubble.sample", in: window)
        // 每次取当前尺寸；标题反馈会增加高度，不能拿首次几何误判命中。
        for offset: CGFloat in [8, 2] {
            try await SurfaceEventTestSupport.click(NSPoint(x: rect.minX - offset, y: rect.midY), in: window)
            #expect(probe.copies == 0, "完整外部阴影不属于点击区")
        }
        try await SurfaceEventTestSupport.click(NSPoint(x: rect.minX + 0.5, y: rect.minY + 0.5), in: window)
        #expect(probe.copies == (note ? 1 : 0), "标题圆角外侧排除，备注外层矩形包含")
        if note {
            let arrowY = upward ? rect.minY + 2 : rect.maxY - 2
            try await SurfaceEventTestSupport.click(NSPoint(x: rect.minX + 47, y: arrowY), in: window)
            #expect(probe.copies == 2, "上下箭头仍位于原矩形点击区域")
        }
        let count = probe.copies
        try await SurfaceEventTestSupport.click(NSPoint(x: rect.midX, y: rect.midY), in: window)
        #expect(probe.copies == count + 1)
        try RowBubbleTestSupport.record(window, name: "boundary-\(note)-\(upward)", probe: probe)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func directProductionVisualMatrix(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        for note in [false, true] {
            for long in [false, true] {
                for upward in [false, true] {
                    let probe = RowBubbleProbe()
                    let text = long ? String(repeating: "Synthetic 合成文本需要换行。", count: 12) : "Synthetic 合成"
                    let sample = RowBubbleSample(probe: probe, note: note, callback: false, upward: upward,
                        shift: upward ? -80 : 24, text: text, header: "diary.copied")
                    let window = support.window(sample, locale: locale, scheme: scheme, size: NSSize(width: 340, height: 340))
                    defer { SystemPageHost.release(window) }
                    try await SystemPageHost.settle(window)
                    let rect = try NativeSyntaxUI.frame("syntax.bubble.sample", in: window)
                    #expect(rect.width == (note ? 210 : 260))
                    #expect(rect.minX >= 32 && rect.maxX <= 308 && rect.minY > 24 && rect.maxY < 316)
                    #expect(SurfaceConsumerUI.strings(window).contains(text))
                    if note { #expect(RowBubbleTestSupport.copied(window, locale: locale)) }
                    #expect(probe.copies == 0 && probe.appearances == 1)
                    try RowBubbleTestSupport.record(window,
                        name: "matrix-\(locale)-\(scheme)-\(note)-\(long)-\(upward)", probe: probe)
                }
            }
        }
    }
}
