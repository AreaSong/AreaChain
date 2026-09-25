import Foundation

enum DashboardNavigation {
    @MainActor
    static func openToday(_ navigation: WorkspaceNavigation) {
        navigation.revealTab(.today)
    }

    @MainActor
    static func openPending(_ navigation: WorkspaceNavigation) {
        navigation.revealTab(.pending)
    }

    @MainActor
    static func openCalendar(
        dayKey: String,
        isPadding: Bool,
        navigation: WorkspaceNavigation
    ) {
        guard !isPadding else { return }
        navigation.inspectBoard(dayKey)
        navigation.revealTab(.calendar)
    }

    @MainActor
    static func open(_ route: DashboardActivityRoute?, navigation: WorkspaceNavigation) {
        switch route {
        case .inspectItem(let id, let dayKey, _):
            navigation.inspectTask(id, dayKey: dayKey)
        case .diaryPage:
            navigation.revealTab(.diary)
        case .trash:
            navigation.revealTab(.trash)
        case nil:
            break
        }
    }
}
