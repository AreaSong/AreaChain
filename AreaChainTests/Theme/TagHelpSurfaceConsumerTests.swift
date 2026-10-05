import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagHelpSurfaceConsumerTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func originalGalleryShowsFullAndClippedSurfaces(scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let window = support.window(DaybookControlsPreview(localeID: "en", dark: scheme == .dark, longLabels: false),
            scheme: scheme, size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let label = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == "Production help · original clipShape"
        })
        try await SettingsButtonTestSupport.reveal(label, in: window)
        let frame = try SettingsButtonTestSupport.frame(label, in: window)
        #expect(try #require(window.contentView).bounds.contains(frame))
        try OverlaySurfaceTestSupport.record(window, name: "e-gallery-\(scheme)")
    }

    @Test func titleNativeHoverKeepsOriginalTagExclusion() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let title = String(repeating: "Synthetic long title ", count: 4).trimmingCharacters(in: .whitespaces)
        let probe = TagDetailProbe(text: title + " #one #two #three #four #five #six")
        let window = support.window(TagDetailSample(probe: probe).frame(width: 316).padding(32),
            size: NSSize(width: 380, height: 320))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        #expect(SurfaceConsumerUI.strings(window).contains("All tags"))
        let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == title
        })
        try await SurfaceConsumerUI.hover(node, in: window) {
            #expect(!SurfaceConsumerUI.strings(window).contains("All tags"))
            #expect(probe.closes == 0 && probe.appearances == 1 && !support.container.mainContext.hasChanges)
            // 只观察原标题气泡出现；绝不点击默认复制路径。
            try OverlaySurfaceTestSupport.record(window, name: "e-tags-title-hover")
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func tagConditionsAndCandidateRoundTrip(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        // 以原估宽算法的实际临界输入刻画出现条件，不注入私有显示状态。
        let tags = ["one", "two"]
        let titles = (1...80).map { String(repeating: "a", count: $0) }
        let fitting = try #require(titles.last { LiveComposerPreviewHeader.canFit(title: $0, tags: tags,
            hasTime: false, hasPriority: false) })
        let texts = ["A #one", fitting + " #one #two", fitting + "a #one #two",
                     "合成长标题 #很长的标签名称需要截断 #anotherLongTag #three #four #five #six #seven"]
        for width: CGFloat in [240, 356] {
            for (index, text) in texts.enumerated() {
                let probe = TagDetailProbe(text: text)
                let window = support.window(TagDetailSample(probe: probe).frame(width: width).padding(32),
                    locale: locale, scheme: scheme, size: NSSize(width: width + 64, height: 320))
                defer { SystemPageHost.release(window) }
                try await NativeSyntaxUI.prepareFocus(in: window)
                for suggestions in [false, true, false] {
                    probe.suggestions = suggestions
                    try await SystemPageHost.settle(window)
                    let title = L10n.string("syntax.preview.allTags", locale: Locale(identifier: locale))
                    let visible = SurfaceConsumerUI.strings(window).contains(title)
                    #expect(visible == (index >= 2 && !suggestions))
                    #expect(probe.appearances == 1 && probe.closes == 0)
                    if visible {
                        let scroll = try #require(OverlaySurfaceTestSupport.descendants(window.contentView)
                            .compactMap { $0 as? NSScrollView }.first)
                        #expect(scroll.frame.width <= 140 && scroll.frame.height <= 120)
                        let names = NaturalLanguageParser.parseTaskCapture(text).tagNames
                        let shown = SurfaceConsumerUI.strings(window)
                        for tag in names { #expect(shown.contains("#" + tag)) }
                        let rows = try names.map { tag in
                            let nodes = SettingsButtonTestSupport.elements(window.contentView).filter {
                                SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == "#" + tag
                            }
                            #expect(nodes.count == 1, "标签行不能重复挂载")
                            return try SettingsButtonTestSupport.frame(#require(nodes.first), in: window).midY
                        }
                        #expect(zip(rows, rows.dropFirst()).allSatisfy { $0 > $1 }, "原标签顺序必须保持")
                        #expect(names == (index == 2 ? tags : ["很长的标签名称需要截断", "anotherLongTag", "three", "four", "five", "six", "seven"]))
                    }
                    try OverlaySurfaceTestSupport.record(window, name: "e-tags-\(index)-\(suggestions)-\(locale)-\(scheme)-\(Int(width))")
                }
                #expect(!support.container.mainContext.hasChanges)
            }
        }
    }

    @Test(arguments: [false, true], ["send", "queue"])
    func directHelpKeepsCallbackBranches(hasExample: Bool, delivery: String) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let probe = HelpActionProbe()
        let window = support.window(SyntaxExpandableCard(isExpanded: Binding(get: { probe.expanded }, set: { probe.expanded = $0 }),
            onSelectToken: { probe.tokens.append($0) }, onSelectExample: hasExample ? { probe.examples.append($0) } : nil),
            size: NSSize(width: 400, height: 320))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let row = try SurfaceConsumerUI.button(containing: L10n.string("syntax.guide.tag", locale: Locale(identifier: "en")), in: window)
        try await clickHelp(row, in: window, delivery: delivery)
        #expect(probe.tokens == (hasExample ? [] : ["#"]))
        #expect(probe.examples == (hasExample ? [L10n.string("syntax.example.tag.snippet", locale: Locale(identifier: "en"))] : []))
        let complex = try SurfaceConsumerUI.button(containing: L10n.string("syntax.guide.example", locale: Locale(identifier: "en")), in: window)
        try await clickHelp(complex, in: window, delivery: delivery)
        let expectedExamples = hasExample ? ["syntax.example.tag.snippet", "syntax.example.complex.snippet"].map {
            L10n.string(String.LocalizationValue($0), locale: Locale(identifier: "en"))
        } : []
        #expect(probe.examples == expectedExamples && probe.tokens == (hasExample ? [] : ["#"]))
        #expect(probe.expanded, "单项和综合示例不能意外走关闭回调")
        try await clickHelp(SettingsButtonTestSupport.button("common.close", in: window), in: window, delivery: delivery)
        #expect(!probe.expanded && !support.container.mainContext.hasChanges)
    }

    private func clickHelp(_ button: NSObject, in window: NSWindow, delivery: String) async throws {
        try SettingsButtonTestSupport.assertBounds([button], in: window)
        let rect = try SettingsButtonTestSupport.frame(button, in: window)
        try await SurfaceEventTestSupport.click(NSPoint(x: rect.midX, y: rect.midY), in: window, delivery: delivery)
    }

    @Test(arguments: [false, true])
    func directHelpExitCommandOwnership(focusHost: Bool) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let probe = HelpActionProbe()
        let window = SystemPageHost.preferenceWindow(
            SyntaxExpandableCard(isExpanded: Binding(get: { probe.expanded }, set: { probe.expanded = $0 }),
                onSelectToken: { probe.tokens.append($0) })
                .environment(\.locale, Locale(identifier: "en")).preferredColorScheme(.light),
            container: support.container, prefs: support.prefs, size: NSSize(width: 400, height: 320))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        // 额外焦点对照只证明卡片能够收到 Exit，不替代生产打开后的输入焦点路径。
        if focusHost { try #require(window.makeFirstResponder(window.contentView)) }
        SurfaceEventTestSupport.note("direct exit focusHost=\(focusHost)")
        SurfaceEventTestSupport.describe(window)
        NSApp.postEvent(try PickerNativeTestSupport.key(code: 53, chars: "\u{1B}", in: window), atStart: false)
        try await SystemPageHost.settle(window)
        SurfaceEventTestSupport.note("direct exit expanded=\(probe.expanded)")
        #expect(!probe.expanded)
        #expect(probe.tokens.isEmpty && probe.examples.isEmpty && !support.container.mainContext.hasChanges)
    }

    @Test func directHelpNativeHoverDoesNotSelect() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let probe = HelpActionProbe()
        let window = support.window(SyntaxExpandableCard(isExpanded: .constant(true),
            onSelectToken: { probe.tokens.append($0) }, onSelectExample: { probe.examples.append($0) }),
            size: NSSize(width: 400, height: 320))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        let title = L10n.string("syntax.guide.tag", locale: Locale(identifier: "en"))
        let row = try SurfaceConsumerUI.button(containing: title, in: window)
        try await SurfaceConsumerUI.hover(row, in: window) {
            #expect(SurfaceConsumerUI.strings(window).contains { $0.contains("#life") })
            #expect(probe.tokens.isEmpty && probe.examples.isEmpty)
            try OverlaySurfaceTestSupport.record(window, name: "e-help-direct-native-hover")
        }
    }
}

