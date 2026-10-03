import Foundation
import Testing
@testable import AreaChain

struct ContentQueryPresentationBoundaryTests {
    @Test func publishedDiaryTagAssociationRejectsAnotherUUID() throws {
        var batch = QueryBatchFixture.mixed("#work")
        var diary = batch.snapshots.diaries.values![0]
        diary.tagIDs = QueryBatchFixture.id.uuidString
        batch.snapshots.diaries = .complete([diary])
        batch.facts.metadata = .init(tagNames: [QueryBatchFixture.id: "work"], privateTagIDs: [])
        let response = ContentQueryBatchReader.read(batch)
        let match = try #require(response.matches.first { $0.id.type == .diary })
        var evidence = try #require(QueryBatchFixture.evidence(match).first { $0.field == .tags })
        let condition = try #require(response.sortContext.presentationConditions[evidence.conditionID]?.value)
        #expect(ContentQueryPresentationEvidenceRules.issue(evidence, condition: condition, match: match) == nil)
        evidence.relatedObject = .init(type: .tag, id: UUID())
        #expect(ContentQueryPresentationEvidenceRules.issue(evidence, condition: condition, match: match) == .invalidRelation)
    }

    @Test func surrogateInteriorIsRejectedButExpandedGraphemeIsAccepted() {
        let valid = QueryPresentationFixture.todo("👩", title: "👩🏽‍💻")
        #expect(QueryPresentationFixture.highlighted(valid.primary) == ["👩🏽‍💻"])
        let invalid = QueryPresentationFixture.corruptTodo(query: "👩", title: "👩🏽‍💻") { items in
            items.map { var value = $0; value.range = .init(location: 0, length: 1); return value }
        }
        #expect(invalid.rows[0].primary?.highlights.isEmpty == true)
        #expect(invalid.rows[0].diagnostics.contains(.init(issue: .invalidRange)))
    }

    @Test func metadataConditionCannotClaimAFieldOfAnotherType() {
        var batch = QueryBatchFixture.mixed("date:today")
        batch.snapshots.routines = .complete([])
        let sorted = QuerySortFixture.sort(batch)
        guard case .todo(var read) = sorted.source.readings[0], let value = read.matches.first else {
            Issue.record("合成夹具缺失"); return
        }
        read.matches = [.init(id: value.id, title: value.title, notes: value.notes, dayKey: value.dayKey,
            createdAt: value.createdAt, isDone: value.isDone, evidence: value.evidence.map {
                .init(conditionID: $0.conditionID, alternativeIndex: $0.alternativeIndex, field: .diaryDay)
            })]
        let result = ContentQueryPresenter.project(QueryPresentationFixture.replacing(sorted, readings: [.todo(read)]),
            budget: .init(), locale: QueryPresentationFixture.locale)
        #expect(result.rows.first { $0.id == value.id }?.diagnostics.contains(.init(issue: .invalidField)) == true)
    }

    @Test func invalidRangesDoNotCrashOrChangeMatchMembership() {
        for range in [NSRange(location: NSNotFound, length: 1), .init(location: -1, length: 1),
                      .init(location: 1, length: Int.max), .init(location: 99, length: 1)] {
            let result = QueryPresentationFixture.corruptTodo { items in
                items.map { var value = $0; value.range = range; return value }
            }
            #expect(result.rows.count == 1 && result.source.source.definiteMatchCount == 1)
            #expect(result.rows[0].primary?.highlights.isEmpty == true)
            #expect(result.rows[0].diagnostics.contains(.init(issue: .invalidRange)))
        }
    }

    @Test func wrongConditionsBranchesFieldsAndOwnersAreRejected() {
        let modifications: [(ContentQueryMatchEvidence) -> ContentQueryMatchEvidence] = [
            { .init(conditionID: .init(rawValue: 9_999), alternativeIndex: 0, field: .title, range: $0.range) },
            { var item = $0; item.alternativeIndex = 99; return item },
            { .init(conditionID: $0.conditionID, alternativeIndex: $0.alternativeIndex, field: .filename, range: $0.range) },
            { var item = $0; item.ownerObject = .init(type: .todo, id: QueryBatchFixture.id); return item }
        ]
        for change in modifications {
            let row = QueryPresentationFixture.corruptTodo { $0.map(change) }.rows[0]
            #expect(row.primary?.highlights.isEmpty == true && row.summary == nil)
            #expect(!row.diagnostics.isEmpty)
        }
    }

    @Test func staleRangeWithinBoundsDoesNotHighlightArbitraryCharacters() {
        let row = QueryPresentationFixture.corruptTodo { items in
            items.map { var value = $0; value.range = .init(location: 1, length: 2); return value }
        }.rows[0]
        #expect(row.diagnostics.contains(.init(issue: .staleEvidence)))
        #expect(row.primary?.highlights.isEmpty == true && row.summary == nil)
    }

