import AppKit
import SwiftUI

/// 安排页行内的纯文字推算（星期缩写、标题是否被截断）；从 GanttPage 原样移出，行为不变。
enum GanttRowText {
    static func weekdaySymbol(for key: String, calendar: Calendar) -> String {
        guard let date = DayKey.date(from: key, calendar: calendar) else { return "" }
        let weekday = calendar.component(.weekday, from: date)
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard (1...symbols.count).contains(weekday) else { return "" }
        return symbols[weekday - 1]
    }

    static func isTitleTruncated(_ title: String, titleWidth: CGFloat, hasPriority: Bool) -> Bool {
        let font = NSFont.systemFont(ofSize: DaybookType.captionSize, weight: .medium)
        let textWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
        let reservedWidth: CGFloat = GanttRowMetrics.checkboxWidth + (hasPriority ? 26 : 0) + 14
        return textWidth > max(40, titleWidth - reservedWidth)
    }
}
