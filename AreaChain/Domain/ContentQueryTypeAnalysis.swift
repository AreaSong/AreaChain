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
    /// 仅 image 使用；type 在此数组内表示拥有者，不能据此扩大提供者结果类型。
    var imageOwnerAssessments: [ContentQueryTypeAssessment] = []

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
        let selection = ContentQueryOccurrenceDay.resolve(conditions, explicitDay: occurrenceDay)
        let types = requestedTypes.sorted { $0.rawValue < $1.rawValue }.map { type in
            type == .image ? assessImage(conditions, selection: selection)
                : assess(conditions, type: type, selection: selection)
        }
        return .init(requestedTypes: requestedTypes, types: types)
    }

    private static func assessImage(
        _ conditions: [ContentQueryCondition], selection: ContentQueryOccurrenceDay
    ) -> ContentQueryTypeAssessment {
        // 复用每类拥有者的字段冲突分析；created 始终独立于业务 date，文字仍由图片匹配器选择 filename。
        let ownerConditions = conditions.map { condition in
            var value = condition
            if case .page(.contentTypes(let types)) = value.value {
                value.value = .page(.contentTypes(types.contains(.image) ? [.todo, .routine, .diary] : []))
            }
            if case .page(.tagID(let id, _)) = value.value { value.value = .page(.tagID(id, matching: .own)) }
            return value
        }
        var branches = [CommandObjectType.todo, .routine, .diary].map {
            assess(ownerConditions, type: $0, selection: selection)
        }
        let imageConditions = conditions.filter {
            if case .clause(let terms) = $0.value { return terms.contains { $0.atom == .image } }
            return false
        }
        if !imageConditions.isEmpty {
            for index in branches.indices {
                branches[index].reasons.append(.init(issue: .fieldNotApplicable,
                    conditionIDs: imageConditions.map(\.id), binding: .notApplicable))
            }
        }
        var result = ContentQueryTypeAssessment(type: .image, imageOwnerAssessments: branches)
        if !imageConditions.isEmpty {
            result.reasons = [.init(issue: .fieldNotApplicable, conditionIDs: imageConditions.map(\.id), binding: .notApplicable)]
        } else {
            let possible = branches.filter(\.isPossible)
            if possible.isEmpty { result.reasons = branches.flatMap(\.reasons) }
            else if possible.allSatisfy(\.requiresInput) {
                result.reasons = possible.flatMap(\.reasons).filter { $0.issue == .requiresOccurrenceDay }
            }
        }
        return result
    }

    private static func assess(
        _ conditions: [ContentQueryCondition], type: CommandObjectType, selection: ContentQueryOccurrenceDay
    ) -> ContentQueryTypeAssessment {
        var result = ContentQueryTypeAssessment(type: type)
        var constraints: [Constraint] = []
        for condition in conditions {
            switch condition.value {
            case .scope: break
            case .clause(let terms):
                constraints += clause(terms, id: condition.id, selection: selection, result: &result)
            case .page(let predicate):
                constraints += page(predicate, condition: condition, result: &result)
            }
        }
        constraints += occurrenceWindow(conditions, type: type, selection: selection)
        if case .invalid = selection, [.routine, .routineOccurrence].contains(type) {
            result.reasons.append(.init(issue: .contradiction, conditionIDs: conditions.filter {
                $0.value.dimension == .content(.on)
            }.map(\.id), binding: .occurrenceDay))
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

    private static func clause(
        _ terms: [ContentQuerySemanticTerm], id: ContentQueryConditionID,
        selection: ContentQueryOccurrenceDay, result: inout ContentQueryTypeAssessment
    ) -> [Constraint] {
        let bindings = terms.map { ContentQueryApplicability.binding(for: $0.atom, to: result.type, occurrenceDay: selection.dayKey) }
        guard let first = bindings.first, let dimension = terms.first?.atom.dimension else { return [] }
        // OR 不能隐藏该类型不具备的状态；理由锚定原条件，不改写条件或缩小请求类型。
        let binding: ContentQueryFieldBinding = bindings.contains(.notApplicable) ? .notApplicable : first
        if let issue = applicabilityIssue(binding) {
            result.reasons.append(.init(issue: issue, conditionIDs: [id], binding: binding))
        }
        guard binding != .notApplicable else { return [] }
        let values = terms.map { term -> ContentQuerySemanticTerm in
            if case .on(let day) = term.atom { return .init(atom: .date(.init(lowerBound: day, upperBound: day))) }
            return term
        }
        // 缺 on 仍保留同一执行日的互斥状态分析；缺输入不能掩盖 open AND done。
        return [.init(id: id, binding: binding, dimension: dimension == .on ? .date : dimension, terms: values)]
    }

    private static func occurrenceWindow(
        _ conditions: [ContentQueryCondition], type: CommandObjectType, selection: ContentQueryOccurrenceDay
    ) -> [Constraint] {
        guard type == .routine, let day = selection.dayKey,
              conditions.contains(where: { if case .clause(let terms) = $0.value {
                  return terms.first?.atom.dimension == .date
              }; return false }) else { return [] }
        let dateIDs = conditions.filter { $0.value.dimension == .content(.date) }.map(\.id)
        let onIDs = conditions.filter { $0.value.dimension == .content(.on) }.map(\.id)
        // 仅文本业务窗口和 on 建关系；页面逾期排程投影与 created 不在此字段绑定里。
        return (onIDs.isEmpty ? Array(dateIDs.prefix(1)) : onIDs).map {
            .init(id: $0, binding: .scheduledDayExistenceReturningOneDefinition, dimension: .date,
                  terms: [.init(atom: .date(.init(lowerBound: day, upperBound: day)))])
        }
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
