import Foundation
@testable import AreaChain

enum QueryPresentationFixture {
    static let locale = Locale(identifier: "en_US")
    static let budget = ContentQueryPresentationBudget(maxUTF16: 40, contextUTF16: 4)

    static func project(_ batch: ContentQueryBatch, budget: ContentQueryPresentationBudget = budget) -> ContentQueryPresentationResponse {
        ContentQueryPresenter.project(QuerySortFixture.sort(batch), budget: budget, locale: locale)
    }

    static func todo(_ query: String, title: String, notes: String = "",
                     budget: ContentQueryPresentationBudget = budget) -> ContentQueryPresentationRow {
        project(QuerySortFixture.batch(query, titles: [(title, notes)]), budget: budget).rows[0]
    }

    static func replacing(_ sorted: ContentQuerySortedResponse, readings: [ContentQueryProviderRead]? = nil,
                          ordered: [ContentQueryRankedMatch]? = nil) -> ContentQuerySortedResponse {
        let before = sorted.source
        let response = ContentQueryBatchResponse(requestID: before.requestID, sortContext: before.sortContext,
            queryState: before.queryState, typeAnalysis: before.typeAnalysis, textDiagnostics: before.textDiagnostics,
            conditionDiagnostics: before.conditionDiagnostics, readings: readings ?? before.readings,
            completeness: before.completeness, consistencyIssues: before.consistencyIssues)
        return .init(source: response, requested: sorted.requested, applied: sorted.applied, fallback: sorted.fallback,
                     ordered: ordered ?? sorted.ordered)
    }

    static func corruptTodo(query: String = "alpha", title: String = "alpha",
                            _ change: ([ContentQueryMatchEvidence]) -> [ContentQueryMatchEvidence]) -> ContentQueryPresentationResponse {
        let sorted = QuerySortFixture.sort(QuerySortFixture.batch(query, titles: [(title, "alpha")]))
        guard case .todo(var read) = sorted.source.readings[0], let match = read.matches.first else { fatalError("合成夹具缺失") }
        read.matches = [.init(id: match.id, title: match.title, notes: match.notes, dayKey: match.dayKey,
            createdAt: match.createdAt, isDone: match.isDone, evidence: change(match.evidence))]
        return ContentQueryPresenter.project(replacing(sorted, readings: [.todo(read)]), budget: budget, locale: locale)
    }

    static func clipboard(_ needle: String, text: String, mode: ClipboardSearchMode) -> ContentQueryBatch {
        var batch = QueryBatchFixture.empty("/clipboard")
        batch.snapshots.clipboard = .complete([ClipboardQueryFixture.record(1, text)])
        batch.options.clipboardMode = .explicit(mode, needle: needle)
        return batch
    }

    static func highlighted(_ value: ContentQueryDisplayText?) -> [String] {
        guard let value else { return [] }
        return value.highlights.map { (value.text as NSString).substring(with: $0.range) }
    }
}
