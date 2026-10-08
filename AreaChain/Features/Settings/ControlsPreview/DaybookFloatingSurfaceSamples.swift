import SwiftUI

/// 原 ControlsPreview 的合成展示；候选/预览组合仍直接消费生产组件。
struct DaybookFloatingSurfaceSamples: View {
    @State private var copies = 0
    @State private var suggestions = false
    @State private var helpExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            MenuBarFilterSurfaceSamples()
            Toggle(isOn: $suggestions) { Text("controls.preview.surface.suggestions") }
            HStack(spacing: 24) {
                Text("controls.preview.surface.tagDetail").padding(12).daybookSurface(floating: .tagDetail)
                Text("controls.preview.surface.syntaxHelp").padding(12).daybookSurface(floating: .syntaxHelp)
            }
            HStack(spacing: 16) {
                ForEach(0..<4) { state in
                    Text("controls.preview.surface.bubble \(state + 1)").padding(8)
                        .daybookSurface(floating: .rowBubble(isHovered: state % 2 == 1, isCopied: state >= 2))
                }
            }
            Text("controls.preview.surface.bubbles").font(DaybookType.caption)
            VStack(alignment: .leading, spacing: DaybookSpacing.lg) {
                RowTitleBubble(title: "Synthetic 合成长标题气泡", growsUpward: false, onCopy: { copies += 1 })
                RowNoteBubble(note: "Synthetic 合成备注", growsUpward: false, bubbleShiftX: 0, onCopy: { copies += 1 })
                RowNoteBubble(note: "Synthetic 合成备注", growsUpward: true, bubbleShiftX: -60, onCopy: { copies += 1 })
            }
            Text("controls.preview.surface.help").font(DaybookType.caption)
            SyntaxExpandableCard(isExpanded: $helpExpanded, onSelectToken: { _ in })
            LiveComposerPreviewHeader(text: "Synthetic long title #长标签名称 #one #two #three #four #five #six",
                                      showsSuggestions: suggestions, onClose: {}, onCopy: { _ in copies += 1 })
                .frame(width: 316)
            LiveComposerPreviewHeader(text: "Synthetic 合成 #工作", showsSuggestions: suggestions, onClose: {}, onCopy: { _ in copies += 1 })
                .frame(width: 316)
            LiveDiaryComposerPreview(text: "Synthetic 合成 #工作 // 合成备注", showsSuggestions: suggestions,
                                     onCopy: { _, _ in copies += 1; return true }, onClose: {})
                .frame(width: 316)
            if copies > 0 {
                Text("controls.preview.copyFeedback").font(DaybookType.caption)
                    .accessibilityIdentifier("preview.copyFeedback")
            }
            ForEach(DaybookOverlaySamples.cases.filter { $0 != "empty" }, id: \.self) { scenario in
                DaybookOverlaySample(scenario: scenario)
            }
        }
        .padding(24)
    }
}

/// ControlsPreview 直接挂生产两级/单级筛选；示例 Binding 只属于预览。
struct MenuBarFilterSurfaceSamples: View {
    @State private var filters = BoardFilters()
    @State private var tags = [TagItem(name: "Synthetic 合成标签", sortOrder: 0)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("controls.preview.surface.filter")
                .padding(12).daybookSurface(floating: .filterFlyout)
            HStack(alignment: .bottom, spacing: 24) {
                MenuBarFilterFlyout(tab: .tasks, filters: $filters, onDismiss: {})
                MenuBarFilterFlyout(tab: .diary, filters: $filters,
                    tags: tags, onDismiss: {})
            }
        }
    }
}
