import Foundation

/// 静态分析没有快照或提供者注册表；possible 仅表示未证明不可能，不能证明有结果或覆盖完整。
struct ContentQueryTypeAnalysis: Equatable {
    let requestedTypes: Set<CommandObjectType>
    let types: [ContentQueryTypeAssessment]

    var possibleTypes: Set<CommandObjectType> { Set(types.filter(\.isPossible).map(\.type)) }
    func assessment(for type: CommandObjectType) -> ContentQueryTypeAssessment? { types.first { $0.type == type } }
}

struct ContentQueryTypeAssessment: Equatable {
    let type: CommandObjectType
    var reasons: [ContentQueryTypeReason] = []

    var isPossible: Bool { !reasons.contains { [.contradiction, .fieldNotApplicable].contains($0.issue) } }
    var requiresInput: Bool { reasons.contains { $0.issue == .requiresOccurrenceDay } }
}

struct ContentQueryTypeReason: Equatable {
    enum Issue: Equatable { case contradiction, fieldNotApplicable, requiresOccurrenceDay, analysisLimit }
    let issue: Issue
    let conditionIDs: [ContentQueryConditionID]
    let binding: ContentQueryFieldBinding
}

/// 只在绑定一致的字段上复用原 AND/OR 算法；页面复合约束先展开成它真实约束的字段。
enum ContentQueryTypeValidation {
    private struct Constraint {
        let id: ContentQueryConditionID
        let binding: ContentQueryFieldBinding
        let dimension: ContentQueryDimension
        let terms: [ContentQuerySemanticTerm]
    }

    static func analyze(
        _ conditions: [ContentQueryCondition], requestedTypes: Set<CommandObjectType>, occurrenceDay: String? = nil
    ) -> ContentQueryTypeAnalysis {
        let types = requestedTypes.sorted { $0.rawValue < $1.rawValue }.map { type in
            assess(conditions, type: type, occurrenceDay: occurrenceDay)
        }
        return .init(requestedTypes: requestedTypes, types: types)
    }

    private static func assess(
        _ conditions: [ContentQueryCondition], type: CommandObjectType, occurrenceDay: String?
    ) -> ContentQueryTypeAssessment {
        var result = ContentQueryTypeAssessment(type: type)
        var constraints: [Constraint] = []
        for condition in conditions {
            switch condition.value {
            case .scope: break
            case .clause(let terms):
                guard let dimension = terms.first?.atom.dimension else { continue }
                let binding = ContentQueryApplicability.binding(dimension, to: type, occurrenceDay: occurrenceDay)
                if let issue = applicabilityIssue(binding) {
                    result.reasons.append(.init(issue: issue, conditionIDs: [condition.id], binding: binding))
                } else {
                    constraints.append(.init(id: condition.id, binding: binding, dimension: dimension, terms: terms))
                }
            case .page(let predicate):
                constraints += page(predicate, condition: condition, result: &result)
            }
        }
        var seen: Set<ContentQueryFieldBinding> = []
        for binding in constraints.map(\.binding) where seen.insert(binding).inserted {
            let group = constraints.filter { $0.binding == binding }
            guard let dimension = group.first?.dimension else { continue }
            let answer = ContentQueryValidation.satisfiable(group.map(\.terms), dimension: dimension)
            if answer != true {
                result.reasons.append(.init(issue: answer == nil ? .analysisLimit : .contradiction,
                                           conditionIDs: uniqueIDs(group.map(\.id)), binding: binding))
            }
        }
        result.reasons += pageConflicts(conditions, type: type)
        return result
    }

    private static func applicabilityIssue(_ binding: ContentQueryFieldBinding) -> ContentQueryTypeReason.Issue? {
        switch binding {
        case .notApplicable: .fieldNotApplicable
        case .requiresOccurrenceDay: .requiresOccurrenceDay
        default: nil
        }
    }

