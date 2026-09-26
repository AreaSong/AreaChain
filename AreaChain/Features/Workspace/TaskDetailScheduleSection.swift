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
                    .foregroundStyle(DaybookPalette.text.secondary)
                Spacer()
                Text(DayKey.displayName(dayKey, locale: locale))
                    .font(DaybookType.badge.weight(.medium))
                    .foregroundStyle(DaybookPalette.accent.base)
            }

            HStack(spacing: 5) {
                let todayKey = DayClock.shared.todayKey
                let tomorrowKey = DayKey.shifted(todayKey, by: 1)
                let afterTomorrowKey = DayKey.shifted(todayKey, by: 2)

                DaybookChip(
                    tint: DaybookPalette.accent.base,
                    isSelected: dayKey == todayKey,
                    action: { onSelectDate(todayKey) }
                ) {
                    Text(L10n.string("capture.today", locale: locale))
                }
                DaybookChip(
                    tint: DaybookPalette.accent.base,
                    isSelected: dayKey == tomorrowKey,
                    action: { onSelectDate(tomorrowKey) }
                ) {
                    Text(L10n.string("capture.tomorrow", locale: locale))
                }
                DaybookChip(
                    tint: DaybookPalette.accent.base,
                    isSelected: dayKey == afterTomorrowKey,
                    action: { onSelectDate(afterTomorrowKey) }
                ) {
                    Text(L10n.string("capture.afterTomorrow", locale: locale))
                }
                DaybookChip(
                    tint: DaybookPalette.accent.base,
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
                    .foregroundStyle(DaybookPalette.text.secondary)
                Spacer()
                if let remindMinutes {
                    Text(RemindMinutes.label(remindMinutes, locale: locale))
                        .font(.system(size: 10, weight: .bold, design: .monospaced)) // token-exempt: 提醒时刻用等宽
                        .foregroundStyle(DaybookPalette.accent.base)
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
            tint: DaybookPalette.accent.base,
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
    var allowsEmpty = false
    var accessibilityTitle: LocalizedStringKey = "drawer.weekdays.title"
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsTitle {
                Text("drawer.weekdays.title")
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
            .accessibilityLabel(accessibilityTitle)
        }
    }
}

// MARK: - Streak Statistics Card

/// 检查日连击卡的展示状态。跳过优先于完成，避免 `isRoutineDone` 把跳过日画成已完成。
enum StreakInspectStatus: Equatable {
    case paused, skipped, completed, offday, pending
}

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

    func status(isEnabled: Bool) -> StreakInspectStatus {
        if !isEnabled { return .paused }
        if isSkipped { return .skipped }
        if isCompleted { return .completed }
        if !isDue { return .offday }
        return .pending
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
    private var inspectStatus: StreakInspectStatus { config.flags.status(isEnabled: isEnabled) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("drawer.streak.title")
                .font(DaybookType.label)
                .foregroundStyle(DaybookPalette.text.secondary)

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
                .foregroundStyle(DaybookPalette.text.secondary)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(DaybookType.body.weight(.bold))
                    .foregroundStyle(DaybookPalette.status.pending)
                Text("\(streakResult.currentStreak)")
                    .font(.system(size: 16, weight: .bold, design: .rounded)) // token-exempt: 连击数字用圆体
                    .foregroundStyle(DaybookPalette.text.primary)
                Text("drawer.streak.days")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bestStreakColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("drawer.streak.best")
                .font(DaybookType.micro)
                .foregroundStyle(DaybookPalette.text.secondary)
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(DaybookType.body.weight(.bold))
                    .foregroundStyle(DaybookPalette.status.pending)
                Text("\(streakResult.bestStreak)")
                    .font(.system(size: 16, weight: .bold, design: .rounded)) // token-exempt: 连击数字用圆体
                    .foregroundStyle(DaybookPalette.text.primary)
                Text("drawer.streak.days")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.secondary)
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
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch inspectStatus {
        case .paused:
            Image(systemName: "pause.circle.fill")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.done)
        case .skipped:
            Image(systemName: "forward.circle.fill")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
        case .offday:
            Image(systemName: "calendar.badge.clock")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
        case .pending:
            Image(systemName: "circle")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.accent.base)
        }
    }

    private var statusText: LocalizedStringKey {
        switch inspectStatus {
        case .paused: "drawer.streak.status.paused"
        case .skipped: "drawer.streak.status.skipped"
        case .completed: "drawer.streak.status.completed"
        case .offday: "drawer.streak.status.offday"
        case .pending: "drawer.streak.status.pending"
        }
    }

    private var statusColor: Color {
        switch inspectStatus {
        case .completed: DaybookPalette.text.done
        case .pending: DaybookPalette.accent.base
        case .paused, .skipped, .offday: DaybookPalette.text.secondary
        }
    }
}
