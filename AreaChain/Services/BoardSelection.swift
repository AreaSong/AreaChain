import Foundation
import Observation

/// 维护看板与手记的日期选择与详情查看状态
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
