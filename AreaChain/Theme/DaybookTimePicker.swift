import SwiftUI

/// 分钟 Binding 是唯一业务值；当前时刻只给空值/坏值提供原生编辑起点，不会在挂载时写回。
struct DaybookTimePicker: View {
    let title: String.LocalizationValue
    @Binding var minutes: Int?
    var eventVersion: UInt64?
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.isEnabled) private var isEnabled
    @State private var focused = false

    init(_ title: String.LocalizationValue, minutes: Binding<Int?>, eventVersion: UInt64? = nil) {
        self.title = title
        _minutes = minutes
        self.eventVersion = eventVersion
    }

    private var status: String? {
        if minutes == nil { return L10n.string("time.unset", locale: locale) }
        if RemindMinutes.clamped(minutes) == nil { return L10n.string("time.invalid", locale: locale) }
        return nil
    }

    var body: some View {
        VStack(spacing: DaybookSpacing.xs) {
            DaybookInputShell(kind: .search, focused: focused && isEnabled) {
                DaybookNativeTimePicker(minutes: $minutes, title: L10n.string(title, locale: locale),
                    status: status, locale: locale, calendar: calendar, focused: $focused, eventVersion: eventVersion)
            }
            if let status {
                Text(verbatim: status)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minWidth: DaybookMetrics.TimePicker.minimumWidth)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// 只服务时分显示：保留环境日历标识，用固定 UTC 展示日排除当前日期的 DST 缺口。
/// 这不是提醒日期/排程转换；领域的时区与夏令时规则仍由原 RemindMinutes / DayKey 决定。
struct DaybookTimePresentation {
    let calendar: Calendar
    static let referenceDate = Date(timeIntervalSinceReferenceDate: 43_200)

    init(calendar: Calendar) {
        var display = calendar
        display.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = display
    }

    func date(_ minutes: Int) -> Date? {
        RemindMinutes.date(minutes: minutes, on: Self.referenceDate, calendar: calendar)
    }

    func minutes(_ date: Date) -> Int { RemindMinutes.from(date: date, calendar: calendar) }
}
