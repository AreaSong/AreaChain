import SwiftUI

/// 民事日选择；唯一选中值属于调用方，月份浏览和键盘焦点仅在本次挂载中存在。
struct DaybookDatePicker: View {
    @Binding var selection: String
    var todayKey: String? = nil
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.isEnabled) private var isEnabled
    @State private var monthKey: String?
    @State private var isMounted = false
    @FocusState private var gridFocused: Bool

    private var today: String { todayKey ?? DayKey.today(calendar: calendar) }
    private var displayedMonth: String { monthKey ?? validSelection ?? today }
    private var validSelection: String? {
        DayKey.date(from: selection, calendar: calendar).map { DayKey.from($0, calendar: calendar) }
    }

    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            DaybookPeriodBar(title: DayKey.monthTitle(displayedMonth, calendar: calendar, locale: locale),
                             onPrev: { browse(-1) }, onNext: { browse(1) })
            DaybookWeekdayHeader()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DaybookSpacing.xs), count: 7),
                      spacing: DaybookSpacing.xs) {
                ForEach(DaybookMonthGridDay.month(containing: displayedMonth, calendar: calendar)) { cell in
                    if let key = cell.key {
                        DaybookDateCell(dayKey: key, isToday: key == today, isSelected: key == validSelection,
                                        isFocused: gridFocused && key == validSelection) { select(key) }
                    } else {
                        Color.clear.frame(height: DaybookMetrics.DatePicker.cellHeight)
                            .accessibilityHidden(true)
                    }
                }
            }
            .background {
                // 焦点载体与日格为兄弟节点，避免 isFocused 环境把所有按钮都画成聚焦。
                Color.clear
                    .frame(width: 1, height: 1)
                    .focusable(isEnabled, interactions: .edit)
                    .focusEffectDisabled()
                    .focused($gridFocused)
                    .onKeyPress(phases: [.down, .repeat], action: handleKey)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: DaybookMetrics.DatePicker.width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("day.date"))
        .accessibilityIdentifier("daybook.datePicker")
        .onAppear {
            isMounted = true
            monthKey = validSelection ?? today
        }
        .onDisappear { isMounted = false }
        .onChange(of: selection) { _, _ in monthKey = validSelection ?? today }
    }

    private func browse(_ offset: Int) {
        guard isMounted, isEnabled else { return }
        monthKey = DayKey.shiftedMonth(displayedMonth, by: offset, calendar: calendar)
        gridFocused = true
    }

    private func select(_ key: String) {
        guard isMounted, isEnabled, DayKey.date(from: key, calendar: calendar) != nil else { return }
        if key != selection { selection = key }
        // 拒绝写入的 Binding 不能留下乐观选中态；焦点不等同业务选择。
        gridFocused = true
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard isMounted, isEnabled, press.modifiers.isDisjoint(with: [.command, .control, .option]) else {
            return .ignored
        }
        let offset: Int
        switch press.key {
        case .leftArrow: offset = -1
        case .rightArrow: offset = 1
        case .upArrow: offset = -7
        case .downArrow: offset = 7
        case .return: return .handled
        default: return .ignored
        }
        select(DayKey.shifted(validSelection ?? today, by: offset, calendar: calendar))
        return .handled
    }
}
