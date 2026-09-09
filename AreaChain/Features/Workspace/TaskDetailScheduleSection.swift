import SwiftUI

// MARK: - Date Schedule Section

/// 待办排定日期芯片组件
struct TaskDetailDateChips: View {
    var dayKey: String
    var onSelectDate: (String) -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("drawer.date.title")
                    .font(.system(size: 10, weight: .semibold))
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
                    title: "今天",
                    color: DaybookTheme.stamp,
                    isSelected: dayKey == todayKey,
                    action: { onSelectDate(todayKey) }
                )
                PillBadge(
                    title: "明天",
                    color: DaybookTheme.stamp,
                    isSelected: dayKey == tomorrowKey,
                    action: { onSelectDate(tomorrowKey) }
                )
                PillBadge(
                    title: "后天",
                    color: DaybookTheme.stamp,
                    isSelected: dayKey == afterTomorrowKey,
                    action: { onSelectDate(afterTomorrowKey) }
                )
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
                    .font(.system(size: 10, weight: .semibold))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("drawer.weekdays.title")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)

            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { weekday in
                    let isSelected = (resolvedMask & (1 << (weekday - 1))) != 0
                    Button {
                        let newMask = resolvedMask ^ (1 << (weekday - 1))
                        onUpdateMask(newMask == 0 ? 0b0111110 : newMask)
                    } label: {
                        Text(weekdayShortName(weekday))
                            .font(.system(size: 10.5, weight: .medium))
                            .frame(width: 25, height: 25)
                            .background(
                                Circle()
                                    .fill(isSelected ? DaybookTheme.stamp : DaybookTheme.cardSurface)
                            )
                            .foregroundStyle(isSelected ? Color.white : DaybookTheme.ink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func weekdayShortName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "日"
        case 2: return "一"
        case 3: return "二"
        case 4: return "三"
        case 5: return "四"
        case 6: return "五"
        case 7: return "六"
        default: return ""
        }
    }
}

// MARK: - Streak Statistics Card

/// 习惯连击与历史记录统计卡片
struct TaskDetailStreakCard: View {
    var streakResult: StreakResult
    var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("drawer.streak.title")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // 当前连击
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

                    Divider()
                        .frame(height: 28)
                        .opacity(0.3)

                    // 历史最佳连击
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

                Divider().opacity(0.2)

                // 今日打卡状态
                HStack(spacing: 6) {
                    statusIcon
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(statusColor)
                    Spacer()
                }
            }
            .padding(10)
            .modernCard(cornerRadius: DaybookRadius.small)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if !isEnabled {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
        } else if streakResult.isCompletedToday {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.done)
        } else if streakResult.isSkippedToday {
            Image(systemName: "forward.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
        } else if !streakResult.isDueToday {
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
        } else if streakResult.isCompletedToday {
            return "drawer.streak.status.completed"
        } else if streakResult.isSkippedToday {
            return "drawer.streak.status.skipped"
        } else if !streakResult.isDueToday {
            return "drawer.streak.status.offday"
        } else {
            return "drawer.streak.status.pending"
        }
    }

    private var statusColor: Color {
        if !isEnabled {
            return DaybookTheme.muted
        } else if streakResult.isCompletedToday {
            return DaybookTheme.done
        } else if streakResult.isSkippedToday || !streakResult.isDueToday {
            return DaybookTheme.muted
        } else {
            return DaybookTheme.stamp
        }
    }
}