    @Test func noLegalExplicitRangesAndRegexZeroWidthRetainSafePrefix() {
        let batch = QueryPresentationFixture.clipboard("^", text: "公开 plainText", mode: .regex)
        let result = QueryPresentationFixture.project(batch)
        #expect(result.rows.count == 1)
        #expect(result.rows[0].summary?.text == "公开 plainText")
        #expect(result.rows[0].summary?.highlights.isEmpty == true)
        #expect(result.rows[0].diagnostics.contains(.init(issue: .noLegalModeRange)))
        #expect(result.rows[0].diagnostics.contains(.init(issue: .zeroLengthModeMatch)))
    }

    @Test func invalidExplicitModeEvidenceUsesNoRegexOrReplacementSearch() throws {
        let sorted = QuerySortFixture.sort(QueryPresentationFixture.clipboard("alpha", text: "alpha body", mode: .exact))
        guard case .clipboard(var read) = sorted.source.readings[0] else { Issue.record("夹具缺少剪贴板"); return }
        let item = try #require(read.matches.first)
        read.matches = [.init(id: item.id, plainText: item.plainText, copiedAt: item.copiedAt, pinnedAt: item.pinnedAt,
            pinKey: item.pinKey, sourceBundleID: item.sourceBundleID, payload: item.payload, mode: item.mode,
            evidence: item.evidence, modeEvidence: .init(mode: .exact, ranges: [.init(location: 999, length: 10)]))]
        let result = ContentQueryPresenter.project(QueryPresentationFixture.replacing(sorted, readings: [.clipboard(read)]),
            budget: QueryPresentationFixture.budget, locale: QueryPresentationFixture.locale)
        #expect(result.rows[0].summary?.text == "alpha body")
        #expect(result.rows[0].summary?.highlights.isEmpty == true)
        #expect(result.rows[0].diagnostics.contains(.init(issue: .noLegalModeRange)))
    }

    @Test func exactTypedIdentityNeverFallsBackToSameUUID() {
        let sorted = QuerySortFixture.sort(QueryBatchFixture.mixed())
        let wrong = ContentQueryRankedMatch(id: .init(type: .routineOccurrence, id: QueryBatchFixture.id, dayKey: "2026-01-01"),
            tier: nil, reason: .recentOnly, time: sorted.ordered[0].time)
        let result = ContentQueryPresenter.project(QueryPresentationFixture.replacing(sorted, ordered: [wrong]),
            budget: QueryPresentationFixture.budget, locale: QueryPresentationFixture.locale)
        #expect(result.rows.map(\.id) == [wrong.id])
        #expect(result.rows[0].primary == nil && result.rows[0].summary == nil)
        #expect(result.rows[0].diagnostics == [.init(issue: .missingIdentity)])
        #expect(result.diagnostics == [.init(issue: .unorderedSourceIdentity)])
    }

    @Test func duplicateSourceOrOrderIdentityNeverChoosesAnArbitraryRow() throws {
        let sorted = QuerySortFixture.sort(QuerySortFixture.batch("alpha", titles: [("alpha", "")]))
        guard case .todo(var read) = sorted.source.readings[0] else { Issue.record("夹具缺少任务"); return }
        read.matches.append(try #require(read.matches.first))
        let ambiguous = ContentQueryPresenter.project(QueryPresentationFixture.replacing(sorted, readings: [.todo(read)]),
            budget: QueryPresentationFixture.budget, locale: QueryPresentationFixture.locale)
        #expect(ambiguous.rows[0].diagnostics == [.init(issue: .ambiguousIdentity)])
        let duplicated = ContentQueryPresenter.project(QueryPresentationFixture.replacing(sorted, ordered: sorted.ordered + sorted.ordered),
            budget: QueryPresentationFixture.budget, locale: QueryPresentationFixture.locale)
        #expect(duplicated.rows.count == 2)
        #expect(duplicated.rows.allSatisfy { $0.diagnostics == [.init(issue: .duplicateOrderIdentity)] })
    }

    @Test func budgetValidationAndEvidenceLimitsAreExplicit() {
        let sorted = QuerySortFixture.sort(QueryBatchFixture.mixed())
        for budget in [ContentQueryPresentationBudget(maxUTF16: 0), .init(maxCandidates: -1), .init(maxEvidence: Int.max)] {
            let result = ContentQueryPresenter.project(sorted, budget: budget, locale: QueryPresentationFixture.locale)
            #expect(result.rows.map(\.id) == sorted.ordered.map(\.id))
            #expect(result.rows.allSatisfy { $0.diagnostics == [.init(issue: .invalidBudget)] })
        }
        let limited = QueryPresentationFixture.project(QuerySortFixture.batch("alpha beta", titles: [("alpha beta", "")]),
            budget: .init(maxEvidence: 1))
        #expect(limited.rows[0].diagnostics.contains(.init(issue: .evidenceLimit)))
        #expect(limited.source.source.definiteMatchCount == 1)
    }
}
