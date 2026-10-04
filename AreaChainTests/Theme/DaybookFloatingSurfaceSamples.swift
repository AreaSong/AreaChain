import SwiftUI
@testable import AreaChain

/// 原 ControlsPreview 的合成展示；候选/预览组合仍直接消费生产组件。
struct DaybookFloatingSurfaceSamples: View {
    @State private var suggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Toggle(isOn: $suggestions) { Text(verbatim: "Preview · Suggestions") }
            LiveComposerPreviewHeader(text: "Synthetic 合成 #工作", showsSuggestions: suggestions, onClose: {})
                .frame(width: 316)
            LiveDiaryComposerPreview(text: "Synthetic 合成 #工作 // 合成备注", showsSuggestions: suggestions,
                                     onCopy: { _, _ in true }, onClose: {})
                .frame(width: 316)
            ForEach(OverlaySurfaceTestSupport.cases.filter { $0 != "empty" }, id: \.self) { scenario in
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: scenario).font(DaybookType.caption)
                    OverlaySurfaceTestSupport.popup(scenario, state: OverlaySurfaceTestSupport.state(scenario),
                                                    width: 316, height: 180)
                }
            }
        }
        .padding(24)
    }
}
