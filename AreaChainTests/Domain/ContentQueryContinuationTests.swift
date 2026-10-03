import Foundation
import Testing
@testable import AreaChain

struct ContentQueryContinuationTests {
    @Test func loadMoreDoesNotReadAndContinuationDoesNotRequireLastPage() throws {
        let owner = try QueryReadFixture.owner()
        let first = owner.published!
        let task = try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 3))
        #expect(first.pagination.status.hasMoreUnits)
        #expect(task.method == .sameSnapshotReevaluation)
        let request = owner.request
        let budget = owner.attemptedBudget
        #expect(owner.loadMore(QueryReadFixture.load(owner)).didPublish)
        #expect(owner.request == request && owner.phase == .prepared && owner.attemptedBudget == budget)
        #expect(owner.published!.pagination.snapshot.sharesSource(with: first.pagination.snapshot))
        #expect(owner.published!.response.definiteMatchCount == 2)
        #expect(owner.loadMore(QueryReadFixture.load(owner)).rejection == .exhausted)
        try owner.cancel(task)
    }

    @Test func completeHistoryConflictMissingSourceAndUnsupportedFieldCannotContinue() throws {
        var history = QueryReadFixture.batch()
        history.facts.routine.scheduleEvidence = []
        var conflict = QueryBatchFixture.occurrences()
        conflict.facts.routine.checks = [RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id),
            RoutineQueryFixture.check(.skipped, id: QueryBatchFixture.id)]
        var missing = QueryReadFixture.batch()
        missing.snapshots.routines = .notProvided
        let unsupported = QueryBatchFixture.occurrences("date:today title:needle")
        for batch in [history, conflict, missing, unsupported, QueryReadFixture.batch(results: 20), QueryBatchFixture.trash()] {
            let owner = try QueryReadFixture.owner(batch)
            #expect(throws: ContentQueryReadError.noBudgetRemainder) {
                try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 30))
            }
            #expect(owner.request == nil)
        }
    }

    @Test func inputWorkAndUnattributedResultRemaindersAreEligible() throws {
        var input = QueryReadFixture.batch()
        input.options.occurrenceBudget.maxInputItems = 0
        var work = QueryReadFixture.batch()
        work.options.occurrenceBudget.maxWork = 0
        var unattributed = QueryReadFixture.batch(results: 0)
        unattributed.snapshots.routines = .complete([])
        unattributed.facts.routine.checks = [RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id)]
        for (batch, dimension) in [(input, ContentQueryBudgetDimension.input), (work, .work), (unattributed, .results)] {
            let owner = try QueryReadFixture.owner(batch)
            #expect(ContentQueryContinuationRemainder(owner.published!.response).dimensions == [dimension])
            let task = try owner.continueReading(source: owner.source!, budget: .init())
            #expect(try owner.publish(owner.evaluate(task)).outcome == .published)
            #expect(ContentQueryContinuationRemainder(owner.published!.response).dimensions.isEmpty)
        }
    }

    @Test func rejectsInvalidUnchangedReducedIrrelevantAndOverflowBudgets() throws {
        let owner = try QueryReadFixture.owner()
        let old = owner.attemptedBudget!
        var negative = old
        negative.maxResults = -1
        var irrelevant = old
        irrelevant.maxWork += 1
        var reduced = old
        reduced.maxWork -= 1
        reduced.maxResults += 1
        for (budget, error) in [(negative, ContentQueryReadError.invalidBudget), (old, .budgetNotIncreased),
            (reduced, .budgetNotIncreased), (irrelevant, .budgetCannotAdvance),
            (QueryReadFixture.budget(owner, results: Int.max), .budgetExceeded)] {
            #expect(throws: error) { try owner.continueReading(source: owner.source!, budget: budget) }
        }
        #expect(owner.request == nil && owner.attemptedBudget == old)
        #expect(throws: ContentQueryReadError.invalidConfiguration) {
            try ContentQueryReadOwner(policy: .init(maximum: .init(maxInputItems: Int.max)))
        }
    }

    @Test func configuredCeilingStopsWithoutAutomaticGrowth() throws {
        let owner = try ContentQueryReadOwner(policy: .init(maximum: .init(maxResults: 3)))
        try owner.publish(owner.evaluate(owner.begin(QueryReadFixture.batch())))
        #expect(try QueryReadFixture.complete(owner, results: 3).outcome == .published)
        #expect(throws: ContentQueryReadError.atBudgetLimit) {
            try owner.continueReading(source: owner.source!, budget: owner.attemptedBudget!)
        }
        #expect(throws: ContentQueryReadError.budgetExceeded) {
            try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 4))
        }
        #expect(owner.phase == .idle && owner.published!.response.definiteMatchCount == 3)
    }

    @Test func largerInputOrWorkWithoutProcessedRangeIsNoProgress() throws {
        for dimension in [ContentQueryBudgetDimension.input, .work] {
            var batch = QueryReadFixture.batch()
            if dimension == .input { batch.options.occurrenceBudget.maxInputItems = 0 }
            else { batch.options.occurrenceBudget.maxWork = 0 }
            let owner = try QueryReadFixture.owner(batch)
            let before = owner.published!.pagination.stamp
            var budget = owner.attemptedBudget!
            if dimension == .input { budget.maxInputItems = 1 } else { budget.maxWork = 11 }
            let task = try owner.continueReading(source: owner.source!, budget: budget)
            #expect(try owner.publish(owner.evaluate(task)).outcome == .noProgress)
            #expect(owner.published!.pagination.stamp == before)
            #expect(owner.request == nil && owner.phase == .idle && owner.attemptedBudget == budget)
            #expect(throws: ContentQueryReadError.budgetNotIncreased) {
                try owner.continueReading(source: owner.source!, budget: budget)
            }
        }
    }

    @Test func noProgressUpdatesBudgetCauseWithoutPublishingCandidate() throws {
        var batch = QueryReadFixture.batch(results: 0)
        batch.snapshots.routines = .complete([])
        batch.facts.routine.checks = [RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id)]
        batch.options.occurrenceBudget.maxWork = 0
        let owner = try QueryReadFixture.owner(batch)
        let before = owner.published!.pagination.stamp
        #expect(owner.continuationRemainder?.dimensions == [.work])
        var budget = owner.attemptedBudget!
        budget.maxWork = 2
        let task = try owner.continueReading(source: owner.source!, budget: budget)
        #expect(try owner.publish(owner.evaluate(task)).outcome == .noProgress)
        #expect(owner.published!.pagination.stamp == before)
        #expect(owner.continuationRemainder?.dimensions == [.results])
        budget.maxResults = 1
        let next = try owner.continueReading(source: owner.source!, budget: budget)
        #expect(try owner.publish(owner.evaluate(next)).outcome == .published)
        #expect(owner.continuationRemainder?.dimensions.isEmpty == true)
        #expect(owner.published!.response.occurrenceReading?.reviewRecords.count == 1)
    }
}
