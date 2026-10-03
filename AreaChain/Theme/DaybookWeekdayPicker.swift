import SwiftUI

/// 外部 selection 是唯一状态；点击只提出更新，草稿空值与至少一天规则均由 WeekdayMask 解释。
struct DaybookWeekdayPicker: View {
    var selection: Int
    var onUpdateSelection: (Int) -> Void
    var allowsEmpty = false
    var accessibilityTitle: Text
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: DaybookMetrics.WeekdayPicker.spacing) {
            ForEach(WeekdayMask.orderedWeekdays(calendar: calendar), id: \.self) { weekday in
                weekdayButton(weekday)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTitle)
    }

    private func weekdayButton(_ weekday: Int) -> some View {
        let isSelected = allowsEmpty
            ? WeekdayMask.containsSelection(selection, weekday: weekday)
            : WeekdayMask.contains(selection, weekday: weekday)
        return Button {
            guard isEnabled else { return }
            // 最后一天被拒绝取消时也交回原值，保留即时保存消费者的回调次数。
            onUpdateSelection(WeekdayMask.toggling(selection, weekday: weekday, allowingEmpty: allowsEmpty))
        } label: {
            Text(WeekdayMask.veryShortSymbol(weekday, locale: locale, calendar: calendar))
                .font(DaybookType.badge.weight(.medium))
                .frame(width: DaybookMetrics.WeekdayPicker.diameter, height: DaybookMetrics.WeekdayPicker.diameter)
                .background(
                    Circle() // token-exempt: 保留星期圆点的原形状及命中边界，不扩成矩形
                        .fill(isSelected ? DaybookPalette.accent.base : DaybookPalette.cardSurface)
                )
                .foregroundStyle(isSelected ? DaybookPalette.text.onAccent : DaybookPalette.text.primary)
        }
        .buttonStyle(.plain) // control: 星期多选圆点，保留原按下、焦点与辅助操作
        .accessibilityLabel(WeekdayMask.accessibilityName(weekday, locale: locale, calendar: calendar))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
