import Foundation
import Testing
@testable import AreaChain

enum QueryReadFixture {
    static func batch(results: Int = 2) -> ContentQueryBatch {
        var batch = QueryBatchFixture.occurrences("date:2026-10-01..2026-10-10")
        batch.options.occurrenceBudget.maxResults = results
        return batch
    }

    static func owner(_ batch: ContentQueryBatch = batch(), pageSize: Int = 1) throws -> ContentQueryReadOwner {
        let owner = try ContentQueryReadOwner(paginationPolicy: .init(units: pageSize, members: pageSize, contexts: pageSize))
        let initial = try owner.begin(batch)
        #expect(owner.published == nil && owner.phase == .prepared)
        let ticket = try owner.evaluate(initial)
        #expect(owner.published == nil && owner.phase == .awaitingPublication)
        #expect(try owner.publish(ticket).outcome == .published)
        return owner
    }

    static func budget(_ owner: ContentQueryReadOwner, results: Int) -> RoutineOccurrenceQueryBudget {
        var budget = owner.attemptedBudget!
        budget.maxResults = results
        return budget
    }

    @discardableResult
    static func browse(_ owner: ContentQueryReadOwner, _ action: ContentQueryBrowseAction) -> ContentQueryBrowseEffect {
        owner.applyBrowse(.init(version: owner.published!.pagination.snapshot.version, action: action))
    }

    static func load(_ owner: ContentQueryReadOwner) -> ContentQueryPaginationEvent {
        .init(stamp: owner.published!.pagination.stamp, action: .loadMoreUnits)
    }

    static func complete(_ owner: ContentQueryReadOwner, results: Int = 10) throws -> ContentQueryReadEffect {
        let task = try owner.continueReading(source: owner.source!, budget: budget(owner, results: results))
        return try owner.publish(owner.evaluate(task))
    }
}
