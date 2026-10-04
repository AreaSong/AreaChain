import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct OverlaySurfaceConsumerTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func directConsumersWithCompleteEdges(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        for width: CGFloat in [240, 356] {
            for scenario in OverlaySurfaceTestSupport.cases {
                let state = OverlaySurfaceTestSupport.state(scenario)
                let height: CGFloat = width == 240 ? 120 : 260
                let popup = OverlaySurfaceTestSupport.popup(scenario, state: state, width: width, height: height)
                    .background(SyntaxViewAnchor("syntax.surface.content"))
                    .padding(32)
                let window = support.window(popup, locale: locale, scheme: scheme,
                                            size: NSSize(width: width + 64, height: 440))
                defer { SystemPageHost.release(window) }
                try await SystemPageHost.settle(window)
                if scenario == "empty" {
                    #expect(!state.hasPresentation)
                    let views = OverlaySurfaceTestSupport.descendants(window.contentView)
                    #expect(!views.contains { $0 is NSScrollView })
                    let anchor = views.first { $0.identifier?.rawValue == "syntax.surface.content" }
                    #expect(anchor == nil || anchor?.bounds.isEmpty == true)
                    try OverlaySurfaceTestSupport.record(window, name: "direct-empty-\(locale)-\(scheme)-\(Int(width))")
                    continue
                }
                let frame = try NativeSyntaxUI.frame("syntax.surface.content", in: window)
                #expect(frame.width <= width)
                #expect(frame.minX >= 32 && frame.maxX <= width + 32)
                if scenario == "attributes" {
                    #expect(frame.height == height)
                    let close = try NativeSyntaxUI.frame("syntax.attributes.close", in: window)
                    #expect(frame.contains(close))
                }
                if scenario.contains("combined") || scenario == "candidates" {
                    #expect(state.isActive && !state.candidates.isEmpty)
                }
                try OverlaySurfaceTestSupport.record(window, name: "direct-\(scenario)-\(locale)-\(scheme)-\(Int(width))")
            }
        }
    }

    @Test func productionDismissalKeepsDistinctPreviewPaths() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let state = OverlaySurfaceTestSupport.state("task-combined")
        let window = support.window(OverlaySurfaceHostSample(state: state, scenario: "task-combined", above: false),
                                    size: NSSize(width: 400, height: 420))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await SettingsButtonTestSupport.key(53, in: window)
        #expect(!state.isActive && state.showsPreview)
        #expect(NativeSyntaxUI.identifiers(in: window).contains("syntax.overlay.preview"))
        try await SettingsButtonTestSupport.key(53, in: window)
        #expect(!state.showsPreview && !state.isActive)
        state.update(text: "#工", cursorLocation: 2, availableTags: ["工作"])
        try await SystemPageHost.settle(window)
        #expect(state.isActive && state.showsPreview)
        // 外部点击清候选，但不是预览的显式关闭。
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: 3, y: 3), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.postEvent(event, atStart: false)
        }
        try await SystemPageHost.settle(window)
        #expect(!state.isActive && state.showsPreview)
        state.update(text: "#工a", cursorLocation: 3, availableTags: ["工a"])
        try await SystemPageHost.settle(window)
        window.resignKey()
        try await SystemPageHost.settle(window)
        #expect(!state.isActive && state.showsPreview)
        window.contentView = nil
        try await SystemPageHost.settle(window)
        #expect(!state.isActive && !state.showsAttributes && state.showsPreview)
    }

    @Test func candidateMouseCallbackIsSingleAndReadOnly() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let state = OverlaySurfaceTestSupport.state("candidates")
        var commits: [String] = []
        let window = support.window(SyntaxAutocompletePopup(state: state, motionDisabled: true,
            onCommit: { commits.append($0.id) }).padding(32), size: NSSize(width: 420, height: 320))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let first = try #require(state.candidates.first)
        let point = try NativeSyntaxUI.center("syntax.candidate." + first.id, in: window)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.postEvent(event, atStart: false)
        }
        try await SystemPageHost.settle(window)
        #expect(commits == [first.id])
        #expect(state.isActive && !support.container.mainContext.hasChanges)
    }

    @Test(arguments: [false, true])
    func productionOverlayPlacementAndPreviewCombinations(above: Bool) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        for scenario in OverlaySurfaceTestSupport.cases where scenario != "empty" {
            let state = OverlaySurfaceTestSupport.state(scenario)
            let window = support.window(OverlaySurfaceHostSample(state: state, scenario: scenario, above: above),
                                        size: NSSize(width: 400, height: above ? 260 : 420))
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            if scenario == "attributes" {
                state.showAttributes()
            }
            try await SystemPageHost.settle(window)
            let identifier = scenario == "attributes" ? "syntax.overlay.attributes"
                : scenario.contains("preview") ? "syntax.overlay.preview" : "syntax.overlay.candidates"
            let frame = try NativeSyntaxUI.frame(identifier, in: window)
            #expect(try #require(window.contentView).bounds.contains(frame))
            let monitors = OverlaySurfaceTestSupport.descendants(window.contentView)
                .filter { $0.identifier?.rawValue == "syntax.overlay.event-monitor" }
            #expect(monitors.count == 1)
            try OverlaySurfaceTestSupport.record(window, name: "host-\(scenario)-\(above)")
        }
    }
}

/// 原生产定位/事件宿主；这里只提供合成来源锚点，不复制宿主实现。
private struct OverlaySurfaceHostSample: View {
    let state: SyntaxAutocompleteState
    let scenario: String
    let above: Bool

    var body: some View {
        VStack {
            if above { Spacer() }
            if scenario == "attributes" {
                CaptureAttributesButton(text: "#工作 #新标签 !p1 @09:00", knownTags: ["工作"], state: state)
            } else {
                Color.clear.frame(height: 34).syntaxSuggestions(state, prefersAbove: above)
            }
            if !above { Spacer() }
        }
        .padding(24)
        .syntaxOverlayHost()
    }
}
