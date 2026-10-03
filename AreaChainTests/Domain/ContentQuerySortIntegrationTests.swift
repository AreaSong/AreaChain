import Foundation
import Testing
@testable import AreaChain

struct ContentQuerySortIntegrationTests {
    @Test func parserSessionBatchAndSortingPreserveIdentityAndEvidence() {
        let batch = QueryBatchFixture.mixed("(batch-common | absent) -excluded")
        let response = ContentQueryBatchReader.read(batch)
        let result = ContentQuerySorter.sort(response, mode: .relevance)
        #expect(Set(result.ordered.map(\.id)) == Set(response.matches.map(\.id)))
        #expect(result.ordered.count == response.definiteMatchCount)
        #expect(result.source.matches == response.matches)
        #expect(result.source.textDiagnostics == response.textDiagnostics)
        #expect(result.source.conditionDiagnostics == response.conditionDiagnostics)
        #expect(result.source.consistencyIssues == response.consistencyIssues)
        #expect(result.source.sortContext.clauses.map(\.id) == batch.session.conditions.filter {
            $0.value.dimension == .content(.text)
        }.map(\.id))
    }

    @Test func sameRequestIDCannotReplaceFrozenQuery() {
        let first = ContentQueryBatchReader.read(QuerySortFixture.batch("alpha", titles: [("alpha", "")]))
        let second = ContentQueryBatchReader.read(QuerySortFixture.batch("beta", titles: [("beta tail", "")]))
        #expect(first.requestID == second.requestID)
        #expect(ContentQuerySorter.sort(first, mode: .relevance).ordered.first?.tier == .exactName)
        #expect(ContentQuerySorter.sort(second, mode: .relevance).ordered.first?.tier == .allName)
        #expect(ContentQuerySorter.sort(first, mode: .relevance).ordered.first?.tier == .exactName)
    }

    @Test func hiddenBodyChangesCannotChangeOrderingOrExplanations() {
        var batch = QueryBatchFixture.mixed("batch-common")
        var diary = batch.snapshots.diaries.values![0]
        diary.isPrivate = true
        var observations: [[ContentQueryRankedMatch]] = []
        for text in ["batch-common", "batch-common batch-common\nextra synthetic hidden material"] {
            diary.text = text
            batch.snapshots.diaries = .complete([diary])
            let result = QuerySortFixture.sort(batch)
            let hidden = result.ordered.first { $0.id.type == .diary }
            #expect(hidden?.tier == .otherFields && hidden?.reason == .protectedText)
            if text != "batch-common" { #expect(!TrashQueryFixture.strings(result).contains(text)) }
            observations.append(result.ordered)
        }
        #expect(observations[0] == observations[1])
    }

    @Test func explicitClipboardModesUseOnlyPublishedModeEvidence() {
        for mode in [ClipboardSearchMode.mixed, .exact, .regex] {
            var batch = QueryBatchFixture.empty("/clipboard")
            batch.snapshots.clipboard = .complete([ClipboardQueryFixture.record(1, "alpha\nbody")])
            batch.options.clipboardMode = .explicit(mode, needle: "alpha")
            let result = QuerySortFixture.sort(batch)
            #expect(result.ordered.count == 1)
            if mode == .regex {
                #expect(result.applied == .recent && result.fallback == .explicitModeWithoutComparableText)
            } else {
                #expect(result.applied == .relevance && result.fallback == nil)
                #expect(result.ordered.first?.tier == .otherFields)
                #expect(result.ordered.first?.reason == .explicitModeEvidence)
            }
            batch.options.clipboardMode = .explicit(mode, needle: " ")
            #expect(QuerySortFixture.sort(batch).fallback == .explicitModeWithoutComparableText)
        }
    }

    @Test func trashGroupsContextAndRestoreConditionsRemainUntouched() throws {
        let response = ContentQueryBatchReader.read(QueryBatchFixture.trash("/trash 合成子任务"))
        let sorted = ContentQuerySorter.sort(response, mode: .relevance)
        guard case .trash(let before) = response.readings[0], case .trash(let after) = sorted.source.readings[0] else {
            Issue.record("缺少原墓碑投影"); return
        }
        #expect(before.groups == after.groups)
        #expect(before.matches == after.matches)
        #expect(sorted.ordered.map(\.id) == before.matches.map(\.id))
        #expect(sorted.ordered.first?.tier == .exactName)
        #expect(before.visibleContextCount == 2 && sorted.ordered.count == 1)
    }

    @Test func partialSourcesAndProtectionLimitsStayPartial() {
        var batch = QueryBatchFixture.mixed()
        batch.snapshots.todos = .partial(batch.snapshots.todos.values!)
        let result = QuerySortFixture.sort(batch)
        #expect(result.onlyKnownSubset)
        #expect(!result.source.canDeclareCompleteNoMatch)
        #expect(result.source.completeness.providers.contains { $0.limitations.contains(.source(.todo, .partial)) })
        #expect(result.ordered.count == result.source.definiteMatchCount)
        #expect(!QuerySortFixture.sort(QueryBatchFixture.empty()).onlyKnownSubset)
    }

    @Test func shuffledBatchInputHasStableOrder() {
        var batch = QuerySortFixture.batch("alpha", titles: Array(repeating: ("alpha", ""), count: 12))
        let expected = QuerySortFixture.sort(batch).ordered
        for _ in 0..<10 {
            batch.snapshots.todos = .complete(batch.snapshots.todos.values!.shuffled())
            #expect(QuerySortFixture.sort(batch).ordered == expected)
        }
    }

    @Test func structuredTagsAndDatesAreNotPositiveText() {
        var batch = QueryBatchFixture.mixed("#工作")
        var todo = batch.snapshots.todos.values![0]
        todo.tagIDs = TodoQueryFixture.work.uuidString
        batch.snapshots.todos = .complete([todo])
        batch.facts.metadata = .init(tagNames: TodoQueryFixture.names, privateTagIDs: [])
        let result = QuerySortFixture.sort(batch)
        #expect(result.ordered.contains { $0.id.type == .todo })
        #expect(result.applied == .recent && result.fallback == .noPositiveText)
        #expect(QuerySortFixture.sort(QueryBatchFixture.occurrences()).fallback == .noPositiveText)
    }

    @Test func clipboardPinTimeCannotReplaceCaptureTime() {
        var batch = QueryBatchFixture.empty("/clipboard alpha")
        var older = ClipboardQueryFixture.record(1, "alpha")
        let newer = ClipboardQueryFixture.record(2, "alpha")
        older.copiedAt -= 100
        older.pinnedAt = newer.copiedAt + 100_000
        batch.snapshots.clipboard = .complete([older, newer])
        let result = QuerySortFixture.sort(batch)
        #expect(result.ordered.map(\.id.id) == [newer.id, older.id])
        #expect(result.ordered.map(\.time.instant) == [newer.copiedAt, older.copiedAt])
    }

    @Test func descriptionsAndRankStorageDoNotExpandBodyQueryOrFilename() {
        let result = QuerySortFixture.sort(QueryBatchFixture.mixed())
        let descriptions = [String(describing: result), String(reflecting: result),
            String(reflecting: result.source.sortContext)]
            + result.source.sortContext.clauses.map { String(reflecting: $0) }
            + result.ordered.map { String(reflecting: $0) }
        #expect(descriptions.allSatisfy { !$0.contains(QueryBatchFixture.common) })
        #expect(!TrashQueryFixture.strings(result.ordered).contains(QueryBatchFixture.common))
    }
}
