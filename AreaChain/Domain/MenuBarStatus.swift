import Foundation

enum MenuBarStatus: Equatable {
    case empty
    case remaining(Int)
    case completed

    static func forDay(
        routines: [RoutineSnapshot], checks: [CheckSnapshot], todos: [TodoSnapshot], dayKey: String
    ) -> MenuBarStatus {
        let progress = DayBoardLogic.todayProgress(
            routines: routines, checks: checks, todos: todos, dayKey: dayKey
        )
        if progress.total == 0 { return .empty }
        let remaining = progress.total - progress.completed
        return remaining > 0 ? .remaining(remaining) : .completed
    }

    func accessibilityLabel(locale: Locale) -> String {
        switch self {
        case .empty: L10n.string("menubar.status.empty", locale: locale)
        case .remaining(let count): L10n.string("a11y.app.remaining \(count)", locale: locale)
        case .completed: L10n.string("menubar.status.completed", locale: locale)
        }
    }
}
