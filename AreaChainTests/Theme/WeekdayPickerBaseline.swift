import SwiftUI
@testable import AreaChain

/// 阶段 D 移动前的绘制基线，仅供等价性回归；生产只使用 Theme 公共实现。
struct WeekdayPickerBaseline: View {
    var resolvedMask: Int
    var onUpdateMask: (Int) -> Void
    var showsTitle = true
    var allowsEmpty = false
    var accessibilityTitle = "drawer.weekdays.title"
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsTitle {
                Text(verbatim: L10n.string("drawer.weekdays.title", locale: locale))
                    .font(DaybookType.label)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }

            HStack(spacing: 4) {
                ForEach(WeekdayMask.orderedWeekdays(calendar: calendar), id: \.self) { weekday in
                    let isSelected = allowsEmpty
                        ? WeekdayMask.containsSelection(resolvedMask, weekday: weekday)
                        : WeekdayMask.contains(resolvedMask, weekday: weekday)
                    Button {
                        onUpdateMask(WeekdayMask.toggling(resolvedMask, weekday: weekday, allowingEmpty: allowsEmpty))
                    } label: {
                        Text(WeekdayMask.veryShortSymbol(weekday, locale: locale, calendar: calendar))
                            .font(DaybookType.badge.weight(.medium))
                            .frame(width: 25, height: 25)
                            .background(
                                Circle() // token-exempt: 星期圆点，不是胶囊
                                    .fill(isSelected ? DaybookPalette.accent.base : DaybookPalette.cardSurface)
                            )
                            .foregroundStyle(isSelected ? DaybookPalette.text.onAccent : DaybookPalette.text.primary)
                    }
                    .buttonStyle(.plain) // control: 星期圆点选择器，不是胶囊
                    .accessibilityLabel(WeekdayMask.accessibilityName(weekday, locale: locale, calendar: calendar))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(verbatim: L10n.string(
                String.LocalizationValue(stringLiteral: accessibilityTitle),
                locale: locale
            )))
        }
    }
}
