import SwiftUI

/// 看板筛选的一条选项。宿主自己决定下拉、浮层或胶囊，选项值和清除结果只在这里生成。
struct BoardFilterChoice: Identifiable {
    var id: String
    var title: String
    var count: Int?
    var indent: CGFloat
    var isSelected: Bool
    var dotColor: Color?
    var systemImage: String?
    var applied: BoardFilter
    var cleared: BoardFilter
}

enum BoardFilterChoices {
    struct NamedRow: Identifiable {
        var id: UUID
        var name: String
        var depth: Int = 0
    }

    static func dates(filter: BoardFilter, locale: Locale) -> [BoardFilterChoice] {
        DateFilterScope.allCases.map { scope in
            BoardFilterChoice(
                id: "date.\(scope.rawValue)",
                title: scope.title(locale: locale),
                count: nil,
                indent: 0,
                isSelected: filter.dateScope == scope,
                dotColor: nil,
                systemImage: dateIcon(scope),
                applied: filter.withDateScope(scope),
                cleared: filter.withDateScope(.all)
            )
        }
    }

    static func reminders(filter: BoardFilter, locale: Locale) -> [BoardFilterChoice] {
        ReminderFilterScope.allCases.map { scope in
            BoardFilterChoice(
                id: "reminder.\(scope.rawValue)",
                title: scope.title(locale: locale),
                count: nil,
                indent: 0,
                isSelected: filter.reminderScope == scope,
                dotColor: nil,
                systemImage: scope == .unset ? "bell.slash" : "bell",
                applied: filter.withReminderScope(scope),
                cleared: filter.withReminderScope(.all)
            )
        }
    }

    static func priorities(filter: BoardFilter, locale: Locale) -> [BoardFilterChoice] {
        PriorityFilterScope.allCases.map { scope in
            BoardFilterChoice(
                id: "priority.\(scope.rawValue)",
                title: scope.title(locale: locale),
                count: nil,
                indent: 0,
                isSelected: priorityIsSelected(filter, scope: scope),
                dotColor: priorityDot(scope),
                systemImage: priorityIcon(scope),
                applied: filter.withPriorityScope(scope),
                cleared: filter.withPriorityScope(.all)
            )
        }
    }

    static func tags(
        filter: BoardFilter,
        rows: [NamedRow],
        counts: [UUID: Int],
        untaggedCount: Int?,
        includeNone: Bool,
        totalCount: Int? = nil,
        locale: Locale
    ) -> [BoardFilterChoice] {
        var items = [
            BoardFilterChoice(
                id: "all",
                title: L10n.string("filter.all", locale: locale),
                count: totalCount,
                indent: 0,
                isSelected: filter.tagID == nil,
                dotColor: nil,
                systemImage: nil,
                applied: filter.withTag(nil),
                cleared: filter.withTag(nil)
            )
        ]
        if includeNone {
            items.append(BoardFilterChoice(
                id: BoardFilter.noneID.uuidString,
                title: L10n.string("filter.tag.none", locale: locale),
                count: untaggedCount,
                indent: 0,
                isSelected: filter.isNoTag,
                dotColor: nil,
                systemImage: nil,
                applied: filter.withTag(BoardFilter.noneID),
                cleared: filter.withTag(nil)
            ))
        }
        items += rows.map { row in
            valueChoice(
                id: row.id,
                title: row.name,
                count: counts[row.id],
                indent: 0,
                isSelected: filter.tagID == row.id,
                dotColor: DiaryTagChrome.color(for: row.name),
                applied: filter.withTag(row.id),
                cleared: filter.withTag(nil)
            )
        }
        return items
    }

    static func bundles(filter: BoardFilter, bundleIDs: [String], locale: Locale) -> [BoardFilterChoice] {
        let all = BoardFilterChoice(
            id: "all",
            title: L10n.string("filter.all", locale: locale),
            count: nil,
            indent: 0,
            isSelected: filter.bundleID == nil,
            dotColor: nil,
            systemImage: nil,
            applied: filter.withBundle(nil),
            cleared: filter.withBundle(nil)
        )
        return [all] + bundleIDs.map { bundleID in
            BoardFilterChoice(
                id: bundleID,
                title: BundleDisplay.name(for: bundleID),
                count: nil,
                indent: 0,
                isSelected: filter.bundleID == bundleID,
                dotColor: nil,
                systemImage: nil,
                applied: filter.withBundle(bundleID),
                cleared: filter.withBundle(nil)
            )
        }
    }

    /// 标签名带 `#`；「全部」和「无标签」保持原文。
    static func markedTagTitle(_ choice: BoardFilterChoice) -> String {
        if choice.id == "all" || choice.id == BoardFilter.noneID.uuidString { return choice.title }
        return "#" + choice.title
    }

    static func priorityMark(_ filter: BoardFilter) -> (dot: Color?, icon: String?) {
        switch filter.priorityScope {
        case .all, .highPriorityOnly:
            return (nil, "exclamationmark.3")
        case .p1, .p2, .p3, .p4:
            return (priorityDot(filter.priorityScope), nil)
        }
    }

    private static func valueChoice(
        id: UUID,
        title: String,
        count: Int?,
        indent: CGFloat,
        isSelected: Bool,
        dotColor: Color? = nil,
        applied: BoardFilter,
        cleared: BoardFilter
    ) -> BoardFilterChoice {
        BoardFilterChoice(
            id: id.uuidString,
            title: title,
            count: count,
            indent: indent,
            isSelected: isSelected,
            dotColor: dotColor,
            systemImage: nil,
            applied: applied,
            cleared: cleared
        )
    }

    private static func dateIcon(_ scope: DateFilterScope) -> String {
        switch scope {
        case .all: "circle"
        case .today: "calendar"
        case .recent: "calendar.badge.clock"
        case .overdue: "clock.badge.exclamationmark"
        case .upcoming: "calendar.badge.plus"
        }
    }

    private static func priorityIcon(_ scope: PriorityFilterScope) -> String? {
        switch scope {
        case .all: "circle"
        case .highPriorityOnly: "exclamationmark.3"
        case .p1, .p2, .p3, .p4: nil
        }
    }

    private static func priorityDot(_ scope: PriorityFilterScope) -> Color? {
        switch scope {
        case .all, .highPriorityOnly: nil
        case .p1: QuadrantSlot.importantUrgent.themeColor
        case .p2: QuadrantSlot.important.themeColor
        case .p3: QuadrantSlot.urgent.themeColor
        case .p4: QuadrantSlot.rest.themeColor
        }
    }

    private static func priorityIsSelected(_ filter: BoardFilter, scope: PriorityFilterScope) -> Bool {
        switch scope {
        case .all:
            return filter.priorityScope == .all && !filter.isHighPriorityOnly
        case .highPriorityOnly:
            return filter.priorityScope == .highPriorityOnly
                || (filter.isHighPriorityOnly && filter.priorityScope == .all)
        case .p1, .p2, .p3, .p4:
            return filter.priorityScope == scope
        }
    }
}
