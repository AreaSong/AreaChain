import SwiftUI

/// 日期宿主共用日键身份；空白只标识占位，不生成相邻月份日期。
struct DaybookMonthGridDay: Identifiable {
    var id: String
    var key: String?

    static func month(containing monthKey: String, calendar: Calendar) -> [Self] {
        DayKey.monthGrid(containing: monthKey, calendar: calendar).enumerated().map { index, key in
            Self(id: key ?? "padding.\(monthKey).\(index)", key: key)
        }
    }
}

enum DaybookMonthGridDensity {
    case regular
    case compact

    var minimumContentHeight: CGFloat {
        switch self {
        case .regular: DaybookMetrics.MonthGrid.regularContentHeight
        case .compact: DaybookMetrics.MonthGrid.compactContentHeight
        }
    }
}

enum DaybookDateCellPresentation {
    case picker
    case monthGrid(DaybookMonthGridDensity)
    case habit(DaybookHabitDateState)
    /// 保留宿主短日期的格式来源；第二行日号仍使用公共日格的环境日历。
    case weekHeader(shortStamp: String)
}

/// 已由消费者计算的日格状态，只决定配色，不推断习惯计划或历史。
enum DaybookHabitDateState: CaseIterable {
    case checked, skipped, missed, open, outside

    var foreground: Color {
        switch self {
        case .checked, .skipped: DaybookPalette.accent.base
        case .missed, .open: DaybookPalette.text.primary
        case .outside: DaybookPalette.text.tertiary
        }
    }

    var fill: Color {
        switch self {
        case .checked: DaybookPalette.accent.fill
        case .skipped: DaybookPalette.fill.subtle
        case .missed: DaybookPalette.fill.hover
        case .open, .outside: .clear
        }
    }
}

/// 只接收呈现值；annotation 为已计算的文字，nil 在月格中保留原附加行。
/// 不持有选择、焦点或拖放事件，所有动作及业务状态仍由宿主拥有。
struct DaybookDateCell: View {
    var dayKey: String
    var isToday: Bool
    var isSelected: Bool
    var isFocused: Bool = false
    var presentation: DaybookDateCellPresentation = .picker
    var annotation: Text? = nil
    var isDropTarget: Bool = false
    /// 习惯宿主提供已本地化的业务状态，不重复日期；其他呈现仍使用原今天值。
    var statusDescription: String? = nil
    var action: () -> Void
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        control
            .accessibilityLabel(fullDate)
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityIdentifier("daybook.date.\(dayKey)")
    }

    @ViewBuilder private var control: some View {
        switch presentation {
        case .picker:
            Button(action: action) {
                dayNumber
                    .underline(isToday)
                    .frame(maxWidth: .infinity, minHeight: DaybookMetrics.DatePicker.cellHeight)
            }
            .buttonStyle(DaybookButtonStyle(isSelected ? .active : .quiet, size: .inline, isFocused: isFocused))
        case .monthGrid(let density):
            Button(action: action) { monthLabel(density) }
                .buttonStyle(DaybookButtonStyle(.quiet))
                .frame(maxWidth: .infinity, minHeight: density.minimumContentHeight)
                .contentShape(Rectangle())
                .overlay(shape.stroke(isDropTarget ? DaybookPalette.accent.base : Color.clear, lineWidth: 2))
        case .weekHeader(let shortStamp):
            Button(action: action) { weekHeaderLabel(shortStamp) }
                .buttonStyle(DaybookButtonStyle(.quiet))
        case .habit(let state):
            Button(action: action) {
                Text(String(dayKey.suffix(2)))
                    .font(DaybookType.micro)
                    .frame(maxWidth: .infinity, minHeight: DaybookMetrics.HabitMonthGrid.minimumContentHeight)
                    .foregroundStyle(isSelected ? DaybookPalette.text.onAccent : state.foreground)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                            .fill(isSelected ? DaybookPalette.accent.base : state.fill)
                    )
            }
            // 保留原 plain 承载及透明格仅文字命中的行为，不套用日期弹窗的内边距/焦点。
            .buttonStyle(.plain) // control: 公共习惯日期格，保留检查器原命中与焦点语义
        }
    }

    private var accessibilityValue: Text {
        if case .habit = presentation { return Text(verbatim: statusDescription ?? "") }
        return isToday ? Text("calendar.today") : Text("")
    }

    private var dayNumber: some View {
        let bold: Bool = switch presentation {
        case .picker: isSelected || isToday
        case .monthGrid: isSelected
        case .habit: false
        case .weekHeader: false
        }
        return Text(DayKey.dayNumber(dayKey, calendar: calendar))
            .font(DaybookType.body.weight(bold ? .semibold : .regular))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
    }

    private func weekHeaderLabel(_ shortStamp: String) -> some View {
        VStack(alignment: .leading, spacing: DaybookMetrics.WeekHeader.lineSpacing) {
            Text(verbatim: shortStamp)
                .font(DaybookType.caption.weight(.semibold))
            Text(DayKey.dayNumber(dayKey, calendar: calendar))
                .font(DaybookType.title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthLabel(_ density: DaybookMonthGridDensity) -> some View {
        VStack(spacing: DaybookMetrics.MonthGrid.annotationSpacing) {
            dayNumber
            (annotation ?? Text(" "))
                .font(.system(size: DaybookMetrics.MonthGrid.annotationSize, weight: .semibold, design: .rounded))
                .foregroundStyle(annotation == nil ? .clear : DaybookPalette.accent.base)
        }
        .foregroundStyle(isSelected ? DaybookPalette.text.primary : DaybookPalette.text.secondary)
        // 保留 regular 按钮在内容外另加 3/6pt 内边距；长附加文字仍可撑高紧凑格。
        .frame(maxWidth: .infinity, minHeight: density.minimumContentHeight)
        .background(shape.fill(isSelected ? DaybookPalette.accent.base.opacity(0.18) : DaybookPalette.cardSurface))
        .overlay(shape.stroke(monthBorder, lineWidth: isToday ? 1.4 : 0.8))
        .contentShape(shape)
    }

    private var monthBorder: Color {
        if isToday { return DaybookPalette.accent.base }
        return isSelected ? DaybookPalette.accent.base.opacity(0.4) : DaybookPalette.border.default.opacity(0.3)
    }

    private var fullDate: String {
        guard let date = DayKey.date(from: dayKey, calendar: calendar) else { return dayKey }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}
