import Foundation

/// on 是唯一执行日选择，不是 date 窗口的别名；错误选择不能降格为未选择或取最后值。
enum ContentQueryOccurrenceDay: Equatable {
    case unspecified
    case selected(String)
    case invalid(ContentQueryIssue)

    var dayKey: String? {
        if case .selected(let day) = self { return day }
        return nil
    }

    static func resolve(
        _ conditions: [ContentQueryCondition], explicitDay: String? = nil
    ) -> Self {
        resolve(conditions.compactMap {
            if case .clause(let terms) = $0.value { return terms }
            return nil
        }, explicitDay: explicitDay)
    }

    static func resolve(
        _ clauses: [[ContentQuerySemanticTerm]], explicitDay: String? = nil
    ) -> Self {
        var days: Set<String> = []
        for terms in clauses {
            if let issue = groupIssue(terms) { return .invalid(issue) }
            for term in terms {
                guard case .on(let day) = term.atom else { continue }
                guard !term.excluded else { return .invalid(.unsupportedExclusion) }
                guard CommandArgumentValidation.isCanonicalDay(day) else { return .invalid(.invalidDate) }
                days.insert(day)
            }
        }
        if let explicitDay {
            guard CommandArgumentValidation.isCanonicalDay(explicitDay) else { return .invalid(.invalidDate) }
            days.insert(explicitDay)
        }
        guard days.count <= 1 else { return .invalid(.conflictingOccurrenceDays) }
        return days.first.map(Self.selected) ?? .unspecified
    }

    static func groupIssue(_ terms: [ContentQuerySemanticTerm]) -> ContentQueryIssue? {
        let days = terms.compactMap { term -> String? in
            if case .on(let day) = term.atom { return day }
            return nil
        }
        guard !days.isEmpty else { return nil }
        if days.count != terms.count { return .mixedDimensions }
        return Set(days).count > 1 ? .multipleOccurrenceDaysInGroup : nil
    }
}
