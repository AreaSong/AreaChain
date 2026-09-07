import Foundation
import Observation

@Observable
@MainActor
final class CalendarSyncStatus {
    static let shared = CalendarSyncStatus()

    var phase: CalendarSyncPhase = .off
    var lastSyncedAt: Date?

    func mark(_ phase: CalendarSyncPhase) {
        self.phase = phase
        if phase == .synced {
            lastSyncedAt = .now
        }
        if phase == .off {
            lastSyncedAt = nil
        }
    }
}

@Observable
@MainActor
final class BoardSelection {
    static let shared = BoardSelection()

    var inspectingDayKey: String
    var diaryDayKey: String

    init(now: Date = .now) {
        let today = DayKey.today(now)
        inspectingDayKey = today
        diaryDayKey = today
    }

    func inspectBoard(_ key: String) {
        inspectingDayKey = key
    }

    func inspectDiary(_ key: String) {
        diaryDayKey = key
    }
}
