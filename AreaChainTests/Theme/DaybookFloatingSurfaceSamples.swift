import SwiftUI
@testable import AreaChain

/// 原 ControlsPreview 的合成展示；候选/预览组合仍直接消费生产组件。
struct DaybookFloatingSurfaceSamples: View {
    @State private var suggestions = false
    @State private var helpExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            MenuBarFilterSurfaceSamples()
            Toggle(isOn: $suggestions) { Text(verbatim: "Preview · Suggestions") }
            HStack(spacing: 24) {
                Text(verbatim: "tagDetail · 60% / 0.8pt").padding(12).daybookSurface(floating: .tagDetail)
                Text(verbatim: "syntaxHelp · full shadow").padding(12).daybookSurface(floating: .syntaxHelp)
            }
            HStack(spacing: 16) {
                ForEach(0..<4) { state in
                    Text(verbatim: "Bubble \(state)").padding(8)
                        .daybookSurface(floating: .rowBubble(isHovered: state % 2 == 1, isCopied: state >= 2))
                }
            }
            Text(verbatim: "Production bubbles · card-only shadow · external arrows").font(DaybookType.caption)
            HStack(alignment: .top, spacing: 24) {
                RowTitleBubble(title: "Synthetic 合成长标题气泡", growsUpward: false, onCopy: {})
                RowNoteBubble(note: "Synthetic 合成备注", growsUpward: false, bubbleShiftX: 0, onCopy: {})
                RowNoteBubble(note: "Synthetic 合成备注", growsUpward: true, bubbleShiftX: -60, onCopy: {})
            }
            Text(verbatim: "Production help · original clipShape").font(DaybookType.caption)
            SyntaxExpandableCard(isExpanded: $helpExpanded, onSelectToken: { _ in })
            LiveComposerPreviewHeader(text: "Synthetic long title #长标签名称 #one #two #three #four #five #six",
                                      showsSuggestions: suggestions, onClose: {})
                .frame(width: 316)
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

/// ControlsPreview 直接挂生产两级/单级筛选；示例 Binding 只属于预览。
struct MenuBarFilterSurfaceSamples: View {
    @State private var filters = BoardFilters()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: "filterFlyout · 65% / 0.8pt inset · background shadow")
                .padding(12).daybookSurface(floating: .filterFlyout)
            HStack(alignment: .bottom, spacing: 24) {
                MenuBarFilterFlyout(tab: .tasks, filters: $filters, onDismiss: {})
                MenuBarFilterFlyout(tab: .diary, filters: $filters,
                    tags: [TagItem(name: "Synthetic 合成标签", sortOrder: 0)], onDismiss: {})
            }
        }
    }
}
