import Foundation

enum DashboardNavigation {
    @MainActor
    static func openToday(_ navigation: WorkspaceNavigation) {
        navigation.revealTab(.today)
    }

    @MainActor
    static func openPending(_ navigation: WorkspaceNavigation, lane: PendingLane) {
        var session = navigation.pendingLaneSession ?? PendingLaneSession(overdueCount: 0)
        session.choose(lane)
        navigation.pendingLaneSession = session
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
            navigation.revealTab(.calendar, inspecting: id, dayKey: dayKey)
        case .openDiary:
            break
        case .focusTrash(let id):
            navigation.focusTrash(id)
        case nil:
            break
        }
    }
}
