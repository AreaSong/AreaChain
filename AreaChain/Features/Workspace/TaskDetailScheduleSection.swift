import SwiftUI

// MARK: - Date Schedule Section

/// 待办排定日期芯片组件
struct TaskDetailDateChips: View {
    var dayKey: String
    var onSelectDate: (String) -> Void
    @Environment(\.locale) private var locale
    @State private var pickingDay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("drawer.date.title")
                    .font(DaybookType.label)
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Text(DayKey.displayName(dayKey, locale: locale))
                    .font(DaybookType.badge.weight(.medium))
                    .foregroundStyle(DaybookTheme.stamp)
            }

            HStack(spacing: 5) {
                let todayKey = DayClock.shared.todayKey
                let tomorrowKey = DayKey.shifted(todayKey, by: 1)
                let afterTomorrowKey = DayKey.shifted(todayKey, by: 2)

                DaybookChip(
                    tint: DaybookTheme.stamp,
                    isSelected: dayKey == todayKey,
                    action: { onSelectDate(todayKey) }
                ) {
                    Text(L10n.string("capture.today", locale: locale))
                }
                DaybookChip(
                    tint: DaybookTheme.stamp,
                    isSelected: dayKey == tomorrowKey,
                    action: { onSelectDate(tomorrowKey) }
                ) {
                    Text(L10n.string("capture.tomorrow", locale: locale))
                }
                DaybookChip(
                    tint: DaybookTheme.stamp,
                    isSelected: dayKey == afterTomorrowKey,
                    action: { onSelectDate(afterTomorrowKey) }
                ) {
                    Text(L10n.string("capture.afterTomorrow", locale: locale))
                }
                DaybookChip(
                    tint: DaybookTheme.stamp,
                    isSelected: dayKey != todayKey && dayKey != tomorrowKey && dayKey != afterTomorrowKey,
                    action: { pickingDay = true }
                ) {
                    Text(L10n.string("day.pick", locale: locale))
                }
            }
            .popover(isPresented: $pickingDay) {
                DaySchedulePicker(initialKey: dayKey) { key in
                    onSelectDate(key)
                    pickingDay = false
                }
            }
        }
    }
}

// MARK: - Remind Time Section

/// 待办与习惯的提醒时间点快捷选择组件
struct TaskDetailRemindChips: View {
    var remindMinutes: Int?
    var onSelectMinutes: (Int?) -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("drawer.remind.title")
                    .font(DaybookType.label)
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                if let remindMinutes {
                    Text(RemindMinutes.label(remindMinutes, locale: locale))
                        .font(.system(size: 10, weight: .bold, design: .monospaced)) // token-exempt: 提醒时刻用等宽
                        .foregroundStyle(DaybookTheme.stamp)
                    DaybookIconButton(systemName: "xmark.circle.fill", label: "row.time.clear", size: .inline) {
                        onSelectMinutes(nil)
                    }
                }
            }

            HStack(spacing: 5) {
                chip(label: "09:00", minutes: 9 * 60)
                chip(label: "12:00", minutes: 12 * 60)
                chip(label: "15:00", minutes: 15 * 60)
                chip(label: "18:00", minutes: 18 * 60)
                chip(label: "20:00", minutes: 20 * 60)
            }
        }
    }

    private func chip(label: String, minutes: Int) -> some View {
        DaybookChip(
            tint: DaybookTheme.stamp,
            isSelected: remindMinutes == minutes,
            action: {
                onSelectMinutes(remindMinutes == minutes ? nil : minutes)
            }
        ) {
            Text(label)
        }
    }
}

// MARK: - Weekday Mask Section

/// 习惯周期星期掩码选择器
struct TaskDetailWeekdayPicker: View {
    var resolvedMask: Int
    var onUpdateMask: (Int) -> Void
    var showsTitle = true
    var accessibilityTitle: LocalizedStringKey = "drawer.weekdays.title"
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsTitle {
                Text("drawer.weekdays.title")
                    .font(DaybookType.label)
                    .foregroundStyle(DaybookTheme.muted)
            }

            HStack(spacing: 4) {
                ForEach(WeekdayMask.orderedWeekdays(calendar: calendar), id: \.self) { weekday in
                    let isSelected = WeekdayMask.contains(resolvedMask, weekday: weekday)
                    Button {
                        onUpdateMask(WeekdayMask.toggling(resolvedMask, weekday: weekday))
                    } label: {
                        Text(WeekdayMask.veryShortSymbol(weekday, locale: locale, calendar: calendar))
                            .font(DaybookType.badge.weight(.medium))
                            .frame(width: 25, height: 25)
                            .background(
                                Circle()
                                    .fill(isSelected ? DaybookTheme.stamp : DaybookTheme.cardSurface)
                            )
                            .foregroundStyle(isSelected ? DaybookPalette.text.onAccent : DaybookTheme.ink)
                    }
                    .buttonStyle(.plain) // control: 星期圆点选择器，不是胶囊
                    .accessibilityLabel(WeekdayMask.accessibilityName(weekday, locale: locale, calendar: calendar))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityTitle)
        }
    }
}

