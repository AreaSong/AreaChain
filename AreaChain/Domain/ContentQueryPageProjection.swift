import Foundation

/// 一次派生投影，不是第二份可编辑真值。extended 条件只能回查询编辑，不能压成 BoardFilter。
struct ContentQueryPageProjection: Equatable {
    var fields: [ContentQueryConditionDimension: ContentQueryConditionValue] = [:]
    var extendedConditionIDs: [ContentQueryConditionID] = []
    var extendedDimensions: Set<ContentQueryConditionDimension> = []
    var boardFilter: BoardFilter?

    static func make(_ conditions: [ContentQueryCondition], context: ContentQueryPageContext) -> Self {
        var result = Self()
        let grouped = Dictionary(grouping: conditions) { $0.value.dimension }
        for (dimension, group) in grouped {
            guard let dimension else {
                result.extendedConditionIDs += group.map(\.id)
                continue
            }
            if dimension == .scope, group.allSatisfy({ $0.origin.isPage }) { continue }
            if group.count == 1, let value = group.first?.value, accepts(value, context: context) {
                result.fields[dimension] = value
            } else {
                result.extendedConditionIDs += group.map(\.id)
                result.extendedDimensions.insert(dimension)
            }
        }
        result.extendedConditionIDs.sort { $0.rawValue < $1.rawValue }
        if hasBoardFilter(context.page) { result.boardFilter = board(result.fields) }
        return result
    }

    static func accepts(_ value: ContentQueryConditionValue, context: ContentQueryPageContext) -> Bool {
        guard ContentQueryConditionValidation.invalid(value, dates: context.dates) == nil else { return false }
        guard let dimension = value.dimension, editableDimensions(context.page).contains(dimension) else { return false }
        switch dimension {
        case .content(.tag):
            if case .page(.tagID(_, let matching)) = value {
                switch context.page {
                case .pending, .items: return matching == .taskOrSubtask
                default: return matching == .own
                }
            }
            if case .page(.noTags) = value, case .diaries = context.page { return false }
            return value == .page(.noTags)
        case .content(.priority): return PriorityFilterScope.allCases.contains { ContentQueryPageMapping.priorityValue($0) == value }
        case .content(.date): return acceptsDate(value, context: context)
        case .content(.reminder):
            if case .page(.reminderPresence(let scope)) = value { return scope != .all }
            return false
        case .sourceApplication, .itemKind, .todoStatus, .routineStatus: return true
        default: return false
        }
    }

    static func editableDimensions(_ page: ContentQueryPage) -> Set<ContentQueryConditionDimension> {
        let board: Set<ContentQueryConditionDimension> = [.content(.tag), .content(.priority), .sourceApplication, .content(.date)]
        switch page {
        case .today: return board.union([.content(.reminder)])
        case .pending: return board
        case .items: return board.union([.itemKind, .todoStatus, .routineStatus])
        case .diaries: return [.content(.tag)]
        case .calendar, .schedule, .quadrants: return [.content(.date)]
        default: return []
        }
    }

    private static func acceptsDate(_ value: ContentQueryConditionValue, context: ContentQueryPageContext) -> Bool {
        if case .page(.boardDate(let scope, let rule)) = value {
            let evaluation: ContentQueryPageDateRule.Evaluation
            switch context.page {
            case .today: evaluation = .listedDay
            case .pending:
                guard [.overdue, .upcoming].contains(scope) else { return false }
                evaluation = .agenda
            case .items: evaluation = .items
            default: return false
            }
            return rule.evaluation == evaluation && rule.todayKey == context.todayKey && rule.calendar == context.calendar
        }
        // 原生日期页能接收区间，但 BoardFilter 的相对日期与绝对区间并非同一条件。
        if case .clause(let terms) = value, terms.count == 1, !terms[0].excluded, case .date(let interval) = terms[0].atom {
            switch context.page {
            case .calendar(_, let view): return represents(interval, view: view, calendar: context.calendar)
            case .schedule: return represents(interval, view: .month, calendar: context.calendar)
            case .quadrants: return interval.lowerBound == interval.upperBound
            default: return false
            }
        }
        return false
    }

    private static func represents(
        _ interval: ContentQueryDateInterval, view: ContentQueryCalendarView, calendar: Calendar
    ) -> Bool {
        let keys: [String]
        switch view {
        case .selectedDay: return interval.lowerBound == interval.upperBound
        case .week: keys = DayKey.weekKeys(containing: interval.lowerBound, calendar: calendar)
        case .month: keys = DayKey.daysInMonth(containing: interval.lowerBound, calendar: calendar)
        }
        return keys.first == interval.lowerBound && keys.last == interval.upperBound
    }

    private static func hasBoardFilter(_ page: ContentQueryPage) -> Bool {
        switch page {
        case .today, .pending, .items, .diaries: true
        default: false
        }
    }

    private static func board(_ fields: [ContentQueryConditionDimension: ContentQueryConditionValue]) -> BoardFilter {
        var filter = BoardFilter()
        for value in fields.values {
            switch value {
            case .page(.tagID(let id, _)): filter.tagID = id
            case .page(.noTags): filter.tagID = BoardFilter.noneID
            case .page(.sourceApplication(let bundle)): filter.bundleID = bundle
            case .page(.reminderPresence(let scope)): filter.reminderScope = scope
            case .page(.boardDate(let scope, _)): filter.dateScope = scope
            case .clause:
                if let scope = PriorityFilterScope.allCases.first(where: { ContentQueryPageMapping.priorityValue($0) == value }) {
                    filter = filter.withPriorityScope(scope)
                }
            default: break
            }
        }
        return filter
    }
}
