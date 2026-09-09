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
    var inspectingDiaryID: UUID?
    var discardEditsOnBlur = false

    init(now: Date = .now) {
        let today = DayKey.today(now)
        inspectingDayKey = today
        diaryDayKey = today
    }

    func inspectBoard(_ key: String) {
        inspectingDayKey = key
        inspectingDiaryID = nil
    }

    func inspectDiary(id: UUID, dayKey: String) {
        diaryDayKey = dayKey
        inspectingDiaryID = id
    }

    func clearInspectedDiary() {
        inspectingDiaryID = nil
    }

    func markEscapeCancelsEdits() {
        discardEditsOnBlur = true
    }

    func consumeEscapeCancelsEdits() -> Bool {
        let flagged = discardEditsOnBlur
        discardEditsOnBlur = false
        return flagged
    }
}