// MARK: - Streak Statistics Card

/// 习惯连击状态标志集合
struct StreakInspectionFlags {
    var isCompleted: Bool
    var isSkipped: Bool
    var isDue: Bool

    init(
        isCompleted: Bool = false,
        isSkipped: Bool = false,
        isDue: Bool = true
    ) {
        self.isCompleted = isCompleted
        self.isSkipped = isSkipped
        self.isDue = isDue
    }
}

/// 习惯连击与历史记录统计卡片配置
struct StreakCardConfig {
    var streakResult: StreakResult
    var isEnabled: Bool
    var inspectDayKey: String
    var flags: StreakInspectionFlags

    init(
        streakResult: StreakResult,
        isEnabled: Bool,
        inspectDayKey: String,
        flags: StreakInspectionFlags
    ) {
        self.streakResult = streakResult
        self.isEnabled = isEnabled
        self.inspectDayKey = inspectDayKey
        self.flags = flags
    }
}

/// 习惯连击与历史记录统计卡片
struct TaskDetailStreakCard: View {
    @Environment(\.locale) private var locale

    var config: StreakCardConfig

    private var streakResult: StreakResult { config.streakResult }
    private var isEnabled: Bool { config.isEnabled }
    private var inspectDayKey: String { config.inspectDayKey }
    private var inspectCompleted: Bool { config.flags.isCompleted }
    private var inspectSkipped: Bool { config.flags.isSkipped }
    private var inspectDue: Bool { config.flags.isDue }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("drawer.streak.title")
                .font(DaybookType.label)
                .foregroundStyle(DaybookTheme.muted)

            VStack(spacing: 8) {
                streakMetricsRow
                Divider().opacity(0.2)
                streakStatusRow
            }
            .padding(10)
            .daybookSurface(.card, configure: { $0.radius = DaybookRadius.small })
        }
    }

    private var streakMetricsRow: some View {
        HStack(spacing: 12) {
            currentStreakColumn
            Divider()
                .frame(height: 28)
                .opacity(0.3)
            bestStreakColumn
        }
    }

    private var currentStreakColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("drawer.streak.current")
                .font(DaybookType.micro)
                .foregroundStyle(DaybookTheme.muted)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(DaybookType.body.weight(.bold))
                    .foregroundStyle(DaybookPalette.status.pending)
                Text("\(streakResult.currentStreak)")
                    .font(.system(size: 16, weight: .bold, design: .rounded)) // token-exempt: 连击数字用圆体
                    .foregroundStyle(DaybookTheme.ink)
                Text("drawer.streak.days")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bestStreakColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("drawer.streak.best")
                .font(DaybookType.micro)
                .foregroundStyle(DaybookTheme.muted)
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(DaybookType.body.weight(.bold))
                    .foregroundStyle(.yellow) // token-exempt: 没有黄色令牌
                Text("\(streakResult.bestStreak)")
                    .font(.system(size: 16, weight: .bold, design: .rounded)) // token-exempt: 连击数字用圆体
                    .foregroundStyle(DaybookTheme.ink)
                Text("drawer.streak.days")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakStatusRow: some View {
        HStack(spacing: 6) {
            statusIcon
            VStack(alignment: .leading, spacing: 1) {
                Text(statusText)
                    .font(DaybookType.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                if inspectDayKey != DayClock.shared.todayKey {
                    Text(DayKey.displayName(inspectDayKey, locale: locale))
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookTheme.muted)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if !isEnabled {
            Image(systemName: "pause.circle.fill")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.muted)
        } else if inspectCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.done)
        } else if inspectSkipped {
            Image(systemName: "forward.circle.fill")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.muted)
        } else if !inspectDue {
            Image(systemName: "calendar.badge.clock")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.muted)
        } else {
            Image(systemName: "circle")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.stamp)
        }
    }

    private var statusText: LocalizedStringKey {
        if !isEnabled {
            return "drawer.streak.status.paused"
        } else if inspectCompleted {
            return "drawer.streak.status.completed"
        } else if inspectSkipped {
            return "drawer.streak.status.skipped"
        } else if !inspectDue {
            return "drawer.streak.status.offday"
        } else {
            return "drawer.streak.status.pending"
        }
    }

    private var statusColor: Color {
        if !isEnabled {
            return DaybookTheme.muted
        } else if inspectCompleted {
            return DaybookTheme.done
        } else if inspectSkipped || !inspectDue {
            return DaybookTheme.muted
        } else {
            return DaybookTheme.stamp
        }
    }
}
