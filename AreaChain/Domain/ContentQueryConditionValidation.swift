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
        let identities = Dictionary(grouping: conditions, by: \.id)
        result += identities.filter { $0.value.count > 1 }.map {
            .init(issue: .ambiguousConditionIDs, conditionIDs: [$0.key])
        }.sorted { $0.conditionIDs[0].rawValue < $1.conditionIDs[0].rawValue }
        if case .invalid(let issue) = ContentQueryOccurrenceDay.resolve(conditions) {
            result.append(.init(issue: issue, conditionIDs: conditions.filter {
                $0.value.dimension == .content(.on)
            }.map(\.id)))
        }
        return result
    }

    static func invalid(_ value: ContentQueryConditionValue, dates: ContentQueryDateContext) -> ContentQueryIssue? {
        switch value {
        case .scope: return nil
        case .clause(let terms):
            guard let first = terms.first else { return .incompleteCondition }
            guard terms.allSatisfy({ $0.atom.dimension == first.atom.dimension }) else { return .mixedDimensions }
            if let issue = ContentQueryOccurrenceDay.groupIssue(terms) { return issue }
            for term in terms {
                if term.excluded, ![.text, .tag].contains(term.atom.dimension) { return .unsupportedExclusion }
                switch term.atom {
                case .date(let interval), .created(let interval):
                    if let issue = invalidInterval(interval, dates: dates) { return issue }
                case .on(let day):
                    if let issue = invalidInterval(.init(lowerBound: day, upperBound: day), dates: dates) { return issue }
                case .reminder(let minutes): if !(0..<1440).contains(minutes) { return .invalidCondition }
                default: break
                }
            }
        case .page(let predicate):
            switch predicate {
            case .taskPriority(let priority):
                if priority.scope == .all && !priority.highPriorityOnly { return .invalidCondition }
            case .boardDate(let scope, let rule):
                guard scope != .all else { return .invalidCondition }
                return invalidInterval(.init(lowerBound: rule.todayKey, upperBound: rule.todayKey),
                                       dates: .init(todayKey: rule.todayKey, calendar: rule.calendar))
            case .reminderPresence(.all), .itemKind(.all), .todoStatus(.all), .routineStatus(.all): return .invalidCondition
            case .contentTypes(let types):
                if types.isEmpty || !types.isSubset(of: [.todo, .routine, .subtask, .diary, .image, .tag]) { return .invalidCondition }
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

}
