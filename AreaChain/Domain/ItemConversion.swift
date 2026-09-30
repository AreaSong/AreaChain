import Foundation

enum ItemConversion {
    /// 子任务标题逐行接在原备注后面。空标题略过。没有子任务时原备注保持不动。
    static func foldedNotes(existing: String, subtaskTitles: [String]) -> String {
        let lines = subtaskTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return existing }
        let block = lines.joined(separator: "\n")
        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return block }
        let separator = existing.hasSuffix("\n") ? "" : "\n"
        return existing + separator + block
    }

    static func weekdayMask(for dayKey: String, calendar: Calendar = .current) -> Int {
        guard let date = DayKey.date(from: dayKey, calendar: calendar) else { return WeekdayMask.all }
        return WeekdayMask.only(weekday: calendar.component(.weekday, from: date))
    }
}
