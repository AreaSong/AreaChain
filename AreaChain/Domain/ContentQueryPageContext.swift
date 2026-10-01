import Foundation

/// 宿主提供真实访问身份；刷新、面板、焦点变化必须沿用 visitID。
struct ContentQueryPageLocation: Equatable {
    let hostID: String
    let visitID: String
    let reference: String
}

enum ContentQueryPage: Equatable {
    case overview, settings, shortcuts, privacy, backup
    case today(BoardFilter)
    case pending(lane: PendingLane, filter: BoardFilter)
    case items(ItemsListingQuery)
    case diaries(tagID: UUID?)
    case images, clipboard, tags, trash
    case tagContents(tagID: UUID, types: Set<CommandObjectType>)
    case calendar(ContentQueryDateInterval, view: ContentQueryCalendarView = .selectedDay)
    case schedule(ContentQueryDateInterval)
    case quadrants(dayKey: String, selection: QuadrantSlot?)
}

/// selectedDay 对应现有选中日清单；现有日历的主视图切换只有 week/month。
enum ContentQueryCalendarView: Equatable { case selectedDay, week, month }

struct ContentQueryPageContext: Equatable {
    let location: ContentQueryPageLocation
    var page: ContentQueryPage
    let todayKey: String
    let calendar: Calendar

    var dates: ContentQueryDateContext { .init(todayKey: todayKey, calendar: calendar) }
}

enum ContentQueryPageMapping {
    static func defaults(_ context: ContentQueryPageContext) -> [ContentQueryConditionValue] {
        switch context.page {
        case .overview, .settings, .shortcuts, .privacy, .backup: return []
        case .today(let filter):
            var values = board(filter, context: context, evaluation: .listedDay, reminders: true)
            if filter.dateScope == .all { values.append(day(context.todayKey)) }
            return [.scope(.catalog(.tasks))] + values
        case .pending(let lane, let filter):
            var filter = filter
            filter.dateScope = lane == .overdue ? .overdue : .upcoming
            return [.scope(.catalog(.tasks))] + board(filter, context: context, evaluation: .agenda, reminders: false)
        case .items(let query):
            return items(query, context: context)
        case .diaries(let id):
            return [.scope(.catalog(.diaries))] + (id.map { [.page(.tagID($0))] } ?? [])
        case .images: return [.scope(.catalog(.images))]
        case .clipboard: return [.scope(.catalog(.clipboard))]
        case .tags: return [.scope(.catalog(.tags))]
        case .trash: return [.scope(.catalog(.trash))]
        case .tagContents(let id, let types):
            return [.scope(.global), .page(.tagID(id)), .page(.contentTypes(types))]
        case .calendar(let interval, _), .schedule(let interval):
            return [.scope(.catalog(.tasks)), .atom(.date(interval))]
        case .quadrants(let key, let selection):
            let priority = selection.map { ContentQueryConditionValue.atom(.priority(.init(
                isImportant: $0.isImportant, isUrgent: $0.isUrgent))) }
            return [.scope(.catalog(.tasks)), day(key)] + (priority.map { [$0] } ?? [])
        }
    }

    static func board(
        _ filter: BoardFilter, context: ContentQueryPageContext,
        evaluation: ContentQueryPageDateRule.Evaluation, reminders: Bool
    ) -> [ContentQueryConditionValue] {
        var values: [ContentQueryConditionValue] = []
        if let id = filter.tagID {
            let matching: ContentQueryTagMatching = evaluation == .listedDay ? .own : .taskOrSubtask
            values.append(.page(id == BoardFilter.noneID ? .noTags : .tagID(id, matching: matching)))
        }
        if let bundle = filter.bundleID { values.append(.page(.sourceApplication(bundle))) }
        let priority = filter.priorityScope == .all && filter.isHighPriorityOnly ? .highPriorityOnly : filter.priorityScope
        if let value = priorityValue(priority) { values.append(value) }
        if reminders, filter.reminderScope != .all { values.append(.page(.reminderPresence(filter.reminderScope))) }
        if filter.dateScope != .all {
            values.append(.page(.boardDate(filter.dateScope, .init(
                evaluation: evaluation, todayKey: context.todayKey, calendar: context.calendar))))
        }
        return values
    }

    static func priorityValue(_ scope: PriorityFilterScope) -> ContentQueryConditionValue? {
        let slots: [QuadrantSlot]
        switch scope {
        case .all: return nil
        case .highPriorityOnly: slots = [.importantUrgent, .important, .urgent]
        case .p1: slots = [.importantUrgent]
        case .p2: slots = [.important]
        case .p3: slots = [.urgent]
        case .p4: slots = [.rest]
        }
        return .clause(slots.map { .init(atom: .priority(.init(isImportant: $0.isImportant, isUrgent: $0.isUrgent))) })
    }

    private static func items(_ query: ItemsListingQuery, context: ContentQueryPageContext) -> [ContentQueryConditionValue] {
        var values: [ContentQueryConditionValue] = [.scope(.catalog(.tasks))]
        values += board(query.filter, context: context, evaluation: .items, reminders: false)
        if query.kind != .all { values.append(.page(.itemKind(query.kind))) }
        if query.todoStatus != .all { values.append(.page(.todoStatus(query.todoStatus))) }
        if query.routineStatus != .all { values.append(.page(.routineStatus(query.routineStatus))) }
        return values
    }

    private static func day(_ key: String) -> ContentQueryConditionValue {
        .atom(.date(.init(lowerBound: key, upperBound: key)))
    }
}
