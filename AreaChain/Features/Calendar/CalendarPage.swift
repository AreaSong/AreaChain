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

    @State private var selectedKey: String
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
        _selectedKey = State(initialValue: todayKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            monthChrome
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
                        allowsTodoDrag: true
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

    private var monthChrome: some View {
        HStack(spacing: 8) {
            Button {
                selectedKey = DayKey.shiftedMonth(selectedKey, by: -1, calendar: calendar)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(DaybookTheme.muted)
            .accessibilityLabel("calendar.prev")

            Text(DayKey.monthTitle(selectedKey, calendar: calendar, locale: locale))
                .font(.system(size: 16, weight: .regular, design: .serif).italic())
                .foregroundStyle(DaybookTheme.ink)
                .frame(maxWidth: .infinity)

            Button {
                selectedKey = DayKey.shiftedMonth(selectedKey, by: 1, calendar: calendar)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(DaybookTheme.muted)
            .accessibilityLabel("calendar.next")

            if selectedKey != todayKey {
                Button("calendar.today") { selectedKey = todayKey }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
    }

    private var selectedHeading: some View {
        Text(DayKey.displayName(selectedKey, calendar: calendar, locale: locale))
            .font(.system(size: 12))
            .foregroundStyle(DaybookTheme.muted)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("calendar.add", text: $draft)
                .textFieldStyle(.plain)
                .onSubmit(addTodo)
                .daybookHideInputChrome()
            ComposerAddButton(enabled: canSubmit, action: addTodo)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(DaybookTheme.rule, lineWidth: 1)
        )
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
