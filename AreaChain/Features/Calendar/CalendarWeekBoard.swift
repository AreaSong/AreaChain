import SwiftData
import SwiftUI

/// 日历的一周：七列当天事项。待办可以拖到另一列改期。
struct CalendarWeekBoard: View {
    @Environment(\.locale) private var locale

    var days: [String]
    var selectedKey: String
    var todayKey: String
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var todos: [TodoItem]
    var listFocused: Bool
    var listFocusID: Binding<UUID?>
    var onSelect: (String) -> Void
    var onInspect: (UUID, String) -> Void
    var onReturnToGrid: () -> Void
    var onDropTodo: (UUID, String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(days, id: \.self) { day in
                column(day)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func column(_ day: String) -> some View {
        let selected = day == selectedKey
        return VStack(alignment: .leading, spacing: 6) {
            DaybookDateCell(dayKey: day, isToday: day == todayKey, isSelected: selected,
                            presentation: .weekHeader(shortStamp: DayKey.shortStamp(day, locale: locale))) {
                onSelect(day)
            }
            .accessibilityIdentifier("calendar.week.\(day)")
            ScrollView {
                DayBoardList(
                    dayKey: day,
                    routines: routines,
                    checks: checks,
                    todos: todos,
                    config: DayBoardListConfig(
                        todayKey: todayKey,
                        allowsTodoDrag: true,
                        interaction: DayBoardInteraction(
                            focusedTaskID: listFocused && selected ? listFocusID : nil,
                            highlightedTaskID: listFocused && selected ? listFocusID.wrappedValue : nil,
                            onInspect: { onInspect($0, day) },
                            onReturnToInput: onReturnToGrid
                        )
                    )
                )
            }
            .daybookScroll()
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .daybookSurface(.card, isSelected: selected)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.compactMap(TodoDragToken.decode).first else { return false }
            onDropTodo(id, day)
            return true
        }
    }
}

enum CalendarDayFocus {
    static func firstOpenID(
        dayKey: String,
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem]
    ) -> UUID? {
        let routineSnaps = routines.map(\.snapshot)
        let checkSnaps = checks.compactMap(\.snapshot)
        let todoSnaps = todos.map(\.snapshot)
        let openRoutineIDs = Set(DayBoardLogic.openRoutines(
            routines: routineSnaps, checks: checkSnaps, dayKey: dayKey
        ).map(\.id))
        let openTodoIDs = Set(DayBoardLogic.openTodos(todos: todoSnaps, dayKey: dayKey).map(\.id))
        let rows = routines.filter { openRoutineIDs.contains($0.id) }.map(BoardRow.resident)
            + todos.filter { openTodoIDs.contains($0.id) }.map(BoardRow.todo)
        return rows.sorted {
            Classification.precedes($0.boardSortKey(listDay: dayKey), $1.boardSortKey(listDay: dayKey))
        }.first?.id
    }
}