@MainActor
enum SurfaceConsumerUI {
    static func strings(_ window: NSWindow) -> [String] {
        SettingsButtonTestSupport.elements(window.contentView).flatMap { node in
            ["accessibilityValue", "accessibilityLabel", "accessibilityTitle"].compactMap {
                SettingsButtonTestSupport.value(node, $0) as? String
            }
        }
    }

    static func button(containing text: String, in window: NSWindow) throws -> NSObject {
        try #require(SettingsButtonTestSupport.buttons(in: window).first { node in
            ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].contains {
                (SettingsButtonTestSupport.value(node, $0) as? String)?.contains(text) == true
            }
        }, "未找到合成场景按钮：\(text)")
    }

    static func hover(_ node: NSObject, in window: NSWindow, inspect: () throws -> Void) async throws {
        let rect = try SettingsButtonTestSupport.frame(node, in: window)
        let point = NSPoint(x: rect.midX, y: rect.midY)
        let original = NSEvent.mouseLocation
        defer { warp(original) }
        warp(window.convertPoint(toScreen: point))
        window.acceptsMouseMovedEvents = true
        let event = try #require(NSEvent.mouseEvent(with: .mouseMoved, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 0, pressure: 0))
        NSApp.sendEvent(event)
        try await SystemPageHost.settle(window)
        // 显式 withAnimation 的离场节点会短暂留在 AX 树；观察完成后的状态，不把过渡帧当成显隐失败。
        try await Task.sleep(for: .milliseconds(450))
        window.contentView?.layoutSubtreeIfNeeded()
        // 必须在恢复测试前指针位置之前取证，否则已经触发离开事件。
        try inspect()
    }

    private static func warp(_ point: NSPoint) {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        #expect(CGWarpMouseCursorPosition(CGPoint(x: point.x, y: top - point.y)) == .success)
    }
}

@Observable @MainActor private final class TagDetailProbe {
    let text: String
    var suggestions = false
    var appearances = 0
    var closes = 0
    init(text: String) { self.text = text }
}

private struct TagDetailSample: View {
    let probe: TagDetailProbe
    var body: some View {
        LiveComposerPreviewHeader(text: probe.text, showsSuggestions: probe.suggestions, onClose: { probe.closes += 1 })
            .onAppear { probe.appearances += 1 }
    }
}

@Observable @MainActor private final class HelpActionProbe {
    var expanded = true
    var tokens: [String] = []
    var examples: [String] = []
}
