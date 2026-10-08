import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LivePreviewSurfaceTests {
    @Test func mergedActionsKeepProjectionAndFeedback() async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = LivePreviewProbe(diary: true, long: true)
        let window = support.window(LivePreviewSample(probe: probe).frame(width: 316).padding(32),
                                    size: NSSize(width: 380, height: 180))
        window.title = "Diary M — injected synthetic copy"
        defer { SystemPageHost.release(window) }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        let anchor = try #require(OverlaySurfaceTestSupport.descendants(window.contentView)
            .first { $0.identifier?.rawValue == "syntax.preview.sample" })
        let frame = try NativeSyntaxUI.frame("syntax.preview.sample", in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: frame.midX, y: frame.midY), in: window)
        for index in 0..<3 {
            probe.copySuccess = index != 1
            probe.sensitive = index == 2
            try await SystemPageHost.settle(window)
            // 每个合成场景重新自然进入卡片；静止指针不保证内容切换后仍有悬停动作。
            try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
            try await RowBubbleTestSupport.move(NSPoint(x: frame.midX, y: frame.midY), in: window)
            try DiaryDiagnostic.record(window, phase: "action-\(index)-ready")
            let performed = try DiaryDiagnostic.performCopy(in: window)
            #expect(performed)
            try #require(probe.copies.count == index + 1, "命名辅助动作应到达注入复制入口")
            print("DIARY_M AX actionReturned=\(performed) copyResult=\(probe.copySuccess)")
            var feedback: [NSBitmapImageRep] = []
            let expected = probe.sensitive ? L10n.string("diary.private.title", locale: Locale(identifier: "en"))
                : NaturalLanguageParser.parseDiaryCapture(probe.text).cleanTitle
            #expect(probe.copies[index].0 == expected && probe.copies[index].1 == probe.sensitive)
            for suggestions in [false, true, false] {
                probe.suggestions = suggestions
                try await SystemPageHost.settle(window)
                try DiaryDiagnostic.record(window, phase: "action-\(index)-feedback-\(suggestions)")
                feedback.append(try OverlaySurfaceTestSupport.bitmap(window))
                #expect(OverlaySurfaceTestSupport.descendants(window.contentView).contains { $0 === anchor })
                #expect(probe.appearances == 1 && probe.copies.count == index + 1)
            }
            print("DIARY_M AX copy index=\(index) result=\(probe.copySuccess) projectionMatches=\(probe.copies[index].0 == expected)")
            try await Task.sleep(for: .milliseconds(1400))
            try DiaryDiagnostic.record(window, phase: "action-\(index)-reset")
            for bitmap in feedback {
                #expect(try DiaryDiagnostic.recognizedStrings(bitmap).contains { $0.contains("Copied") } == probe.copySuccess)
            }
            #expect(try !DiaryDiagnostic.recognizedStrings(OverlaySurfaceTestSupport.bitmap(window)).contains { $0.contains("Copied") })
        }
        let menuNode = try #require(MenuButtonTestSupport.menus(in: window).first)
        let menu = try await MenuButtonTestSupport.openAndEscape(menuNode, in: window)
        #expect(probe.closes == 0)
        try MenuButtonTestSupport.dispatch("Close", in: menu)
        #expect(probe.closes == 1 && probe.copies.count == 3 && probe.appearances == 1)
        #expect(window.isKeyWindow && !support.container.mainContext.hasChanges)
    }

    @Test(arguments: [false, true])
    func mergedPreviewDiagnostic(lower: Bool) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = LivePreviewProbe(diary: true, long: true)
        let window = support.window(VStack {
            if lower { Spacer().frame(height: 300) }
            LivePreviewSample(probe: probe).frame(width: 316)
            Spacer()
        }.padding(32), size: NSSize(width: 380, height: 540))
        defer { SystemPageHost.release(window) }
        let pointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(pointer) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        try DiaryDiagnostic.record(window, phase: "preview-\(lower)-before")
        let frame = try NativeSyntaxUI.frame("syntax.preview.sample", in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: frame.midX, y: frame.midY), in: window)
        try await Task.sleep(for: .milliseconds(450))
        try DiaryDiagnostic.record(window, phase: "preview-\(lower)-hover")
        #expect(probe.copies.isEmpty && probe.closes == 0 && probe.appearances == 1)
        #expect(window.isKeyWindow && !support.container.mainContext.hasChanges)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionPreviewsKeepCompleteEdges(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        for width: CGFloat in [240, 356] {
            for diary in [false, true] {
                for long in [false, true] {
                    let probe = LivePreviewProbe(diary: diary, long: long)
                    let window = support.window(LivePreviewSample(probe: probe).frame(width: width).padding(32),
                        locale: locale, scheme: scheme, size: NSSize(width: width + 64, height: 300))
                    defer { SystemPageHost.release(window) }
                    try await SystemPageHost.settle(window)
                    for suggestions in [false, true] {
                        probe.suggestions = suggestions
                        try await SystemPageHost.settle(window)
                        let frame = try NativeSyntaxUI.frame("syntax.preview.sample", in: window)
                        #expect(frame.width == width && frame.minX >= 32)
                        #expect(frame.height >= (diary ? 46 : 36))
                        #expect(frame.maxY <= 268 && frame.minY >= 32)
                        if !diary {
                            let close = try SettingsButtonTestSupport.button("common.close", locale: locale, in: window)
                            let rect = try SettingsButtonTestSupport.frame(close, in: window)
                            #expect(frame.contains(rect) && rect.width == 18 && rect.height == 18)
                        }
                        let name = "preview-\(diary)-\(long)-\(suggestions)-\(locale)-\(scheme)-\(Int(width))"
                        try OverlaySurfaceTestSupport.record(window, name: name)
                    }
                    #expect(probe.appearances == 1 && probe.copies.isEmpty && probe.closes == 0)
                    #expect(!support.container.mainContext.hasChanges)
                }
            }
        }
    }

    @Test(arguments: [false, true])
    func decorationSwitchKeepsNativeIdentityAndCloseCallback(diary: Bool) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let probe = LivePreviewProbe(diary: diary)
        let window = support.window(LivePreviewSample(probe: probe).frame(width: 316).padding(32),
                                    size: NSSize(width: 380, height: 180))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let anchor = try #require(OverlaySurfaceTestSupport.descendants(window.contentView)
            .first { $0.identifier?.rawValue == "syntax.preview.sample" })
        let frame = try NativeSyntaxUI.frame("syntax.preview.sample", in: window)
        for suggestions in [true, false, true] {
            probe.suggestions = suggestions
            try await SystemPageHost.settle(window)
            #expect(OverlaySurfaceTestSupport.descendants(window.contentView).contains { $0 === anchor })
            #expect(try NativeSyntaxUI.frame("syntax.preview.sample", in: window) == frame)
            #expect(probe.appearances == 1 && probe.copies.isEmpty && probe.closes == 0)
        }
        if !diary {
            try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("common.close", in: window), in: window)
            #expect(probe.closes == 1 && probe.suggestions)
        }
        #expect(!support.container.mainContext.hasChanges)
    }

    @Test(arguments: ["en", "zh-Hans"])
    func sensitivePreviewKeepsOriginalProjectionAndInjectedCopy(locale: String) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let probe = LivePreviewProbe(diary: true, long: true)
        probe.sensitive = true
        let window = support.window(LivePreviewSample(probe: probe).frame(width: 316).padding(32),
                                    locale: locale, size: NSSize(width: 380, height: 180))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let labels = SettingsButtonTestSupport.elements(window.contentView).compactMap {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String
        }
        #expect(!labels.contains { $0.contains("Synthetic long") || $0.contains("合成备注") })
        try OverlaySurfaceTestSupport.record(window, name: "preview-sensitive-hidden-\(locale)")
        let originalPointer = NSEvent.mouseLocation
        defer { warpPointer(originalPointer) }
        let frame = try NativeSyntaxUI.frame("syntax.preview.sample", in: window)
        let point = NSPoint(x: frame.midX, y: frame.midY)
        warpPointer(window.convertPoint(toScreen: point))
        window.acceptsMouseMovedEvents = true
        let moved = try #require(NSEvent.mouseEvent(with: .mouseMoved, location: point,
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0))
        NSApp.sendEvent(moved)
        try await SystemPageHost.settle(window)
        // 辅助动作只触发已注入的回调；不调用默认 NSPasteboard 路径。
        #expect(try DiaryDiagnostic.performCopy(in: window, locale: locale))
        try await SystemPageHost.settle(window)
        #expect(probe.copies.count == 1)
        #expect(probe.copies.first?.0 == L10n.string("diary.private.title", locale: Locale(identifier: locale)))
        #expect(probe.copies.first?.1 == true)
        var feedback: [NSBitmapImageRep] = []
        for suggestions in [true, false] {
            probe.suggestions = suggestions
            try await SystemPageHost.settle(window)
            feedback.append(try OverlaySurfaceTestSupport.bitmap(window))
            #expect(probe.appearances == 1 && probe.copies.count == 1)
        }
        let copied = L10n.string("diary.copied", locale: Locale(identifier: locale))
        for bitmap in feedback {
            #expect(try DiaryDiagnostic.recognizedStrings(bitmap, locale: locale).contains { $0.contains(copied) })
        }
        try OverlaySurfaceTestSupport.record(window, name: "preview-sensitive-\(locale)")
        #expect(!support.container.mainContext.hasChanges)
    }

    private func warpPointer(_ point: NSPoint) {
        // CG 坐标以主屏左上为原点；只移动测试指针并在退出时恢复，不修改系统偏好。
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        #expect(CGWarpMouseCursorPosition(CGPoint(x: point.x, y: top - point.y)) == .success)
    }
}

@Observable @MainActor
final class LivePreviewProbe {
    let diary: Bool
    let text: String
    var suggestions = false
    var sensitive = false
    var appearances = 0
    var closes = 0
    var copies: [(String, Bool)] = []
    var copySuccess = true

    init(diary: Bool, long: Bool = false) {
        self.diary = diary
        text = long
            ? "Synthetic long 合成长标题需要保持截断并保留原悬停入口 #工作 #one #two #three #four #five !p1 @09:00 // 合成备注正文"
            : "Synthetic 合成 #工作"
    }
}

struct LivePreviewSample: View {
    let probe: LivePreviewProbe

    var body: some View {
        Group {
            if probe.diary {
                LiveDiaryComposerPreview(text: probe.text, isSensitiveExternal: probe.sensitive,
                    showsSuggestions: probe.suggestions,
                    onCopy: { probe.copies.append(($0, $1)); return probe.copySuccess }, onClose: { probe.closes += 1 })
            } else {
                LiveComposerPreviewHeader(text: probe.text, showsSuggestions: probe.suggestions,
                                          onClose: { probe.closes += 1 })
            }
        }
        .onAppear { probe.appearances += 1 }
        .background(SyntaxViewAnchor("syntax.preview.sample"))
    }
}
