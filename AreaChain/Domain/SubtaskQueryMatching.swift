import Foundation

/// 自身字段和父级页面约束分开求值；条件间 AND、clause 内 OR，沿 Session 的完整有效条件。
struct SubtaskQueryMatching {
    let request: SubtaskQueryRequest
    private let normalizedTagNames: [UUID: String]

    init(request: SubtaskQueryRequest) {
        self.request = request
        normalizedTagNames = (request.tagNames ?? [:]).mapValues(TagSyntax.normalizedName)
    }

    func match(_ child: SubtaskSnapshot, parent: TodoSnapshot) -> [ContentQueryMatchEvidence]? {
        var result: [ContentQueryMatchEvidence] = []
        for condition in request.session.conditions {
            guard let evidence = match(condition, child: child, parent: parent) else { return nil }
            result += evidence
        }
        return result
    }

    private func match(
        _ condition: ContentQueryCondition, child: SubtaskSnapshot, parent: TodoSnapshot
    ) -> [ContentQueryMatchEvidence]? {
        switch condition.value {
        case .scope: return [.init(conditionID: condition.id, field: .scope)]
        case .page(let predicate): return page(predicate, child: child, parent: parent, id: condition.id)
        case .clause(let terms):
            var matched: [ContentQueryMatchEvidence] = []
            for (index, term) in terms.enumerated() {
                if let evidence = termMatch(term, child: child, parent: parent, id: condition.id) {
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
        _ term: ContentQuerySemanticTerm, child: SubtaskSnapshot, parent: TodoSnapshot, id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        switch term.atom {
        case .text(let needle, _):
            return ContentQuerySnapshotMatching.text(needle, excluded: term.excluded, fields: [(.title, child.title)], id: id)
        case .tag(let name):
            return ContentQuerySnapshotMatching.tag(name, excluded: term.excluded, tagIDs: child.tagIDs,
                                                    normalizedNames: normalizedTagNames, id: id)
        case .status(let status):
            return evidence(child.isDone == (status == .done), id: id, field: .completion)
        case .date(let interval):
            return evidence(ContentQuerySnapshotMatching.contains(interval, day: parent.dayKey), id: id,
                            field: .parentScheduledDay, related: .init(type: .todo, id: parent.id))
        case .created(let interval):
            let day = DayKey.from(child.createdAt, calendar: request.session.queryDates.calendar)
            return evidence(ContentQuerySnapshotMatching.contains(interval, day: day), id: id, field: .createdAt)
        case .priority, .reminder, .image: return nil
        }
    }

    private func page(
        _ predicate: ContentQueryPagePredicate, child: SubtaskSnapshot, parent: TodoSnapshot, id: ContentQueryConditionID
    ) -> [ContentQueryMatchEvidence]? {
        let owner = CommandObjectReference(type: .todo, id: parent.id)
        switch predicate {
        case .tagID(let tagID, _):
            // taskOrSubtask 是父列表的入围规则，不能让父项或兄弟的标签成为该子任务自身命中。
            return evidence(TagIDList.contains(child.tagIDs, tagID), id: id, field: .tags,
                            related: .init(type: .tag, id: tagID))
        case .taskPriority(let priority):
            return evidence(TodoQueryPageRules.priority(priority, todo: parent, forSubtask: true),
                            id: id, field: .parentPriority, related: owner)
        case .noTags:
            return TagIDList.parse(child.tagIDs).isEmpty ? [.init(conditionID: id, field: .tags, kind: .absence)] : nil
        case .sourceApplication(let bundle):
            return evidence(Classification.matches(parent.classifyBits, filter: .init(bundleID: bundle)), id: id,
                            field: .parentSourceApplication, related: owner)
        case .reminderPresence(let scope):
            return evidence(Classification.matchesReminder(parent.remindMinutes, scope: scope), id: id,
                            field: .parentReminder, related: owner)
        case .boardDate(let scope, let rule):
            guard TodoQueryPageRules.boardDate(scope, rule: rule, todo: parent) else { return nil }
            let fields: [ContentQueryMatchField] = [.overdue, .upcoming].contains(scope)
                ? [.parentScheduledDay, .parentCompletion] : [.parentScheduledDay]
            return fields.map { .init(conditionID: id, field: $0, relatedObject: owner) }
        case .itemKind(let kind):
            return evidence(TodoQueryPageRules.listed(parent, dates: request.session.queryDates, kind: kind), id: id,
                            field: .parentItemKind, related: owner)
        case .todoStatus(let status):
            return evidence(TodoQueryPageRules.listed(parent, dates: request.session.queryDates, status: status), id: id,
                            field: .parentCompletion, related: owner)
        case .routineStatus:
            // ItemsListing 的习惯启停不限制一次性父任务及其子任务。
            return [.init(conditionID: id, field: .objectType, kind: .typeNeutral, relatedObject: owner)]
        case .contentTypes(let types): return evidence(types.contains(.subtask), id: id, field: .objectType)
        }
    }

    private func evidence(
        _ matched: Bool, id: ContentQueryConditionID, field: ContentQueryMatchField, related: CommandObjectReference? = nil
    ) -> [ContentQueryMatchEvidence]? {
        matched ? [.init(conditionID: id, field: field, relatedObject: related)] : nil
    }
}
