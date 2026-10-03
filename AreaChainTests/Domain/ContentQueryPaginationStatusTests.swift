import Foundation
import Testing
@testable import AreaChain

struct ContentQueryPaginationStatusTests {
    @Test func knownUndisplayedAndProviderBudgetRemainderStayIndependentAtLastPage() throws {
        var batch = QueryBatchFixture.occurrences("date:2026-10-01..2026-10-10")
        batch.options.occurrenceBudget.maxResults = 2
        let source = QueryDisplayFixture.display(batch)
        var state = try ContentQueryPaginationState(snapshot: source, policy: .init(units: 1))
        #expect(state.status.hits == .init(displayed: 1, known: 2))
        #expect(state.status.hasProviderUnprocessedWork && state.status.hasMoreToLoad)
        #expect(!state.status.completeness.matchingIsComplete)
        #expect(state.apply(QueryPaginationFixture.event(state, .loadMoreUnits)).didPublish)
        #expect(state.status.hits == .init(displayed: 2, known: 2) && !state.status.hasMoreToLoad)
        #expect(state.status.hasProviderUnprocessedWork && !state.status.completeness.matchingIsComplete)
        #expect(!state.status.canDeclareCompleteNoMatch)
        #expect(state.status.completeness == source.source.source.source.completeness)
        #expect(state.snapshot.sharesSource(with: source))
        #expect(state.apply(QueryPaginationFixture.event(state, .loadMoreUnits)).rejection == .exhausted)
    }

    @Test func completeEmptyInputFailureAndHistoricalUnknownRemainDistinct() throws {
        let empty = try ContentQueryPaginationState(snapshot: QueryDisplayFixture.display(QueryBatchFixture.empty()))
        #expect(empty.status.canDeclareCompleteNoMatch && empty.status.completeness.matchingIsComplete)
        #expect(!empty.status.hasProviderUnprocessedWork && !empty.status.hasMoreToLoad)
        let missing = try ContentQueryPaginationState(snapshot: QueryDisplayFixture.display(QueryBatchFixture.occurrences("")))
        #expect(!missing.status.canDeclareCompleteNoMatch && !missing.status.hasProviderUnprocessedWork)
        #expect(missing.status.completeness.providers.contains { $0.limitations.contains(.providerState(.requiresInput)) })
        var batch = QueryBatchFixture.occurrences()
        batch.facts.routine.scheduleEvidence = []
        batch.facts.routine.checks = [RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id)]
        var unknown = try ContentQueryPaginationState(snapshot: QueryDisplayFixture.display(batch))
        #expect(!unknown.status.hasProviderUnprocessedWork && !unknown.status.canDeclareCompleteNoMatch)
        #expect(unknown.status.completeness.providers.contains { $0.limitations.contains(.reviewRecords) })
        #expect(unknown.status.completeness.providers.contains { $0.limitations.contains(.historyCoverage) })
        _ = QueryPaginationFixture.browse(&unknown, .selectAllKnown)
        #expect(unknown.browse.selected.isEmpty && unknown.status.hits.known == 0)
    }

    @Test func protectedImagesNeverChangePublicPaginationCountsOrExposeControls() throws {
        var counts: [ContentQueryPaginationCount] = []
        var completeness: [ContentQueryBatchCompleteness] = []
        for number in [0, 1, 23] {
            var batch = QueryBatchFixture.trash()
            batch.snapshots.images = .complete((0..<number).map { _ in
                var image = TrashFixture.image(UUID())
                image.protection = .protected
                image.filename = "SYNTHETIC_HIDDEN_FILENAME"
                return image
            })
            let source = QueryDisplayFixture.display(batch)
            var state = try ContentQueryPaginationState(snapshot: source, policy: .init(units: 1, members: 1, contexts: 1))
            counts.append(state.status.hits)
            completeness.append(state.status.completeness)
            #expect(source.known.allSatisfy { $0.type != .image })
            #expect(source.units.flatMap(\.context).allSatisfy { $0.object.type != .image })
            #expect(state.status.completeness.providers.contains { $0.limitations.contains(.nonPublicCoverage) })
            _ = QueryPaginationFixture.browse(&state, .selectAllKnown)
            #expect(state.browse.selected.allSatisfy { $0.type != .image })
            let publicProjection = TrashQueryFixture.strings(state)
            #expect(!publicProjection.contains("SYNTHETIC_HIDDEN_FILENAME"))
            #expect(String(describing: state) == "ContentQueryPaginationState(redacted)")
            #expect(String(reflecting: state.status) == "ContentQueryPaginationStatus(redacted)")
        }
        #expect(counts.allSatisfy { $0 == counts[0] })
        #expect(completeness.allSatisfy { $0 == completeness[0] })
    }

    @Test func hiddenDiaryHasNoBodyEntryAcrossPagesAndNoHiddenTextInDiagnostics() throws {
        var batch = QueryBatchFixture.mixed("")
        var diary = batch.snapshots.diaries.values![0]
        diary.isPrivate = true
        diary.text = "SYNTHETIC_PRIVATE_BODY"
        batch.snapshots.diaries = .complete([diary])
        let source = QueryDisplayFixture.display(batch)
        var state = try ContentQueryPaginationState(snapshot: source, policy: .init(units: 1))
        while state.status.hasMoreUnits { _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits)) }
        let id = try #require(source.known.first { $0.type == .diary })
        #expect(QueryPaginationFixture.browse(&state, .expand(.bodyToggle(id, .diaryBody))).rejection == .invalidTarget)
        let publicProjection = TrashQueryFixture.strings(state)
        #expect(!publicProjection.contains("SYNTHETIC_PRIVATE_BODY"))
    }

    @Test func batchSortPresenterDisplayPaginationBrowsePreserveEvidenceAndSource() throws {
        var batch = QueryPaginationFixture.flat(45, query: "synthetic")
        batch.snapshots.todos = .partial(batch.snapshots.todos.values!)
        let response = ContentQueryBatchReader.read(batch)
        let sorted = ContentQuerySorter.sort(response, mode: .relevance)
        let presented = ContentQueryPresenter.project(sorted, budget: QueryPresentationFixture.budget,
            locale: QueryPresentationFixture.locale)
        let display = ContentQueryDisplayBuilder.build(presented)
        var state = try ContentQueryPaginationState(snapshot: display)
        _ = QueryPaginationFixture.browse(&state, .selectVisible)
        let selected = state.browse.selected
        while state.status.hasMoreUnits {
            _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
            #expect(state.snapshot.sharesSource(with: display))
            #expect(state.snapshot.source.rows == presented.rows)
            #expect(state.snapshot.source.source.ordered == sorted.ordered)
            #expect(state.snapshot.source.source.source.matches == response.matches)
        }
        #expect(state.browse.selected == selected && selected.count == 20)
        #expect(state.snapshot.visible == sorted.ordered.map(\.id))
        #expect(state.status.completeness == response.completeness && !state.status.completeness.matchingIsComplete)
        #expect(!state.status.hasMoreToLoad && !state.status.hasProviderUnprocessedWork)
        #expect(!state.status.canDeclareCompleteNoMatch)
    }
}
