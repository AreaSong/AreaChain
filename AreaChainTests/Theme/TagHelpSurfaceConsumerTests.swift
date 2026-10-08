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
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String
                == MenuButtonTestSupport.localized("controls.preview.surface.help", "en")
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
        // 生产 SyntaxOverlay 固定面板顶部；居中宿主会在标签退出时把标题移出静止指针。
        let window = support.window(TagDetailSample(probe: probe).frame(width: 316)
            .frame(height: 256, alignment: .top).padding(32), size: NSSize(width: 380, height: 320))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for cycle in 1...2 {
            try await titleHoverCycle(title, in: window, name: "o-direct-\(cycle)")
            #expect(probe.closes == 0 && probe.appearances == 1 && !support.container.mainContext.hasChanges)
        }
        SystemPageHost.release(window)
        try await productionTitleHover(support, title: title)
    }

    private func titleNode(_ title: String, in window: NSWindow) throws -> NSObject {
        try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String == title
        })
    }

    private func productionTitleHover(_ support: SettingsButtonTestSupport, title: String) async throws {
        let composer = BoardComposerSession()
        let ui = MenuBarHelpSurfaceTests()
        let window = ui.helpWindow(support, composer: composer, toolbar: MenuBarToolbarState())
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(ui.captureField(window))
        let editor = try #require(field.currentEditor() as? NSTextView)
        let text = title + " #one #two #three #four #five #six "
        editor.insertText(text, replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await SystemPageHost.settle(window)
        let state = try #require((field.delegate as? DaybookTextField.Coordinator)?.parent.autocomplete)
        #expect(state.showsPreview && !state.isActive && composer.tasks.text == text)
        let anchor = try NativeSyntaxUI.frame("syntax.overlay.preview", in: window)
        SurfaceEventTestSupport.note("production anchor=\(anchor)")
        for cycle in 1...2 {
            try await titleHoverCycle(title, in: window, name: "o-production-\(cycle)")
            let current = try NativeSyntaxUI.frame("syntax.overlay.preview", in: window)
            #expect(abs(current.minY - anchor.minY) < 1 && abs(current.height - anchor.height) < 1)
            #expect(state.showsPreview && !state.isActive && composer.tasks.text == text)
            #expect(editor.string == text && !support.container.mainContext.hasChanges)
        }
    }

    private func titleHoverCycle(_ title: String, in window: NSWindow, name: String) async throws {
        let original = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(original) }
        #expect(SurfaceConsumerUI.strings(window).contains("All tags"))
        let node = try titleNode(title, in: window)
        let rect = try SettingsButtonTestSupport.frame(node, in: window)
        let point = NSPoint(x: rect.midX, y: rect.midY)
        try OverlaySurfaceTestSupport.record(window, name: name + "-before")
        try await RowBubbleTestSupport.move(point, in: window)
        // 固定取样窗同时检查命中和几何；不轮询到通过，也不重设生产悬停状态。
        for delay in [20, 60, 100, 270] {
            try await Task.sleep(for: .milliseconds(delay))
            let actual = window.convertPoint(fromScreen: NSEvent.mouseLocation)
            try #require(hypot(actual.x - point.x, actual.y - point.y) < 2, "指针相对宿主发生外部移动")
            let current = try SettingsButtonTestSupport.frame(node, in: window)
            #expect(current.contains(actual) && abs(current.minY - rect.minY) < 1)
            SurfaceEventTestSupport.note("\(name) pointer=\(actual) title=\(current) container=\(window.contentView?.bounds ?? .zero)")
        }
        #expect(!SurfaceConsumerUI.strings(window).contains("All tags"))
        #expect(SurfaceConsumerUI.strings(window).filter { $0 == title }.count == 2, "原标题及完整气泡正文必须同时可见")
        try OverlaySurfaceTestSupport.record(window, name: name + "-hover")
        // 仅移动；不能触发默认系统复制。
        try await RowBubbleTestSupport.move(NSPoint(x: 8, y: 8), in: window)
        try await Task.sleep(for: .milliseconds(450))
        let strings = SurfaceConsumerUI.strings(window)
        #expect(strings.contains("All tags") && strings.filter { $0 == title }.count == 1)
        for tag in ["one", "two", "three", "four", "five", "six"] { #expect(strings.contains("#" + tag)) }
        #expect(abs(try SettingsButtonTestSupport.frame(titleNode(title, in: window), in: window).minY - rect.minY) < 1)
        try OverlaySurfaceTestSupport.record(window, name: name + "-exit")
    }

    private func traceResponders(_ window: NSWindow, label: String) {
        var responder = window.firstResponder
        var chain: [String] = []
        while let current = responder, chain.count < 12 {
            chain.append(String(describing: type(of: current)).components(separatedBy: "<")[0])
            responder = current.nextResponder
        }
        SurfaceEventTestSupport.note("exit \(label) chain=\(chain) rootFirst=\(window.firstResponder === window.contentView)")
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
            SyntaxExpandableCard(isExpanded: Binding(get: { probe.expanded }, set: { probe.expanded = $0; probe.changes += 1 }),
                onSelectToken: { probe.tokens.append($0) })
                .environment(\.locale, Locale(identifier: "en")).preferredColorScheme(.light),
            container: support.container, prefs: support.prefs, size: NSSize(width: 400, height: 320))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        // 裸 Window 或 contentView 的第一响应者身份不代表卡内 SwiftUI 命令焦点。
        if focusHost { try #require(window.makeFirstResponder(window.contentView)) }
        #expect(window.firstResponder === (focusHost ? window.contentView : window))
        let button = try SettingsButtonTestSupport.button("common.close", in: window)
        try #require(button.responds(to: NSSelectorFromString("setAccessibilityFocused:")))
        button.setValue(true, forKey: "accessibilityFocused")
        try #require(button.value(forKey: "accessibilityFocused") as? Bool == true)
        try #require(window.firstResponder !== window && window.firstResponder !== window.contentView)
        #expect(probe.expanded && probe.changes == 0, "只建立卡内焦点，不能激活关闭按钮")
        traceResponders(window, label: "focused descendant before Escape")
        let trace = ExitDeliveryTrace(window: window)
        defer { trace.stop() }
        NSApp.postEvent(try PickerNativeTestSupport.key(code: 53, chars: "\u{1B}", in: window), atStart: false)
        try await SystemPageHost.settle(window)
        #expect(trace.keys == [53])
        #expect(!probe.expanded && probe.changes == 1, "一次 Escape 必须到达卡片原 onExitCommand")
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
    var changes = 0
    var tokens: [String] = []
    var examples: [String] = []
}

@MainActor private final class ExitDeliveryTrace {
    private var monitor: Any?
    var keys: [UInt16] = []
    init(window: NSWindow) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                if event.window === window {
                    self?.keys.append(event.keyCode)
                    SurfaceEventTestSupport.note("exit received key=\(event.keyCode) responder=\(String(describing: window.firstResponder))")
                }
            }
            return event
        }
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
