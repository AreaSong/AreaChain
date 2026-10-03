import SwiftUI

/// 日期选择器和月网格共用顺序、短标题及完整星期辅助名称。
struct DaybookWeekdayHeader: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: DaybookSpacing.xs) {
            ForEach(WeekdayMask.orderedWeekdays(calendar: calendar), id: \.self) { weekday in
                Text(WeekdayMask.veryShortSymbol(weekday, locale: locale, calendar: calendar))
                    .font(DaybookType.label)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(WeekdayMask.accessibilityName(weekday, locale: locale, calendar: calendar))
                    .accessibilityIdentifier("daybook.date.weekday.\(weekday)")
            }
        }
    }
}
