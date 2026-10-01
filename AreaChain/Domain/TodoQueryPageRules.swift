import Foundation

/// 父任务的既有页面入围口径；独立子任务只委托这些页面约束，不把父项整条查询先跑一遍。
enum TodoQueryPageRules {
    static func priority(_ priority: ContentQueryPagePriority, todo: TodoSnapshot, forSubtask: Bool = false) -> Bool {
        // BoardSearch.subtaskHits 的旧特例；明确 P1–P4 不等同 highPriorityOnly 开关。
        guard !forSubtask || !priority.highPriorityOnly else { return false }
        return Classification.matches(todo.classifyBits, filter: priority.filter)
    }

    static func boardDate(_ scope: DateFilterScope, rule: ContentQueryPageDateRule, todo: TodoSnapshot) -> Bool {
        switch rule.evaluation {
        case .listedDay:
            return Classification.matchesDate(dayKey: todo.dayKey, isDone: todo.isDone, todayKey: rule.todayKey,
                                              scope: scope, calendar: rule.calendar)
        case .items:
            let query = ItemsListingQuery(filter: .init(dateScope: scope), todayKey: rule.todayKey)
            return !ItemsListing.todos([todo], query: query, calendar: rule.calendar).isEmpty
        case .agenda:
            switch scope {
            case .overdue:
                return !AgendaProjection.overdueTodos(todos: [todo], todayKey: rule.todayKey, calendar: rule.calendar).isEmpty
            case .upcoming:
                return !AgendaProjection.upcomingTodos(todos: [todo], todayKey: rule.todayKey, calendar: rule.calendar).isEmpty
            default: return false
            }
        }
    }

    static func listed(
        _ todo: TodoSnapshot, dates: ContentQueryDateContext, kind: ItemKindScope = .all, status: TodoStatusScope = .all
    ) -> Bool {
        let query = ItemsListingQuery(kind: kind, todoStatus: status, todayKey: dates.todayKey)
        return !ItemsListing.todos([todo], query: query, calendar: dates.calendar).isEmpty
    }
}
