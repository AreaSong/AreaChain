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
        ContentQuerySnapshotMatching.text(needle, excluded: excluded,
                                         fields: [(.title, todo.title), (.notes, todo.notes)], id: id)
    }

    private func tag(
        _ name: String, excluded: Bool, todo: TodoSnapshot, id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        ContentQuerySnapshotMatching.tag(name, excluded: excluded, tagIDs: todo.tagIDs,
                                        normalizedNames: normalizedTagNames, id: id)
    }

    private func page(
        _ predicate: ContentQueryPagePredicate, todo: TodoSnapshot, id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        switch predicate {
        case .tagID(let tagID, let matching): return pageTag(tagID, matching: matching, todo: todo, id: id)
        case .taskPriority(let priority):
            return evidence(TodoQueryPageRules.priority(priority, todo: todo), id: id, field: .priority)
        case .noTags: return evidence(TagIDList.parse(todo.tagIDs).isEmpty, id: id, field: .tags, kind: .absence)
        case .sourceApplication(let bundle):
            return evidence(Classification.matches(todo.classifyBits, filter: .init(bundleID: bundle)),
                            id: id, field: .sourceApplication)
        case .reminderPresence(let scope):
            return evidence(Classification.matchesReminder(todo.remindMinutes, scope: scope), id: id, field: .reminder)
        case .boardDate(let scope, let rule):
            guard TodoQueryPageRules.boardDate(scope, rule: rule, todo: todo) else { return nil }
            let fields: [ContentQueryMatchField] = [.overdue, .upcoming].contains(scope)
                ? [.scheduledDay, .completion] : [.scheduledDay]
            return fields.map { .init(conditionID: id, field: $0) }
        case .contentTypes(let types): return evidence(types.contains(.todo), id: id, field: .objectType)
        case .itemKind(let kind):
            return evidence(TodoQueryPageRules.listed(todo, dates: request.session.queryDates, kind: kind), id: id, field: .objectType)
        case .todoStatus(let status):
            return evidence(TodoQueryPageRules.listed(todo, dates: request.session.queryDates, status: status), id: id, field: .completion)
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

    private func evidence(
        _ matched: Bool, id: ContentQueryConditionID, field: ContentQueryMatchField, kind: ContentQueryMatchKind = .positive
    ) -> [ContentQueryMatchEvidence]? {
        matched ? [.init(conditionID: id, field: field, kind: kind)] : nil
    }

    private func contains(_ interval: ContentQueryDateInterval, day: String) -> Bool {
        ContentQuerySnapshotMatching.contains(interval, day: day)
    }
}
