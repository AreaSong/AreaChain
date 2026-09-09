import SwiftData
import SwiftUI

struct CalendarPage: View {
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
        ViewThatFits(in: .horizontal) {
            wideLayout
            compactLayout
        }
        .padding(DaybookSpacing.page)
        .frame(minWidth: 420, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity, alignment: .topLeading)
        .background(DaybookTheme.paper.opacity(0.94))
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                DaybookPeriodBar(
                    title: DayKey.monthTitle(selectedKey, calendar: calendar, locale: locale),
                    onPrev: { selectedKey = DayKey.shiftedMonth(selectedKey, by: -1, calendar: calendar) },
                    onNext: { selectedKey = DayKey.shiftedMonth(selectedKey, by: 1, calendar: calendar) },
                    onToday: selectedKey == todayKey ? nil : { selectedKey = todayKey }
                )
                CalendarMonthGrid(
                    monthKey: selectedKey,
                    todayKey: todayKey,
                    selectedKey: selectedKey,
                    counts: monthCounts,
                    onSelect: { selectedKey = $0 },
                    onDropTodo: dropTodo
                )
                Spacer(minLength: 0)
            }
            .frame(width: 320)

            Divider()
                .overlay(DaybookTheme.rule.opacity(0.5))

            VStack(alignment: .leading, spacing: 10) {
                selectedHeading
                composer
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        DayBoardList(
                            dayKey: selectedKey,
                            todayKey: todayKey,
                            routines: routines,
                            checks: checks,
                            todos: todos,
                            allowsTodoDrag: true,
                            highlightedTaskID: navigation.selectedTaskID,
                            onInspect: { WorkspaceNavigation.shared.inspectTask($0) }
                        )
                    }
                }
                .daybookScroll()
            }
            .frame(minWidth: 320, maxWidth: .infinity)
        }
        .frame(minWidth: 660)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            DaybookPeriodBar(
                title: DayKey.monthTitle(selectedKey, calendar: calendar, locale: locale),
                onPrev: { selectedKey = DayKey.shiftedMonth(selectedKey, by: -1, calendar: calendar) },
                onNext: { selectedKey = DayKey.shiftedMonth(selectedKey, by: 1, calendar: calendar) },
                onToday: selectedKey == todayKey ? nil : { selectedKey = todayKey }
            )
            CalendarMonthGrid(
                monthKey: selectedKey,
                todayKey: todayKey,
                selectedKey: selectedKey,
                counts: monthCounts,
                onSelect: { selectedKey = $0 },
                onDropTodo: dropTodo
            )
            selectedHeading
            composer
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    DayBoardList(
                        dayKey: selectedKey,
                        todayKey: todayKey,
                        routines: routines,
                        checks: checks,
                        todos: todos,
                        allowsTodoDrag: true,
                        highlightedTaskID: navigation.selectedTaskID,
                        onInspect: { WorkspaceNavigation.shared.inspectTask($0) }
                    )
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
            .foregroundStyle(DaybookTheme.muted)
    }

    private var composer: some View {
        DaybookComposer(text: $draft, placeholder: "calendar.add", onSubmit: addTodo)
    }

    private func addTodo() {
        if DayBoardMutations.addTodo(title: draft, dayKey: selectedKey, context: modelContext) {
            draft = ""
        }
    }

    private func dropTodo(_ id: UUID, onto key: String) {
        guard let todo = todos.first(where: { $0.id == id }) else { return }
        DayBoardMutations.moveTodo(todo, to: key)
        selectedKey = key
    }
}
