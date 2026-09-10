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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DaybookTheme.stamp)
            }

            HStack(spacing: 5) {
                let todayKey = DayClock.shared.todayKey
                let tomorrowKey = DayKey.shifted(todayKey, by: 1)
                let afterTomorrowKey = DayKey.shifted(todayKey, by: 2)

                PillBadge(
                    title: L10n.string("capture.today", locale: locale),
                    color: DaybookTheme.stamp,
                    isSelected: dayKey == todayKey,
                    action: { onSelectDate(todayKey) }
                )
                PillBadge(
                    title: L10n.string("capture.tomorrow", locale: locale),
                    color: DaybookTheme.stamp,
                    isSelected: dayKey == tomorrowKey,
                    action: { onSelectDate(tomorrowKey) }
                )
                PillBadge(
                    title: L10n.string("capture.afterTomorrow", locale: locale),
                    color: DaybookTheme.stamp,
                    isSelected: dayKey == afterTomorrowKey,
                    action: { onSelectDate(afterTomorrowKey) }
                )
                PillBadge(
                    title: L10n.string("day.pick", locale: locale),
                    color: DaybookTheme.stamp,
                    isSelected: dayKey != todayKey && dayKey != tomorrowKey && dayKey != afterTomorrowKey,
                    action: { pickingDay = true }
                )
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
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DaybookTheme.stamp)
                    Button {
                        onSelectMinutes(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DaybookTheme.muted)
                    }
                    .buttonStyle(.plain)
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
        PillBadge(
            title: label,
            color: DaybookTheme.stamp,
            isSelected: remindMinutes == minutes,
            action: {
                onSelectMinutes(remindMinutes == minutes ? nil : minutes)
            }
        )
    }
}

// MARK: - Weekday Mask Section

/// 习惯周期星期掩码选择器
struct TaskDetailWeekdayPicker: View {
    var resolvedMask: Int
    var onUpdateMask: (Int) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("drawer.weekdays.title")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)

            HStack(spacing: 4) {
                ForEach(WeekdayMask.orderedWeekdays(calendar: calendar), id: \.self) { weekday in
                    let isSelected = WeekdayMask.contains(resolvedMask, weekday: weekday)
                    Button {
                        onUpdateMask(WeekdayMask.toggling(resolvedMask, weekday: weekday))
                    } label: {
                        Text(WeekdayMask.veryShortSymbol(weekday, locale: locale, calendar: calendar))
                            .font(.system(size: 10.5, weight: .medium))
                            .frame(width: 25, height: 25)
                            .background(
                                Circle()
                                    .fill(isSelected ? DaybookTheme.stamp : DaybookTheme.cardSurface)
                            )
                            .foregroundStyle(isSelected ? Color.white : DaybookTheme.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(WeekdayMask.accessibilityName(weekday, locale: locale, calendar: calendar))
                }
            }
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)

            VStack(spacing: 8) {
                streakMetricsRow
                Divider().opacity(0.2)
                streakStatusRow
            }
            .padding(10)
            .modernCard(cornerRadius: DaybookRadius.small)
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
                .font(.system(size: 9))
                .foregroundStyle(DaybookTheme.muted)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)
                Text("\(streakResult.currentStreak)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(DaybookTheme.ink)
                Text("drawer.streak.days")
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bestStreakColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("drawer.streak.best")
                .font(.system(size: 9))
                .foregroundStyle(DaybookTheme.muted)
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.yellow)
                Text("\(streakResult.bestStreak)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(DaybookTheme.ink)
                Text("drawer.streak.days")
                    .font(.system(size: 10))
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor)
                if inspectDayKey != DayClock.shared.todayKey {
                    Text(DayKey.displayName(inspectDayKey, locale: locale))
                        .font(.system(size: 9))
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
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
        } else if inspectCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.done)
        } else if inspectSkipped {
            Image(systemName: "forward.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
        } else if !inspectDue {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 11))
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
