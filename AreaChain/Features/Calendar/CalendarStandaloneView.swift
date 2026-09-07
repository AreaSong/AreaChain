import SwiftData
import SwiftUI

struct CalendarStandaloneView: View {
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @State private var dayTick = Date()

    var body: some View {
        let todayKey: String = {
            _ = dayTick
            return dayClock.todayKey
        }()
        CalendarPage(
            todayKey: todayKey,
            routines: routines,
            checks: checks,
            todos: todos
        )
        .padding(16)
        .frame(minWidth: 420, minHeight: 560)
        .background(DaybookTheme.paper.opacity(0.94))
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }
}
