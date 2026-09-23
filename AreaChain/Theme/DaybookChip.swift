import SwiftUI

/// 全应用唯一的胶囊芯片。选中：tint 14% 底 + 35% 描边；未选中：空底 + 细边；悬停：淡灰底。
/// 标签里不要再画 Capsule。颜色用 tint，不要在外面再铺一层底。
struct DaybookChip<Label: View>: View {
    var tint: Color
    var isSelected: Bool
    var action: (() -> Void)?
    @ViewBuilder var label: () -> Label

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        tint: Color = DaybookPalette.accent.base,
        isSelected: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
        self.label = label
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { chip }
                    .buttonStyle(.plain) // control: 芯片外壳，外观由 DaybookChip 绘制
            } else {
                chip
            }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var chip: some View {
        label()
            .font(DaybookType.badge)
            .foregroundStyle(isSelected ? tint : DaybookPalette.text.secondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(stroke, lineWidth: 0.8))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
    }

    private var fill: Color {
        if isSelected { return tint.opacity(0.14) }
        if hovering { return DaybookPalette.fill.hover }
        return .clear
    }

    private var stroke: Color {
        if isSelected { return tint.opacity(0.35) }
        if hovering { return DaybookPalette.border.default.opacity(0.8) }
        return DaybookPalette.border.default.opacity(0.4)
    }
}
