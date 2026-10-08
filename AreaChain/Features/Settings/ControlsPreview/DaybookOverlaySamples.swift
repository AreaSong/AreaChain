import SwiftUI

/// 固定合成内容的展示构造器；不接收输入、仓储或执行回调。
@MainActor
enum DaybookOverlaySamples {
    static let cases = ["candidates", "task-combined", "task-preview", "diary-combined", "diary-preview", "empty", "attributes"]

    static func state(_ scenario: String) -> SyntaxAutocompleteState {
        let state = SyntaxAutocompleteState(context: scenario.hasPrefix("diary") ? .diaryCapture : .capture,
                                            allowsLivePreview: scenario.contains("combined") || scenario.contains("preview"))
        let text = scenario == "empty" ? "" : "Synthetic 合成 #工作 #工"
        state.update(text: text, cursorLocation: text.utf16.count,
                     availableTags: ["工作", "工程", "工具", "工时", "工单", "工艺", "工位", "工厂"])
        if scenario.contains("preview") { state.dismissSuggestionsOnly() }
        return state
    }

    static let attributes = CaptureAttributes(
        text: "Synthetic #工作 #新标签 #three #four #five #six !p1 @09:00", knownTags: ["工作"])

    @ViewBuilder
    static func popup(_ scenario: String, state: SyntaxAutocompleteState, width: CGFloat, height: CGFloat,
                      onCopy: ((String, Bool) -> Bool)? = nil) -> some View {
        if scenario == "attributes" {
            CaptureAttributesPopup(attributes: attributes, maxHeight: height, state: state).frame(width: width)
        } else {
            SyntaxAutocompletePopup(state: state, width: width, maxHeight: height, motionDisabled: true, onCommit: { _ in }, onCopyPreview: onCopy)
        }
    }

}

struct DaybookOverlaySample: View {
    let scenario: String
    @State private var state: SyntaxAutocompleteState
    @State private var copies = 0

    init(scenario: String) {
        self.scenario = scenario
        _state = State(initialValue: DaybookOverlaySamples.state(scenario))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey("controls.preview.overlay." + scenario)).font(DaybookType.caption)
            DaybookOverlaySamples.popup(scenario, state: state, width: 316, height: 180,
                onCopy: { _, _ in copies += 1; return true })
            if copies > 0 { Text("controls.preview.copyFeedback").font(DaybookType.caption) }
        }
    }
}
