import Foundation

struct ContentQueryPresentationEvidence {
    var hits: [(ContentQueryMatchField, ContentQuerySnippetHit)] = []
    var reasons: [ContentQueryPresentationReason] = []
    var diagnostics: [ContentQueryPresentationDiagnostic] = []

    init(fields: ContentQuerySortFields, match: ContentQueryBatchMatch, context: ContentQuerySortContext,
         budget: ContentQueryPresentationBudget, locale: Locale) {
        var uniqueTerms: [[ContentQuerySemanticTerm]] = []
        var indexed: [(ContentQueryMatchField, CommandObjectReference?, NSString)] = []
        if fields.evidence.count > budget.maxEvidence { diagnostics.append(.init(issue: .evidenceLimit)) }
        for item in fields.evidence.prefix(budget.maxEvidence) {
            guard let condition = context.presentationConditions[item.conditionID]?.value else {
                diagnostics.append(.init(issue: .invalidCondition)); continue
            }
            let clause = textClause(item.conditionID, condition)
            // 隐藏分支对任何正文/文字依据均无展示能力，诊断也不泄露是否曾有正文依据。
            if fields.protectedText && (clause != nil || item.field == .diaryBody) { continue }
            if let clause {
                if !uniqueTerms.contains(clause.terms) { uniqueTerms.append(clause.terms) }
                let original = indexed.first { $0.0 == item.field && $0.1 == item.relatedObject }?.2
                    ?? fields.text(for: item).map { $0 as NSString }
                if let original, !indexed.contains(where: { $0.0 == item.field && $0.1 == item.relatedObject }) {
                    indexed.append((item.field, item.relatedObject, original))
                }
                text(item, clause: clause, fields: fields, locale: locale,
                     weight: uniqueTerms.firstIndex(of: clause.terms) ?? 0, indexed: original)
            } else if let issue = ContentQueryPresentationEvidenceRules.issue(item, condition: condition, match: match) {
                diagnostics.append(.init(issue: issue))
            } else {
                appendReason(item)
            }
        }
        if context.explicitMode != nil { mode(match, context: context, budget: budget) }
    }

    private func textClause(_ id: ContentQueryConditionID,
                            _ value: ContentQueryConditionValue) -> ContentQuerySortContext.Clause? {
        guard case .clause(let terms) = value, terms.allSatisfy({ $0.atom.dimension == .text }) else { return nil }
        return .init(id: id, terms: terms)
    }

    private mutating func text(_ item: ContentQueryMatchEvidence, clause: ContentQuerySortContext.Clause,
                              fields: ContentQuerySortFields, locale: Locale, weight: Int, indexed: NSString?) {
        guard let index = item.alternativeIndex, clause.terms.indices.contains(index) else {
            diagnostics.append(.init(issue: .invalidBranch)); return
        }
        if clause.terms[index].excluded || item.kind != .positive { return }
        if item.relatedObject?.dayKey != nil {
            diagnostics.append(.init(issue: .invalidRelation)); return
        }
        guard let string = indexed, fields.text(for: item) != nil else {
            diagnostics.append(.init(issue: item.ownerObject == nil ? .invalidField : .invalidRelation)); return
        }
        guard fields.positiveText(item, clause: clause, indexedText: string) != nil, let range = item.range else {
            diagnostics.append(.init(issue: .invalidRange)); return
        }
        // 只在已知范围内核验字面内容；提供者可能把单个标量命中扩到整个字素。
        guard case .text(let needle, _) = clause.terms[index].atom else { return }
        let verified = string.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                                    range: range, locale: locale)
        let complete = string.rangeOfComposedCharacterSequences(for: range)
        guard verified.location != NSNotFound,
              string.rangeOfComposedCharacterSequences(for: verified) == complete else {
            diagnostics.append(.init(issue: .staleEvidence)); return
        }
        let hit = ContentQuerySnippetHit(range: complete, source: .condition(item.conditionID, alternative: index), weight: weight)
        if !hits.contains(where: { $0.0 == item.field && $0.1.range == complete && $0.1.source == hit.source }) {
            hits.append((item.field, hit))
        }
        appendReason(item)
    }

    private mutating func appendReason(_ item: ContentQueryMatchEvidence) {
        let reason = ContentQueryPresentationReason(conditionID: item.conditionID, alternativeIndex: item.alternativeIndex,
            field: item.field, kind: item.kind, relatedObject: item.relatedObject, ownerObject: item.ownerObject)
        if !reasons.contains(reason) { reasons.append(reason) }
    }

    private mutating func mode(_ match: ContentQueryBatchMatch, context: ContentQuerySortContext,
                               budget: ContentQueryPresentationBudget) {
        guard let mode = context.explicitMode, case .clipboard(let value) = match,
              value.mode == .legacy(mode) else {
            diagnostics.append(.init(issue: .explicitModeMismatch)); return
        }
        guard context.hasExplicitText else { return }
        guard let evidence = value.modeEvidence, evidence.mode == mode, evidence.field == .clipboardPlainText else {
            if context.hasExplicitText { diagnostics.append(.init(issue: .noLegalModeRange)) }
            return
        }
        if evidence.ranges.count > budget.maxEvidence { diagnostics.append(.init(issue: .evidenceLimit)) }
        let original = value.plainText as NSString
        for range in evidence.ranges.prefix(budget.maxEvidence) {
            if range.length == 0 {
                let validZero = mode == .regex && range.location >= 0 && range.location <= original.length
                diagnostics.append(.init(issue: validZero ? .zeroLengthModeMatch : .invalidRange)); continue
            }
            guard ContentQuerySortFields.valid(range, in: original) else {
                diagnostics.append(.init(issue: .invalidRange)); continue
            }
            let complete = original.rangeOfComposedCharacterSequences(for: range)
            if !hits.contains(where: { $0.0 == .clipboardPlainText && $0.1.range == complete }) {
                hits.append((.clipboardPlainText, .init(range: complete, source: .clipboardMode(mode), weight: 0)))
            }
        }
        if hits.isEmpty && context.hasExplicitText { diagnostics.append(.init(issue: .noLegalModeRange)) }
    }
}
