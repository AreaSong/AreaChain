import Foundation

/// 任务页和手记页共用的范围。两边是同一页清单的两种内容，不是两套页面类型。
enum BoardTab: String, CaseIterable, Identifiable, Equatable, Sendable {
    case tasks
    case diary

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .tasks: "tab.tasks"
        case .diary: "tab.diary"
        }
    }

    var helpKey: String {
        switch self {
        case .tasks: "segmented.bar.tasks.help"
        case .diary: "segmented.bar.diary.help"
        }
    }
}

/// 一页清单的筛选。任务和手记各持有一份 `BoardFilter`；手记只使用标签这一维。
struct BoardFilters: Equatable {
    var tasks = BoardFilter()
    var diary = BoardFilter()

    func selection(for scope: BoardTab) -> BoardFilter {
        switch scope {
        case .tasks: tasks
        case .diary: diary
        }
    }

    mutating func write(_ filter: BoardFilter, for scope: BoardTab) {
        switch scope {
        case .tasks:
            tasks = filter
        case .diary:
            diary = BoardFilter(tagID: filter.tagID)
        }
    }

    mutating func clear(_ scope: BoardTab) {
        write(BoardFilter(), for: scope)
    }

    func activeCount(for scope: BoardTab) -> Int {
        let filter = selection(for: scope)
        switch scope {
        case .diary:
            return filter.tagID == nil ? 0 : 1
        case .tasks:
            let priorityActive = filter.isHighPriorityOnly || filter.priorityScope != .all
            return [
                filter.projectID != nil,
                filter.tagID != nil,
                filter.bundleID != nil,
                priorityActive,
                filter.dateScope != .all
            ].filter { $0 }.count
        }
    }
}

extension DateFilterScope {
    func title(locale: Locale) -> String {
        switch self {
        case .all: L10n.string("filter.all", locale: locale)
        case .today: L10n.string("filter.date.today", locale: locale)
        case .recent: L10n.string("filter.date.recent", locale: locale)
        case .overdue: L10n.string("filter.date.overdue", locale: locale)
        }
    }
}

extension PriorityFilterScope {
    func title(locale: Locale) -> String {
        switch self {
        case .all: L10n.string("filter.all", locale: locale)
        case .highPriorityOnly: L10n.string("filter.priority.high", locale: locale)
        case .p1: L10n.string("filter.priority.p1", locale: locale)
        case .p2: L10n.string("filter.priority.p2", locale: locale)
        case .p3: L10n.string("filter.priority.p3", locale: locale)
        case .p4: L10n.string("filter.priority.p4", locale: locale)
        }
    }
}

extension BoardFilter {
    func priorityTitle(locale: Locale) -> String {
        if priorityScope == .all && isHighPriorityOnly {
            return PriorityFilterScope.highPriorityOnly.title(locale: locale)
        }
        if priorityScope == .all { return "" }
        return priorityScope.title(locale: locale)
    }
}
