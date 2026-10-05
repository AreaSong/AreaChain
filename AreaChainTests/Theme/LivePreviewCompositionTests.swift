import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LivePreviewCompositionTests {
    @Test func tagDetailsKeepDraftSelectionAndNativeScroll() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let probe = PreviewInputProbe(diary: false)
        let window = support.window(PreviewInputSample(probe: probe), size: NSSize(width: 400, height: 420))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(OverlaySurfaceTestSupport.descendants(window.contentView)
            .compactMap { $0 as? DaybookAppKitTextField }.first)
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        let draft = "Synthetic title #one #two #three #four #five #six #工"
        editor.insertText(draft, replacementRange: NSRange(location: 0, length: 0))
        try await SystemPageHost.settle(window)
        let selection = editor.selectedRange()
        for _ in 0..<2 {
            #expect(probe.state.isActive)
            #expect(!SurfaceConsumerUI.strings(window).contains("All tags"))
            probe.state.dismissSuggestionsOnly()
            try await SystemPageHost.settle(window)
            #expect(SurfaceConsumerUI.strings(window).contains("All tags"))
            let scroll = try #require(OverlaySurfaceTestSupport.descendants(window.contentView)
                .compactMap { $0 as? NSScrollView }.first { ($0.documentView?.bounds.height ?? 0) > $0.contentView.bounds.height })
            let before = scroll.contentView.bounds.origin
            let point = scroll.convert(NSPoint(x: scroll.bounds.midX, y: scroll.bounds.midY), to: nil)
            let event = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -80, wheel2: 0, wheel3: 0))
            let screen = window.convertPoint(toScreen: point)
            event.location = CGPoint(x: screen.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - screen.y)
            let native = try #require(NSEvent(cgEvent: event))
            scroll.scrollWheel(with: native)
            try await SystemPageHost.settle(window)
            #expect(scroll.contentView.bounds.origin != before, "原生滚轮必须实际移动原标签列表")
            #expect(probe.text == draft && editor.selectedRange() == selection && window.firstResponder === editor)
            #expect(probe.commits == 0 && probe.submissions == 0)
            probe.state.update(text: draft, cursorLocation: selection.location, availableTags: ["工作", "工程"])
            try await SystemPageHost.settle(window)
            #expect(!SurfaceConsumerUI.strings(window).contains("All tags"))
        }
        #expect(!support.container.mainContext.hasChanges)
    }

    @Test(arguments: [false, true], ["return", "mouse"])
    func nativeDraftAndSelectionSurviveCandidateTransitions(diary: Bool, acceptance: String) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let probe = PreviewInputProbe(diary: diary)
        let window = support.window(PreviewInputSample(probe: probe), size: NSSize(width: 400, height: 420))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(OverlaySurfaceTestSupport.descendants(window.contentView)
            .compactMap { $0 as? DaybookAppKitTextField }.first)
        #expect(window.makeFirstResponder(field))
        try await SystemPageHost.settle(window)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Synthetic #工 tail", replacementRange: NSRange(location: 0, length: 0))
        editor.setSelectedRange(NSRange(location: 12, length: 0))
        probe.state.update(text: editor.string, cursorLocation: 12, availableTags: ["工作", "工程"])
        try await SystemPageHost.settle(window)
        let draft = probe.text
        for _ in 0..<2 {
            #expect(probe.state.isActive && probe.state.showsPreview)
            _ = try NativeSyntaxUI.frame("syntax.overlay.candidates", in: window)
            probe.state.dismissSuggestionsOnly()
            try await SystemPageHost.settle(window)
            _ = try NativeSyntaxUI.frame("syntax.overlay.preview", in: window)
            #expect(window.firstResponder === editor && probe.text == draft && probe.state.showsPreview)
            #expect(editor.selectedRange() == NSRange(location: 12, length: 0))
            probe.state.update(text: editor.string, cursorLocation: 12, availableTags: ["工作", "工程"])
            try await SystemPageHost.settle(window)
        }
        let trigger = try #require(probe.state.trigger)
        let candidate = try #require(probe.state.selectedCandidate())
        let expected = (draft as NSString).replacingCharacters(in: trigger.range, with: candidate.insertText)
        try await accept(candidate, via: acceptance, probe: probe, editor: editor, window: window)
        #expect(editor.string == expected && probe.text == expected)
        #expect(editor.selectedRange().location == trigger.range.location + candidate.insertText.utf16.count)
        #expect(window.firstResponder === editor && probe.state.showsPreview && !probe.state.isActive)
        #expect(!support.container.mainContext.hasChanges)
    }

    private func accept(_ candidate: SyntaxCandidate, via acceptance: String, probe: PreviewInputProbe,
                        editor: NSTextView, window: NSWindow) async throws {
        var edits = 0
        let observer = NotificationCenter.default.addObserver(forName: NSText.didChangeNotification,
            object: editor, queue: .main) { _ in MainActor.assumeIsolated { edits += 1 } }
        defer { NotificationCenter.default.removeObserver(observer) }
        if acceptance == "mouse" {
            let point = try NativeSyntaxUI.center("syntax.candidate." + candidate.id, in: window)
            try await SurfaceEventTestSupport.click(point, in: window, delivery: "queue")
        } else {
            try await SettingsButtonTestSupport.key(36, in: window)
        }
        #expect(edits == 1, "两条接受路径均只能产生一次原生文本修改")
        // 原鼠标宿主直接 state.commit；onCommitAutocomplete 仅由字段的 Return/Tab 路径调用。
        #expect(probe.commits == (acceptance == "mouse" ? 0 : 1))
        #expect(probe.submissions == 0)
    }

    @Test func taskCloseOnlyDismissesPreviewWithinProductionPopup() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let state = OverlaySurfaceTestSupport.state("task-combined")
        let window = support.window(SyntaxAutocompletePopup(state: state, motionDisabled: true, onCommit: { _ in })
            .padding(32), size: NSSize(width: 380, height: 300))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let candidates = state.candidates.map(\.id)
        let draft = state.inputText
        // 保留另一属性状态，证明关闭回调只调用 dismissPreview。
        state.showsAttributes = true
        try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("common.close", in: window), in: window)
        #expect(!state.showsPreview && state.isActive && state.showsAttributes)
        #expect(state.candidates.map(\.id) == candidates && state.inputText == draft)
        #expect(!support.container.mainContext.hasChanges)
    }
}

@Observable @MainActor
private final class PreviewInputProbe {
    let state: SyntaxAutocompleteState
    var text = ""
    var focused = true
    var submissions = 0
    var commits = 0

    init(diary: Bool) {
        state = SyntaxAutocompleteState(context: diary ? .diaryCapture : .capture, allowsLivePreview: true)
    }
}

private struct PreviewInputSample: View {
    @Bindable var probe: PreviewInputProbe

    var body: some View {
        VStack {
            DaybookTextField(text: $probe.text, placeholder: "Synthetic", focus: $probe.focused,
                autocomplete: probe.state, availableTags: ["工作", "工程"],
                onSubmit: { probe.submissions += 1 }, onCommitAutocomplete: { _ in probe.commits += 1 })
                .frame(height: 34)
                .syntaxSuggestions(probe.state)
            Spacer()
        }
        .padding(24)
        .syntaxOverlayHost()
    }
}
