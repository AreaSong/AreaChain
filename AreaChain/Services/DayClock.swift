import Foundation
import Observation

@Observable
final class DayClock {
    static let shared = DayClock()

    var now: Date

    var todayKey: String { DayKey.today(now) }
    var yesterdayKey: String { DayKey.yesterday(from: now) }

    init(now: Date = .now) {
        self.now = now
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.now = Date()
        }
    }

    func refresh() {
        now = Date()
    }
}
