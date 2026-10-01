import Foundation

enum ContentQueryConditionValidation {
    static func diagnostics(
        _ conditions: [ContentQueryCondition], dates: ContentQueryDateContext
    ) -> [ContentQueryConditionDiagnostic] {
        var result = conditions.compactMap { condition -> ContentQueryConditionDiagnostic? in
            guard let issue = invalid(condition.value, dates: dates) else { return nil }
            return .init(issue: issue, conditionIDs: [condition.id])
        }
        let scopes = conditions.filter { $0.value.dimension == .scope }
        if let first = scopes.first {
            result += scopes.dropFirst().map {
                .init(issue: $0.value == first.value ? .duplicateCondition : .incompatibleScopes,
                      conditionIDs: [first.id, $0.id])
            }
        }
        for dimension in ContentQueryDimension.allCases {
            let matching = conditions.filter {
                guard case .clause = $0.value else { return false }
                return $0.value.dimension == .content(dimension)
            }
            let clauses = matching.compactMap { condition -> [ContentQuerySemanticTerm]? in
                if case .clause(let terms) = condition.value { return terms }
                return nil
            }
            let satisfiable = ContentQueryValidation.satisfiable(clauses, dimension: dimension)
            if !clauses.isEmpty, satisfiable != true {
                let issue: ContentQueryIssue = satisfiable == nil ? .analysisLimit : .unsatisfiable
                result.append(.init(issue: issue, conditionIDs: matching.map(\.id)))
            }
        }
        result += pageConflicts(conditions)
        return result
    }

    static func invalid(_ value: ContentQueryConditionValue, dates: ContentQueryDateContext) -> ContentQueryIssue? {
        switch value {
        case .scope: return nil
        case .clause(let terms):
            guard let first = terms.first else { return .incompleteCondition }
            guard terms.allSatisfy({ $0.atom.dimension == first.atom.dimension }) else { return .mixedDimensions }
            for term in terms {
                if term.excluded, ![.text, .tag].contains(term.atom.dimension) { return .unsupportedExclusion }
                switch term.atom {
                case .date(let interval), .created(let interval):
                    if let issue = invalidInterval(interval, dates: dates) { return issue }
                case .reminder(let minutes): if !(0..<1440).contains(minutes) { return .invalidCondition }
                default: break
                }
            }
        case .page(let predicate):
            switch predicate {
            case .boardDate(let scope, let rule):
                guard scope != .all else { return .invalidCondition }
                return invalidInterval(.init(lowerBound: rule.todayKey, upperBound: rule.todayKey),
                                       dates: .init(todayKey: rule.todayKey, calendar: rule.calendar))
            case .reminderPresence(.all), .itemKind(.all), .todoStatus(.all), .routineStatus(.all): return .invalidCondition
            case .contentTypes(let types):
                if types.isEmpty || !types.isSubset(of: [.todo, .routine, .subtask]) { return .invalidCondition }
            default: break
            }
        }
        return nil
    }

    private static func invalidInterval(
        _ interval: ContentQueryDateInterval, dates: ContentQueryDateContext
    ) -> ContentQueryIssue? {
        guard CommandArgumentValidation.isCanonicalDay(interval.lowerBound),
              CommandArgumentValidation.isCanonicalDay(interval.upperBound) else { return .invalidDate }
        switch ContentQueryDates.parse(interval.lowerBound + ".." + interval.upperBound, context: dates) {
        case .success: return nil
        case .failure(let failure): return failure.issue
        }
    }

    private static func pageConflicts(_ conditions: [ContentQueryCondition]) -> [ContentQueryConditionDiagnostic] {
        var result: [ContentQueryConditionDiagnostic] = []
        // 普通文字的布尔检查已有分析上限；页面补充检查不再两两遍历所有文字项。
        for left in conditions {
            guard case .page = left.value else { continue }
            for right in conditions where left.id != right.id {
                if case .page = right.value, right.id.rawValue < left.id.rawValue { continue }
                if conflicts(left.value, right.value) {
                    let ids = [left.id, right.id].sorted { $0.rawValue < $1.rawValue }
                    result.append(.init(issue: .unsatisfiable, conditionIDs: ids))
                }
            }
        }
        return result
    }

    private static func conflicts(_ lhs: ContentQueryConditionValue, _ rhs: ContentQueryConditionValue) -> Bool {
        if case .page(.noTags) = lhs { return requiresTag(rhs) }
        if case .page(.noTags) = rhs { return requiresTag(lhs) }
        if case .page(.reminderPresence(.unset)) = lhs { return requiresReminder(rhs) }
        if case .page(.reminderPresence(.unset)) = rhs { return requiresReminder(lhs) }
        if pendingDate(lhs), requiresDone(rhs) { return true }
        if pendingDate(rhs), requiresDone(lhs) { return true }
        if case .page(.sourceApplication(let left)) = lhs, case .page(.sourceApplication(let right)) = rhs { return left != right }
        return false
    }

    private static func pendingDate(_ value: ContentQueryConditionValue) -> Bool {
        if case .page(.boardDate(let scope, _)) = value { return [.overdue, .upcoming].contains(scope) }
        return false
    }

    private static func requiresDone(_ value: ContentQueryConditionValue) -> Bool {
        if case .clause(let terms) = value { return !terms.isEmpty && terms.allSatisfy { $0.atom == .status(.done) } }
        return false
    }

    private static func requiresTag(_ value: ContentQueryConditionValue) -> Bool {
        if case .page(.tagID) = value { return true }
        if case .clause(let terms) = value { return !terms.isEmpty && terms.allSatisfy { $0.atom.dimension == .tag && !$0.excluded } }
        return false
    }

    private static func requiresReminder(_ value: ContentQueryConditionValue) -> Bool {
        if case .page(.reminderPresence(.set)) = value { return true }
        if case .clause(let terms) = value { return terms.first?.atom.dimension == .reminder }
        return false
    }
}