    private static func page(
        _ predicate: ContentQueryPagePredicate, condition: ContentQueryCondition, result: inout ContentQueryTypeAssessment
    ) -> [Constraint] {
        let type = result.type
        let taskTypes: Set<CommandObjectType> = [.todo, .subtask, .routine]
        let binding = ContentQueryApplicability.pageBinding(predicate, to: type)
        if binding == .notApplicable {
            result.reasons.append(.init(issue: .fieldNotApplicable, conditionIDs: [condition.id], binding: binding))
            return []
        }
        func constraint(_ atom: ContentQueryAtom, _ field: ContentQueryFieldBinding) -> [Constraint] {
            [.init(id: condition.id, binding: field, dimension: atom.dimension, terms: [.init(atom: atom)])]
        }
        switch predicate {
        case .taskPriority(let priority):
            if type == .subtask && priority.highPriorityOnly {
                result.reasons.append(.init(issue: .contradiction, conditionIDs: [condition.id], binding: .parentPriority))
            }
            let terms = priorityTerms(priority)
            return [.init(id: condition.id, binding: binding, dimension: .priority, terms: terms)]
        case .todoStatus(let status) where type != .routine:
            return constraint(.status(status == .done ? .done : .open), binding)
        case .boardDate(let scope, let rule) where type == .todo || type == .subtask:
            // 非既有 agenda 组合留给提供者报告能力缺口，不在静态层发明语义。
            guard rule.evaluation != .agenda || [.overdue, .upcoming].contains(scope) else { return [] }
            var values: [Constraint] = []
            if [.overdue, .upcoming].contains(scope) {
                values += constraint(.status(.open), type == .subtask ? .parentCompletion : .ownCompletion)
            }
            if let interval = pageInterval(scope, rule: rule) { values += constraint(.date(interval), binding) }
            return values
        case .contentTypes(let types) where !types.contains(type):
            result.reasons.append(.init(issue: .contradiction, conditionIDs: [condition.id], binding: .objectType))
        case .itemKind(let kind) where taskTypes.contains(type):
            if (kind == .recurring && type != .routine) || (kind == .oneOff && type == .routine) {
                result.reasons.append(.init(issue: .contradiction, conditionIDs: [condition.id], binding: .objectType))
            }
        default: break
        }
        return []
    }

    private static func pageInterval(_ scope: DateFilterScope, rule: ContentQueryPageDateRule) -> ContentQueryDateInterval? {
        switch scope {
        case .all: return nil
        case .today: return .init(lowerBound: rule.todayKey, upperBound: rule.todayKey)
        case .recent:
            return .init(lowerBound: rule.todayKey, upperBound: DayKey.shifted(rule.todayKey, by: 7, calendar: rule.calendar))
        case .overdue:
            return .init(lowerBound: "0001-01-01", upperBound: DayKey.shifted(rule.todayKey, by: -1, calendar: rule.calendar))
        case .upcoming:
            return .init(lowerBound: DayKey.shifted(rule.todayKey, by: 1, calendar: rule.calendar), upperBound: "9999-12-31")
        }
    }

    private static func priorityTerms(_ priority: ContentQueryPagePriority) -> [ContentQuerySemanticTerm] {
        [false, true].flatMap { important in
            [false, true].compactMap { urgent in
                let bits = ClassifyBits(tagIDs: "", isImportant: important, isUrgent: urgent, sourceBundleID: "")
                guard Classification.matches(bits, filter: priority.filter) else { return nil }
                return ContentQuerySemanticTerm(atom: .priority(.init(isImportant: important, isUrgent: urgent)))
            }
        }
    }

    private static func pageConflicts(_ conditions: [ContentQueryCondition], type: CommandObjectType) -> [ContentQueryTypeReason] {
        var result: [ContentQueryTypeReason] = []
        for left in conditions {
            guard case .page = left.value else { continue }
            for right in conditions where left.id != right.id {
                if case .page = right.value, right.id.rawValue < left.id.rawValue { continue }
                if let binding = conflict(left.value, right.value, type: type)
                    ?? conflict(right.value, left.value, type: type) {
                    result.append(.init(issue: .contradiction, conditionIDs: [left.id, right.id], binding: binding))
                }
            }
        }
        return result
    }

    private static func conflict(
        _ lhs: ContentQueryConditionValue, _ rhs: ContentQueryConditionValue, type: CommandObjectType
    ) -> ContentQueryFieldBinding? {
        guard case .page(let predicate) = lhs else { return nil }
        let binding = ContentQueryApplicability.pageBinding(predicate, to: type)
        guard binding != .notApplicable && binding != .typeNeutral else { return nil }
        switch predicate {
        case .noTags:
            if case .page(.tagID(_, let matching)) = rhs, matching == .own || type != .todo { return .ownTags }
            if case .clause(let terms) = rhs, !terms.isEmpty,
               terms.allSatisfy({ $0.atom.dimension == .tag && !$0.excluded }) { return .ownTags }
        case .reminderPresence(.unset):
            if case .page(.reminderPresence(.set)) = rhs { return binding }
            if case .clause(let terms) = rhs, terms.first?.atom.dimension == .reminder,
               ContentQueryApplicability.binding(.reminder, to: type) == binding { return binding }
        case .sourceApplication(let source):
            if case .page(.sourceApplication(let other)) = rhs, source != other { return binding }
        case .routineStatus(let status) where type == .routine:
            if case .page(.routineStatus(let other)) = rhs, status != other { return binding }
        default: break
        }
        return nil
    }

    private static func uniqueIDs(_ ids: [ContentQueryConditionID]) -> [ContentQueryConditionID] {
        var seen: Set<ContentQueryConditionID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
