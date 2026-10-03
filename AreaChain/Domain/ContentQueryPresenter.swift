import Foundation

enum ContentQueryPresenter {
    /// 只接受同一排序响应，不允许另传查询、快照、提供者或解密能力。
    static func project(_ sorted: ContentQuerySortedResponse, budget: ContentQueryPresentationBudget,
                        locale: Locale) -> ContentQueryPresentationResponse {
        let matches = Dictionary(grouping: sorted.source.matches, by: \.id)
        let orders = Dictionary(grouping: sorted.ordered, by: \.id)
        let rows = sorted.ordered.map { ranked -> ContentQueryPresentationRow in
            guard budget.isValid else { return invalid(ranked.id, .invalidBudget) }
            guard orders[ranked.id]?.count == 1 else { return invalid(ranked.id, .duplicateOrderIdentity) }
            guard let candidates = matches[ranked.id] else { return invalid(ranked.id, .missingIdentity) }
            guard candidates.count == 1 else { return invalid(ranked.id, .ambiguousIdentity) }
            return row(candidates[0], context: sorted.source.sortContext, budget: budget, locale: locale)
        }
        let diagnostics: [ContentQueryPresentationDiagnostic] = matches.keys.contains { orders[$0] == nil }
            ? [.init(issue: .unorderedSourceIdentity)] : []
        return .init(source: sorted, locale: locale, rows: rows, diagnostics: diagnostics)
    }

    private static func invalid(_ id: CommandObjectReference, _ issue: ContentQueryPresentationIssue) -> ContentQueryPresentationRow {
        .init(id: id, diagnostics: [.init(issue: issue)])
    }

    private static func row(_ match: ContentQueryBatchMatch, context: ContentQuerySortContext,
                            budget: ContentQueryPresentationBudget, locale: Locale) -> ContentQueryPresentationRow {
        let fields = ContentQuerySortFields(match)
        let evidence = ContentQueryPresentationEvidence(fields: fields, match: match, context: context, budget: budget, locale: locale)
        var row = ContentQueryPresentationRow(id: match.id, reasons: evidence.reasons, diagnostics: evidence.diagnostics)
        ContentQueryPresentationDetails.apply(match, to: &row)
        guard !fields.protectedText else { return row }
        if let name = fields.fields.first(where: { ContentQuerySortFields.isName($0.0) }) {
            row.primary = display(name, evidence: evidence, budget: budget, row: &row)
        }
        if let body = fields.fields.first(where: { [.notes, .diaryBody, .clipboardPlainText].contains($0.0) }) {
            let hits = evidence.hits.filter { $0.0 == body.0 }
            let explicit = context.explicitMode != nil
            let hasQueryText = context.hasPositiveText || (explicit && context.hasExplicitText)
            let prefixAllowed = body.0 != .notes && (!hasQueryText || explicit)
            if !hits.isEmpty || prefixAllowed {
                row.summary = display(body, evidence: evidence, budget: budget, row: &row)
            } else if hasQueryText && body.0 != .notes {
                row.diagnostics.append(.init(issue: evidence.reasons.contains { $0.kind == .positive }
                    ? .metadataOnlySummaryOmitted : .noPublicTextEvidence))
            }
            if row.summary == nil && !body.1.isEmpty { row.omittedPublicContent = true }
        }
        return row
    }

    private static func display(_ field: (ContentQueryMatchField, String), evidence: ContentQueryPresentationEvidence,
                                budget: ContentQueryPresentationBudget,
                                row: inout ContentQueryPresentationRow) -> ContentQueryDisplayText? {
        let value = ContentQuerySnippet.make(text: field.1, field: field.0,
            hits: evidence.hits.filter { $0.0 == field.0 }.map(\.1), budget: budget, diagnostics: &row.diagnostics)
        let omitted = value?.omittedPublicContent ?? !field.1.isEmpty
        if omitted {
            row.omittedPublicContent = true
            row.expansion.append(.init(object: row.id, field: field.0))
        }
        return value
    }
}
