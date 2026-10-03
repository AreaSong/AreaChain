import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ContentQueryReadSessionInteractionTests {
    @Test func focusLossKeepsQueryAndRequiresExplicitNewRead() async throws {
        let f = try SearchReadFixture()
        try await f.unlock()
        try await f.publish()
        let query = try f.query
        let generation = f.vault.generation
        let revision = f.vault.revision
        let keys = await f.system.items
        f.focus.post(name: SearchReadFixture.focusLost, object: f.focusObject)
        #expect(f.session.isMasked && !f.session.hasRetainedPresentation)
        #expect(try f.query == query)
        #expect(f.vault.generation == generation && f.vault.revision == revision && f.vault.isUnlocked)
        #expect(!f.vault.isAuthenticating)
        #expect(await f.system.items == keys)
        #expect(throws: ContentQueryReadSessionError.masked) { try f.session.prepare(read: f.batch) }
        try f.session.resumeDisplay(expecting: f.lease)
        #expect(!f.session.hasPublicationPermit)
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
        try await f.publish()
        NotificationCenter.default.post(name: .privacyMask, object: f.vault)
        #expect(f.session.isMasked && f.owner.source == nil)
        #expect(try f.query == query)
    }

    @Test func stalePaginationBrowseAndOpenIntentAreRejected() async throws {
        let f = try SearchReadFixture()
        f.data.diary()
        try await f.publish()
        let publication = try f.session.presentation()
        let page = ContentQueryPaginationEvent(stamp: publication.pagination.stamp, action: .loadMoreUnits)
        let version = publication.pagination.snapshot.version
        _ = try f.session.browse(.init(version: version, action: .move(.next, inputEditing: false)))
        #expect(try f.session.browse(.init(version: version, action: .open(inputEditing: false))).open == nil)
        f.vault.lock()
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.consumeOpenIntent() }
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.loadMore(page) }
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.browse(.init(version: version, action: .selectVisible)) }
        await f.settle()
        try f.handoff.send(.query(.enterPage(QuerySessionFixture.page(.diaries(tagID: nil), host: HandoffFixture.source))))
        try await f.publish()
        #expect(try f.session.loadMore(page).rejection != nil)
        #expect(try f.session.browse(.init(version: version, action: .selectVisible)).rejection == .staleVersion)
        #expect(throws: ContentQueryReadSessionError.noOpenIntent) { try f.session.consumeOpenIntent() }
    }

    @Test func validOpenCanOnlyBeConsumedOnceAndDoesNotAuthorizeBusinessAction() async throws {
        let f = try SearchReadFixture()
        try await f.publish()
        let version = try f.session.presentation().pagination.snapshot.version
        _ = try f.session.browse(.init(version: version, action: .move(.next, inputEditing: false)))
        _ = try f.session.browse(.init(version: version, action: .open(inputEditing: false)))
        #expect(try f.session.consumeOpenIntent().requiresFreshBusinessValidation)
        #expect(throws: ContentQueryReadSessionError.noOpenIntent) { try f.session.consumeOpenIntent() }
    }

    @Test func ordinaryCancelRetainsResultsWherePrivacyInvalidationDoesNot() async throws {
        let f = try SearchReadFixture()
        try await f.publish()
        let before = try f.session.presentation().task
        let next = try f.session.prepare(read: f.batch)
        try f.session.evaluate(next)
        try f.session.cancel(next)
        #expect(try f.session.presentation().task == before)
        #expect(f.owner.outcome == .publicationCancelled)
        await #expect(throws: ContentQueryReadSessionError.staleTask) { try await f.session.publish(next) }
        f.vault.lock()
        #expect(f.owner.outcome == .sourceInvalidated)
        try f.expectEmpty()
    }

    @Test func explicitUnsavedChangesAndContextlessSavedNotificationInvalidateSource() async throws {
        let f = try SearchReadFixture()
        let diary = f.data.diary()
        try await f.publish()
        let query = try f.query
        diary.dayKey = "2026-01-01"
        // reader 不假装观察未保存实体；真实宿主必须发出显式失效。
        #expect(f.session.hasPublicationPermit)
        try f.session.modelDidChange(expecting: f.lease.ownership)
        #expect(f.owner.source == nil && !f.session.hasRetainedPresentation)
        #expect(try f.query == query)
        try await f.publish()
        f.model.post(name: .boardDidChange, object: nil)
        #expect(f.owner.source == nil && !f.session.hasRetainedPresentation)
        #expect(f.data.context.hasChanges)
    }

    @Test func hostLeaseChangeRejectsOldTaskAndOldCompletionEvent() async throws {
        let f = try SearchReadFixture()
        let old = try f.lease
        let handle = try f.session.prepare(read: f.batch)
        try f.session.evaluate(handle)
        try f.handoff.send(.query(.setInput("/diaries synthetic-new")))
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
        #expect(throws: ContentQueryReadSessionError.staleHost) {
            try f.session.setCompletionBuffer("Synthetic stale", expecting: old)
        }
        #expect(f.owner.source == nil)
    }

    @Test func preparationReentryCannotStampAnOlderReadAsCurrent() throws {
        let f = try SearchReadFixture()
        var newer: ContentQueryReadHandle?
        #expect(throws: ContentQueryReadSessionError.staleTask) {
            try f.session.prepare { query in
                newer = try f.session.prepare(read: f.batch)
                return f.batch(query)
            }
        }
        try f.session.evaluate(#require(newer))
    }

    @Test func budgetContinuationUsesTheSameGateAndRejectsLateWork() async throws {
        let f = try SearchReadFixture()
        var template = QueryReadFixture.batch(results: 1)
        template.snapshots.diaries = .notProvided
        try f.handoff.send(.query(.setInput("date:2026-10-01..2026-10-10")))
        try f.handoff.send(.query(.addCondition(.scope(.routineOccurrences))))
        let first = try f.session.prepare { query in
            .init(requestID: UUID(), session: query, snapshots: template.snapshots,
                  facts: template.facts, options: template.options)
        }
        try f.session.evaluate(first)
        try await f.session.publish(first)
        var budget = template.options.occurrenceBudget
        budget.maxResults = 10
        let next = try f.session.continueReading(budget: budget)
        try f.session.evaluate(next)
        f.vault.lock()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(next) }
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.continueReading(budget: budget) }
        try f.expectEmpty()
    }
}
