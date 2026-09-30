import SwiftData
import SwiftUI

enum CalendarKeyboardFocus: Equatable {
    case grid
    case list
}

enum CalendarSpan: String, CaseIterable, Identifiable {
    case month
    case week

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .month: "calendar.span.month"
        case .week: "calendar.span.week"
        }
    }
}

enum CalendarDayDrop {
    /// 拖动保存失败时保留原来的选中日。
    static func nextSelectedDay(current: String, target: String, saved: Bool) -> String {
        saved ? target : current
    }
}

struct CalendarPage: View {
    @Environment(\.workspaceEmbedded) private var embedded
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var todayKey: String
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var todos: [TodoItem]

    @Bindable private var selection = BoardSelection.shared
    @Bindable private var navigation = WorkspaceNavigation.shared
    @State private var draft = ""
    @State private var span: CalendarSpan = .month
    @State private var keyboardFocus = CalendarKeyboardFocus.grid
    @State private var listFocusID: UUID?

    init(
        todayKey: String,
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem]
    ) {
        self.todayKey = todayKey
        self.routines = routines
        self.checks = checks
        self.todos = todos
    }

    private var selectedKey: String {
        get { selection.inspectingDayKey }
        nonmutating set { selection.inspectingDayKey = newValue }
    }

    var body: some View {
        GeometryReader { geometry in
            ViewThatFits(in: .horizontal) {
                wideLayout
                compactLayout(compactDates: embedded && geometry.size.height < 560)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .calendarGridKeys(
            enabled: keyboardFocus == .grid,
            selectedKey: selectedKey,
            onSelect: { selectedKey = $0 },
            onEnterList: enterDayList
        )
        .padding(DaybookSpacing.page)
        .frame(minWidth: embedded ? 0 : 420, maxWidth: .infinity, minHeight: embedded ? 0 : 560, maxHeight: .infinity, alignment: .topLeading)
        .background(DaybookPalette.fill.page)
    }

    private var calendarSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 嵌入只决定最小尺寸和月格是否紧凑。宽布局侧栏若只留标题，工作台主路径无法离开当月。
            spanPicker
            monthBar
            CalendarMonthGrid(
                dates: CalendarMonthGridDates(monthKey: selectedKey, todayKey: todayKey, selectedKey: selectedKey),
                counts: monthCounts,
                onSelect: selectDayFromGrid,
                onDropTodo: dropTodo
            )
            Spacer(minLength: 0)
        }
        .frame(width: 320)
    }

    private var calendarDayBoard: some View {
        DayBoardList(
            dayKey: selectedKey,
            routines: routines,
            checks: checks,
            todos: todos,
            config: DayBoardListConfig(
                todayKey: todayKey,
                allowsTodoDrag: true,
                interaction: DayBoardInteraction(
                    focusedTaskID: keyboardFocus == .list ? $listFocusID : nil,
                    highlightedTaskID: keyboardFocus == .list ? listFocusID : navigation.selectedTaskID,
                    onInspect: { id in
                        listFocusID = id
                        keyboardFocus = .list
                        WorkspaceNavigation.shared.inspectTask(id)
                    },
                    onReturnToInput: { keyboardFocus = .grid }
                )
            )
        )
    }

    @ViewBuilder
    private var wideLayout: some View {
        if span == .week {
            weekLayout
        } else {
            monthWideLayout
        }
    }

    private var monthWideLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            calendarSidebar

            DaybookDivider(opacity: 0.5)

            VStack(alignment: .leading, spacing: 10) {
                selectedHeading
                composer
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        calendarDayBoard
                    }
                }
                .daybookScroll()
            }
            .frame(minWidth: 320, maxWidth: .infinity)
        }
        .frame(minWidth: 660)
    }

    private var weekLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            spanPicker
            weekBar
            CalendarWeekBoard(
                days: DayKey.weekKeys(containing: selectedKey, calendar: calendar),
                selectedKey: selectedKey,
                todayKey: todayKey,
                routines: routines,
                checks: checks,
                todos: todos,
                listFocused: keyboardFocus == .list,
                listFocusID: $listFocusID,
                onSelect: selectDayFromGrid,
                onInspect: { id, day in
                    selectedKey = day
                    listFocusID = id
                    keyboardFocus = .list
                    navigation.inspectTask(id, dayKey: day)
                },
                onReturnToGrid: { keyboardFocus = .grid },
                onDropTodo: dropTodo
            )
        }
    }

    private var spanPicker: some View {
        Picker("calendar.span", selection: $span) {
            ForEach(CalendarSpan.allCases) { item in
                Text(item.titleKey).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
        .accessibilityIdentifier("calendar.span")
        .onChange(of: span) { _, _ in
            keyboardFocus = .grid
        }
    }

    private var monthBar: some View {
        DaybookPeriodBar(
            title: DayKey.monthTitle(selectedKey, calendar: calendar, locale: locale),
            onPrev: { selectedKey = DayKey.shiftedMonth(selectedKey, by: -1, calendar: calendar) },
            onNext: { selectedKey = DayKey.shiftedMonth(selectedKey, by: 1, calendar: calendar) },
            onToday: selectedKey == todayKey ? nil : { selectedKey = todayKey }
        )
    }

    private var weekBar: some View {
        let days = DayKey.weekKeys(containing: selectedKey, calendar: calendar)
        let title = weekTitle(days)
        return DaybookPeriodBar(
            title: title,
            onPrev: { selectedKey = DayKey.shifted(selectedKey, by: -7, calendar: calendar) },
            onNext: { selectedKey = DayKey.shifted(selectedKey, by: 7, calendar: calendar) },
            onToday: days.contains(todayKey) ? nil : { selectedKey = todayKey },
            prevLabel: "calendar.week.prev",
            nextLabel: "calendar.week.next"
        )
    }

    private func compactLayout(compactDates: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if span == .week {
                weekLayout
            } else {
                monthCompact(compactDates: compactDates)
            }
        }
    }

    private func monthCompact(compactDates: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            spanPicker
            monthBar
            CalendarMonthGrid(
                dates: CalendarMonthGridDates(monthKey: selectedKey, todayKey: todayKey, selectedKey: selectedKey),
                counts: monthCounts,
                isCompact: compactDates,
                onSelect: selectDayFromGrid,
                onDropTodo: dropTodo
            )
            selectedHeading
            composer
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    calendarDayBoard
                }
            }
            .daybookScroll()
        }
    }

    private var monthCounts: [String: Int] {
        DayBoardLogic.monthUnfinished(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            containing: selectedKey,
            calendar: calendar
        )
    }

    private var selectedHeading: some View {
        Text(DayKey.displayName(selectedKey, calendar: calendar, locale: locale))
            .font(DaybookType.subtitle)
            .foregroundStyle(DaybookPalette.text.secondary)
    }

    private var composer: some View {
        DaybookComposer(text: $draft, placeholder: "calendar.add", onSubmit: addTodo)
    }

    private func addTodo() {
        if DayBoardMutations.addCapturedTodo(text: draft, dayKey: selectedKey, context: modelContext) {
            draft = ""
        }
    }

    private func selectDayFromGrid(_ key: String) {
        selectedKey = key
        keyboardFocus = .grid
    }

    private func enterDayList() {
        guard let id = CalendarDayFocus.firstOpenID(
            dayKey: selectedKey, routines: routines, checks: checks, todos: todos
        ) else { return }
        listFocusID = id
        keyboardFocus = .list
    }

    private func weekTitle(_ days: [String]) -> String {
        guard let first = days.first, let last = days.last, first != last else {
            return DayKey.displayName(selectedKey, calendar: calendar, locale: locale)
        }
        return "\(DayKey.shortStamp(first, locale: locale)) – \(DayKey.shortStamp(last, locale: locale))"
    }

    private func dropTodo(_ id: UUID, onto key: String) {
        guard let todo = todos.first(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let saved = DayBoardMutations.moveTodo(todo, to: key)
        selectedKey = CalendarDayDrop.nextSelectedDay(current: selectedKey, target: key, saved: saved)
    }
}
