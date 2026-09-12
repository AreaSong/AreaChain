import Foundation

enum MenuBarStatus: Equatable {
    case empty
    case remaining(Int)
    case completed

    static func forDay(
        routines: [RoutineSnapshot], checks: [CheckSnapshot], todos: [TodoSnapshot], dayKey: String
    ) -> MenuBarStatus {
        let remaining = DayBoardLogic.todayBadgeCount(routines: routines, checks: checks, todos: todos, dayKey: dayKey)
        if remaining > 0 { return .remaining(remaining) }
        let hasItems = !DayBoardLogic.todos(for: dayKey, in: todos).isEmpty
            || !DayBoardLogic.routines(for: dayKey, in: routines).isEmpty
        return hasItems ? .completed : .empty
    }

    func accessibilityLabel(locale: Locale) -> String {
        switch self {
        case .empty: L10n.string("menubar.status.empty", locale: locale)
        case .remaining(let count): L10n.string("a11y.app.remaining \(count)", locale: locale)
        case .completed: L10n.string("menubar.status.completed", locale: locale)
        }
    }
}
