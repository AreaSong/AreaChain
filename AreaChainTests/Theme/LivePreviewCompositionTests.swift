import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LivePreviewCompositionTests {
    @Test(arguments: [false, true])
    func nativeDraftAndSelectionSurviveCandidateTransitions(diary: Bool) async throws {
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
        try await SettingsButtonTestSupport.key(36, in: window)
        #expect(probe.commits == 1 && probe.submissions == 0)
        #expect(editor.string == expected && probe.text == expected)
        #expect(editor.selectedRange().location == trigger.range.location + candidate.insertText.utf16.count)
        #expect(window.firstResponder === editor && probe.state.showsPreview && !probe.state.isActive)
        #expect(!support.container.mainContext.hasChanges)
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
