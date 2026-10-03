import Foundation

enum ContentQueryRelevance {
    struct Rank {
        let tier: ContentQueryRelevanceTier
        let reason: ContentQueryRankReason
    }

    static func rank(_ match: ContentQueryBatchMatch, context: ContentQuerySortContext) -> Rank {
        if let mode = context.explicitMode {
            return .init(tier: .otherFields, reason: hasModeEvidence(match, mode: mode)
                ? .explicitModeEvidence : .noPublicTextEvidence)
        }
        let fields = ContentQuerySortFields(match)
        if fields.protectedText { return .init(tier: .otherFields, reason: .protectedText) }
        if fields.evidence.contains(where: { !context.conditionIDs.contains($0.conditionID) }) {
            return .init(tier: .otherFields, reason: .invalidEvidence)
        }
        let clauses = context.clauses.filter { $0.terms.contains { !$0.excluded } }
        let evaluated = clauses.map { clause in Self.coverage(clause, fields: fields) }
        if evaluated.contains(where: \.invalid) { return .init(tier: .otherFields, reason: .invalidEvidence) }
        // OR 仅靠排除分支满足时，该组没有实际正向文字贡献，不能额外要求替代词出现。
        let coverage = evaluated.filter { $0.hasPositive || !$0.hasAbsence }
        guard !coverage.isEmpty, coverage.allSatisfy(\.hasPositive) else {
            return .init(tier: .otherFields, reason: .noPublicTextEvidence)
        }
        if coverage.allSatisfy(\.hasName) {
            let unique = clauses.reduce(into: [[ContentQuerySemanticTerm]]()) {
                if !$0.contains($1.terms) { $0.append($1.terms) }
            }
            let exact = unique.count == 1 && unique[0].count == 1 && coverage.allSatisfy(\.hasExactName)
            return .init(tier: exact ? .exactName : .allName, reason: .publicEvidence)
        }
        return .init(tier: coverage.contains(where: \.hasName) ? .mixedFields : .otherFields, reason: .publicEvidence)
    }

    private struct Coverage {
        var hasAbsence = false
        var hasPositive = false
        var hasName = false
        var hasExactName = false
        var invalid = false
    }

    private static func coverage(_ clause: ContentQuerySortContext.Clause, fields: ContentQuerySortFields) -> Coverage {
        var result = Coverage()
        for evidence in fields.evidence where evidence.conditionID == clause.id {
            guard let index = evidence.alternativeIndex, clause.terms.indices.contains(index) else {
                result.invalid = true; continue
            }
            if evidence.kind == .absence, clause.terms[index].excluded,
               fields.allowsAbsence(evidence) {
                result.hasAbsence = true; continue
            }
            guard evidence.kind == .positive, !clause.terms[index].excluded,
                  case .text(let text, _) = clause.terms[index].atom,
                  let original = fields.positiveText(evidence, clause: clause), let range = evidence.range else {
                result.invalid = true; continue
            }
            result.hasPositive = true
            guard ContentQuerySortFields.isName(evidence.field) else { continue }
            result.hasName = true
            // 范围完整还不够：组合字符扩展后的范围可能大于真正的匹配文字。
            if range.location == 0, range.length == original.utf16.count,
               original.compare(text, options: [.caseInsensitive, .diacriticInsensitive],
                                locale: Locale(identifier: "en_US_POSIX")) == .orderedSame {
                result.hasExactName = true
            }
        }
        return result
    }

    static func hasModeEvidence(_ match: ContentQueryBatchMatch, mode: ClipboardSearchMode) -> Bool {
        guard mode != .regex, case .clipboard(let value) = match, value.mode == .legacy(mode),
              let evidence = value.modeEvidence, evidence.mode == mode, evidence.field == .clipboardPlainText,
              !evidence.ranges.isEmpty else { return false }
        return evidence.ranges.allSatisfy { ContentQuerySortFields.valid($0, in: value.plainText) }
    }
}
