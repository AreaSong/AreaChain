import SwiftUI

/// 同一实例的 value 必须唯一且稳定；本地化文字和排列不参与身份。
struct DaybookSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String.LocalizationValue
    let help: String.LocalizationValue?
    var id: Value { value }

    init(_ value: Value, _ title: String.LocalizationValue, help: String.LocalizationValue? = nil) {
        self.value = value
        self.title = title
        self.help = help
    }
}

/// Binding 是唯一选中值。空数组不绘制；缺失值保留全部选项但不显示选中滑块。
struct DaybookSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [DaybookSegmentOption<Value>]
    @Environment(\.locale) private var locale
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var sliderAnimation

    var body: some View {
        if !options.isEmpty {
            HStack(spacing: DaybookMetrics.Segmented.spacing) {
                ForEach(options) { option in segment(option) }
            }
            .padding(DaybookMetrics.Segmented.inset)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                    .fill(DaybookPalette.text.primary.opacity(0.06)) // token-exempt: 保留菜单栏 6% 墨色基线
            )
            .animation(DaybookMotion.segmented(reduceMotion), value: selection)
            .transaction { transaction in
                // 宿主也可能带动画更新 Binding；减弱模式不能继承滑动或弹性事务。
                if reduceMotion {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
        }
    }

    private func segment(_ option: DaybookSegmentOption<Value>) -> some View {
        let isSelected = selection == option.value
        let title = L10n.string(option.title, locale: locale)
        return Button {
            guard isEnabled else { return }
            // 保留菜单栏基线：重选也写入一次，没有完成回调或延迟业务派发。
            selection = option.value
        } label: {
            Text(verbatim: title)
                .font(DaybookType.body.weight(isSelected ? .semibold : .medium))
                .lineLimit(1)
                .frame(minWidth: DaybookMetrics.Segmented.minimumLabelWidth)
                .padding(.horizontal, DaybookMetrics.Segmented.horizontalPadding)
                .padding(.vertical, DaybookMetrics.Segmented.verticalPadding)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                            .fill(DaybookPalette.fill.page)
                            .daybookElevation(.raised)
                            .matchedGeometryEffect(id: "selection", in: sliderAnimation)
                    }
                }
                .foregroundStyle(isSelected ? DaybookPalette.text.primary : DaybookPalette.text.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 分段选择保留原生 Button 操作与焦点语义
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .help(Text(verbatim: option.help.map { L10n.string($0, locale: locale) } ?? title))
    }
}
