import Foundation

/// 月格和周格在获得焦点时的方向键。清单获得焦点后改由清单自己移动。
enum CalendarGridStep: Equatable {
    case previousDay
    case nextDay
    case previousWeek
    case nextWeek

    static func from(keyCode: UInt16) -> CalendarGridStep? {
        switch keyCode {
        case 123: return .previousDay
        case 124: return .nextDay
        case 126: return .previousWeek
        case 125: return .nextWeek
        default: return nil
        }
    }

    func apply(to key: String, calendar: Calendar) -> String {
        switch self {
        case .previousDay: return DayKey.shifted(key, by: -1, calendar: calendar)
        case .nextDay: return DayKey.shifted(key, by: 1, calendar: calendar)
        case .previousWeek: return DayKey.shifted(key, by: -7, calendar: calendar)
        case .nextWeek: return DayKey.shifted(key, by: 7, calendar: calendar)
        }
    }
}
