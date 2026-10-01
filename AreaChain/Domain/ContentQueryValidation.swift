import Foundation

/// 解析阶段保留范围/重复诊断；共享可满足性算法由按类型绑定的分析调用，不读取记录。
enum ContentQueryValidation {
    static func diagnostics(_ query: ContentQuery) -> [ContentQueryDiagnostic] {
        var result = scopeDiagnostics(query.scopes)
        for dimension in ContentQueryDimension.allCases {
            let clauses = query.clauses.filter { $0.alternatives.first?.atom.dimension == dimension }
            guard !clauses.isEmpty else { continue }
            result += duplicates(clauses)

        }
        return result
    }

    /// 文本与页面组合共用同一矛盾算法；nil 表示分析超限，不能当作可满足。
    static func satisfiable(_ clauses: [[ContentQuerySemanticTerm]], dimension: ContentQueryDimension) -> Bool? {
        switch dimension {
        case .text, .tag:
            var budget = 4096
            return clauses.flatMap { $0 }.count > 128 ? nil : booleanSatisfiable(clauses, budget: &budget)
        case .date, .created: return dateSatisfiable(clauses)
        default: return scalarSatisfiable(clauses)
        }
    }

    private static func scopeDiagnostics(_ scopes: [ContentQueryScopeToken]) -> [ContentQueryDiagnostic] {
        guard let first = scopes.first else { return [] }
        // 范围只有一个选择槽；不同范围不擅自并集或借 trash 扩大可见性。
        return scopes.dropFirst().map {
            .init(issue: $0.scope == first.scope ? .duplicateCondition : .incompatibleScopes,
                  range: $0.range, relatedRanges: [first.range])
        }
    }

    private static func duplicates(_ clauses: [ContentQueryClause]) -> [ContentQueryDiagnostic] {
        var seen: [ContentQueryTerm] = []
        var result: [ContentQueryDiagnostic] = []
        for clause in clauses {
            for term in clause.alternatives {
                if let previous = seen.first(where: { same($0, term) }) {
                    result.append(.init(issue: .duplicateCondition, range: term.range, relatedRanges: [previous.range]))
                }
                seen.append(term)
            }
        }
        return result
    }

    private static func same(_ lhs: ContentQueryTerm, _ rhs: ContentQueryTerm) -> Bool {
        sameAtom(lhs.atom, rhs.atom) && lhs.excluded == rhs.excluded
    }

    private static func same(_ lhs: ContentQuerySemanticTerm, _ rhs: ContentQuerySemanticTerm) -> Bool {
        sameAtom(lhs.atom, rhs.atom) && lhs.excluded == rhs.excluded
    }

    private static func sameAtom(_ lhs: ContentQueryAtom, _ rhs: ContentQueryAtom) -> Bool {
        if case .text(let left, _) = lhs, case .text(let right, _) = rhs { return left == right }
        return lhs == rhs
    }

    private static func scalarSatisfiable(_ clauses: [[ContentQuerySemanticTerm]]) -> Bool {
        guard let first = clauses.first else { return true }
        return first.contains { candidate in
            clauses.allSatisfy { $0.contains { $0.atom == candidate.atom } }
        }
    }

    private static func interval(_ term: ContentQuerySemanticTerm) -> ContentQueryDateInterval? {
        switch term.atom {
        case .date(let interval), .created(let interval): interval
        default: nil
        }
    }

    private static func dateSatisfiable(_ clauses: [[ContentQuerySemanticTerm]]) -> Bool {
        // 可满足交集必含某个区间下界；不扫描年份跨度，也不展开日键。
        let candidates = Set(clauses.flatMap { $0 }.compactMap { interval($0)?.lowerBound })
        return candidates.contains { day in
            clauses.allSatisfy { clause in
                clause.contains {
                    guard let range = interval($0) else { return false }
                    return range.lowerBound <= day && day <= range.upperBound
                }
            }
        }
    }

    private static func booleanSatisfiable(_ clauses: [[ContentQuerySemanticTerm]], budget: inout Int) -> Bool? {
        budget -= 1
        guard budget >= 0 else { return nil }
        guard !clauses.contains(where: \.isEmpty) else { return false }
        guard let shortest = clauses.min(by: { $0.count < $1.count }), let term = shortest.first else { return true }
        let positive = reduced(clauses, assuming: term)
        if let answer = booleanSatisfiable(positive, budget: &budget) {
            if answer { return true }
        } else { return nil }
        if shortest.count == 1 { return false }
        let inverse = ContentQuerySemanticTerm(atom: term.atom, excluded: !term.excluded)
        return booleanSatisfiable(reduced(clauses, assuming: inverse), budget: &budget)
    }

    private static func reduced(
        _ clauses: [[ContentQuerySemanticTerm]], assuming term: ContentQuerySemanticTerm
    ) -> [[ContentQuerySemanticTerm]] {
        clauses.compactMap { clause in
            if clause.contains(where: { same($0, term) }) { return nil }
            return clause.filter { !sameAtom($0.atom, term.atom) }
        }
    }
}
