import Foundation

/// 只接收通过提供者前置检查的请求。条件间 AND、同一 clause 内 OR；不读取或重解析 input.source。
struct TodoQueryMatching {
    let request: TodoQueryRequest
    private let normalizedTagNames: [UUID: String]

    init(request: TodoQueryRequest) {
        self.request = request
        normalizedTagNames = (request.tagNames ?? [:]).mapValues(TagSyntax.normalizedName)
    }

    func match(_ todo: TodoSnapshot) -> [ContentQueryMatchEvidence]? {
        var evidence: [ContentQueryMatchEvidence] = []
        for condition in request.session.conditions {
            guard let matched = match(condition, todo: todo) else { return nil }
            evidence += matched
        }
        return evidence
    }

    private func match(_ condition: ContentQueryCondition, todo: TodoSnapshot) -> [ContentQueryMatchEvidence]? {
        switch condition.value {
        case .scope: return [.init(conditionID: condition.id, field: .scope)]
        case .page(let predicate): return page(predicate, todo: todo, id: condition.id)
        case .clause(let terms):
            var matched: [ContentQueryMatchEvidence] = []
            for (index, term) in terms.enumerated() {
                if let evidence = termMatch(term, todo: todo, id: condition.id) {
                    matched += evidence.map { item in
                        var item = item
                        item.alternativeIndex = index
                        return item
                    }
                }
            }
            return matched.isEmpty ? nil : matched
        }
    }

    private func termMatch(
        _ term: ContentQuerySemanticTerm, todo: TodoSnapshot, id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        switch term.atom {
        case .text(let needle, _): return text(needle, excluded: term.excluded, todo: todo, id: id)
        case .tag(let name): return tag(name, excluded: term.excluded, todo: todo, id: id)
        case .priority(let flags):
            return evidence(todo.isImportant == flags.isImportant && todo.isUrgent == flags.isUrgent, id: id, field: .priority)
        case .reminder(let minutes): return evidence(todo.remindMinutes == minutes, id: id, field: .reminder)
        case .status(let status): return evidence(todo.isDone == (status == .done), id: id, field: .completion)
        case .date(let interval): return evidence(contains(interval, day: todo.dayKey), id: id, field: .scheduledDay)
        case .created(let interval):
            let day = DayKey.from(todo.createdAt, calendar: request.session.queryDates.calendar)
            return evidence(contains(interval, day: day), id: id, field: .createdAt)
        case .image: return nil
        }
    }

    private func text(
        _ needle: String, excluded: Bool, todo: TodoSnapshot, id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        let fields: [(ContentQueryMatchField, String)] = [(.title, todo.title), (.notes, todo.notes)]
        let found = fields.filter { BoardSearch.matches($0.1, needle: needle) }
        if excluded {
            guard found.isEmpty else { return nil }
            return fields.map { .init(conditionID: id, field: $0.0, kind: .absence) }
        }
        guard !found.isEmpty else { return nil }
        return found.map { field, original in
            // 与 localizedStandardContains 对应的原文 Range；不对折叠/规范化副本求偏移。
            let range = original.localizedStandardRange(of: needle).map {
                // Foundation 的不计变音搜索可能在组合重音前结束；高亮扩展到原文完整字素。
                (original as NSString).rangeOfComposedCharacterSequences(for: NSRange($0, in: original))
            }
            return .init(conditionID: id, field: field, range: range)
        }
    }

    private func tag(
        _ name: String, excluded: Bool, todo: TodoSnapshot, id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        let normalized = TagSyntax.normalizedName(name)
        let matched = TagIDList.normalized(TagIDList.parse(todo.tagIDs)).filter { normalizedTagNames[$0] == normalized }
        if excluded { return matched.isEmpty ? [.init(conditionID: id, field: .tags, kind: .absence)] : nil }
        guard !matched.isEmpty else { return nil }
        return matched.map { .init(conditionID: id, field: .tags, relatedObject: .init(type: .tag, id: $0)) }
    }

    private func page(
        _ predicate: ContentQueryPagePredicate, todo: TodoSnapshot, id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        switch predicate {
        case .tagID(let tagID, let matching): return pageTag(tagID, matching: matching, todo: todo, id: id)
        case .noTags: return evidence(TagIDList.parse(todo.tagIDs).isEmpty, id: id, field: .tags, kind: .absence)
        case .sourceApplication(let bundle):
            return evidence(Classification.matches(todo.classifyBits, filter: .init(bundleID: bundle)),
                            id: id, field: .sourceApplication)
        case .reminderPresence(let scope):
            return evidence(Classification.matchesReminder(todo.remindMinutes, scope: scope), id: id, field: .reminder)
        case .boardDate(let scope, let rule): return evidence(boardDate(scope, rule: rule, todo: todo), id: id, field: .scheduledDay)
        case .contentTypes(let types): return evidence(types.contains(.todo), id: id, field: .objectType)
        case .itemKind(let kind):
            return evidence(listed(todo, kind: kind), id: id, field: .objectType)
        case .todoStatus(let status):
            return evidence(listed(todo, status: status), id: id, field: .completion)
        case .routineStatus:
            // ItemsListing.todos 仅消费 todoStatus；习惯启停不是 todo 的完成状态。
            return [.init(conditionID: id, field: .objectType, kind: .typeNeutral)]
        }
    }

    private func pageTag(
        _ tagID: UUID, matching: ContentQueryTagMatching, todo: TodoSnapshot, id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        let own = TagIDList.contains(todo.tagIDs, tagID)
        if matching == .own {
            return own ? [.init(conditionID: id, field: .tags, relatedObject: .init(type: .tag, id: tagID))] : nil
        }
        guard ItemsListing.hasTag(todo, id: tagID) else { return nil }
        var result: [ContentQueryMatchEvidence] = own
            ? [.init(conditionID: id, field: .tags, relatedObject: .init(type: .tag, id: tagID))] : []
        result += todo.subtasks.filter { $0.deletedAt == nil && TagIDList.contains($0.tagIDs, tagID) }.map {
            .init(conditionID: id, field: .subtaskTags, relatedObject: .init(type: .subtask, id: $0.id))
        }
        return result
    }

    private func boardDate(_ scope: DateFilterScope, rule: ContentQueryPageDateRule, todo: TodoSnapshot) -> Bool {
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

    private func listed(_ todo: TodoSnapshot, kind: ItemKindScope = .all, status: TodoStatusScope = .all) -> Bool {
        let dates = request.session.queryDates
        let query = ItemsListingQuery(kind: kind, todoStatus: status, todayKey: dates.todayKey)
        return !ItemsListing.todos([todo], query: query, calendar: dates.calendar).isEmpty
    }

    private func evidence(
        _ matched: Bool, id: ContentQueryConditionID, field: ContentQueryMatchField, kind: ContentQueryMatchKind = .positive
    ) -> [ContentQueryMatchEvidence]? {
        matched ? [.init(conditionID: id, field: field, kind: kind)] : nil
    }

    private func contains(_ interval: ContentQueryDateInterval, day: String) -> Bool {
        interval.lowerBound <= day && day <= interval.upperBound
    }
}
