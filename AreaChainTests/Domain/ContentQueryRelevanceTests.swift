import Foundation
import Testing
@testable import AreaChain

struct ContentQueryRelevanceTests {
    @Test func singleWordAndPhraseUseExactNameConservatively() {
        for query in ["alpha", "\"alpha beta\""] {
            let name = query == "alpha" ? "alpha" : "alpha beta"
            let result = QuerySortFixture.sort(QuerySortFixture.batch(query, titles: [(name, ""), (name + " tail", "")]))
            #expect(result.ordered.map(\.tier) == [.exactName, .allName])
        }
    }

    @Test func allNameMixedAndBodyTiers() {
        let result = QuerySortFixture.sort(QuerySortFixture.batch("alpha beta", titles: [
            ("none", "alpha beta"), ("alpha", "beta"), ("beta alpha", "")
        ]))
        #expect(result.ordered.map(\.tier) == [.allName, .mixedFields, .otherFields])
        #expect(result.ordered.map(\.id.id) == [3, 2, 1].map { TodoQueryFixture.todo($0).id })
    }

    @Test func orUsesActualAlternativeAndDoesNotInventExactString() {
        let result = QuerySortFixture.sort(QuerySortFixture.batch("(alpha | beta) gamma", titles: [
            ("alpha gamma", ""), ("beta", "gamma"), ("none", "beta gamma")
        ]))
        #expect(result.ordered.map(\.tier) == [.allName, .mixedFields, .otherFields])
        let single = QuerySortFixture.sort(QuerySortFixture.batch("(alpha | beta)", titles: [("alpha", "")]))
        #expect(single.ordered.first?.tier == .allName)
    }

    @Test func excludedOrBranchDoesNotRequireItsPositiveAlternative() {
        let result = QuerySortFixture.sort(QuerySortFixture.batch("(alpha | -beta) gamma", titles: [("gamma", "")]))
        #expect(result.ordered.count == 1)
        #expect(result.ordered.first?.tier == .allName)
        let absentOnly = QuerySortFixture.sort(QuerySortFixture.batch("(alpha | -beta)", titles: [("gamma", "")]))
        #expect(absentOnly.ordered.first?.reason == .noPublicTextEvidence)
    }

    @Test func unicodeWholeRangeDoesNotInventWholeNameEquality() {
        let context = QuerySortFixture.context("e")
        let evidence = ContentQueryMatchEvidence(conditionID: context.clauses[0].id, alternativeIndex: 0,
                                                field: .title, range: NSRange(location: 0, length: 2))
        let rank = ContentQueryRelevance.rank(QuerySortFixture.todo(1, title: "ex", evidence: [evidence]), context: context)
        #expect(rank.tier == .allName)
        let actual = QuerySortFixture.sort(QuerySortFixture.batch("cafe", titles: [("CAFÉ", "")]))
        #expect(actual.ordered.first?.tier == .exactName)
    }

    @Test func duplicatesAndExclusionsDoNotAddWeight() {
        let plain = QuerySortFixture.sort(QuerySortFixture.batch("alpha", titles: [("alpha", "")]))
        let repeated = QuerySortFixture.sort(QuerySortFixture.batch("alpha alpha -absent", titles: [("alpha", "")]))
        #expect(repeated.ordered == plain.ordered)
        let structured = QuerySortFixture.sort(QuerySortFixture.batch("-absent", titles: [("alpha", "")]))
        #expect(structured.applied == .recent)
        #expect(structured.fallback == .noPositiveText)
    }

    @Test func crossTypeNamesBeatBodyWithoutTypeWeight() {
        let result = QuerySortFixture.sort(QueryBatchFixture.mixed())
        #expect(result.ordered.count == 6)
        #expect(result.ordered.last?.id.type == .diary)
        #expect(result.ordered.last?.tier == .otherFields)
        #expect(result.ordered.filter { [.todo, .subtask, .routine].contains($0.id.type) }.allSatisfy { $0.tier == .exactName })
        #expect(result.ordered.first { $0.id.type == .image }?.tier == .allName)
        var tags = QueryBatchFixture.mixed("/tags batch-common")
        tags.snapshots.tags = .complete([.init(id: QueryBatchFixture.id, name: QueryBatchFixture.common)])
        #expect(QuerySortFixture.sort(tags).ordered.first?.tier == .exactName)
    }

    @Test func parentAndOwnerFieldsCannotBecomeOwnNames() {
        var batch = QueryBatchFixture.mixed()
        var child = batch.snapshots.subtasks.values![0]
        child.title = "unrelated"
        batch.snapshots.subtasks = .complete([child])
        var image = batch.snapshots.images.values![0]
        image.filename = "unrelated.png"
        batch.snapshots.images = .complete([image])
        let result = QuerySortFixture.sort(batch)
        #expect(!result.ordered.contains { [.subtask, .image].contains($0.id.type) })
        let occurrences = QuerySortFixture.sort(QueryBatchFixture.occurrences())
        #expect(occurrences.applied == .recent)
        #expect(occurrences.ordered.allSatisfy { $0.tier == nil })
    }

    @Test func bodyFirstLineAndPinningDoNotPromote() {
        var batch = QueryBatchFixture.mixed()
        var diary = batch.snapshots.diaries.values![0]
        diary.text += "\nbody"; diary.isPinned = true
        batch.snapshots.diaries = .complete([diary])
        let result = QuerySortFixture.sort(batch)
        #expect(result.ordered.last?.id.type == .diary)
        #expect(result.ordered.last?.tier == .otherFields)
        let clipboard = QuerySortFixture.sort(QueryBatchFixture.mixed("/clipboard batch-common"))
        #expect(clipboard.ordered.first?.tier == .otherFields)
    }

    @Test func differentAndConditionsNeedTheirOwnEvidence() {
        let context = QuerySortFixture.context("alpha beta")
        let first = context.clauses[0].id
        let match = QuerySortFixture.todo(1, evidence: [.init(conditionID: first, alternativeIndex: 0,
                                                            field: .title, range: NSRange(location: 0, length: 5))])
        let rank = ContentQueryRelevance.rank(match, context: context)
        #expect(rank.tier == .otherFields)
        #expect(rank.reason == .noPublicTextEvidence)
    }

    @Test func invalidReferencesBranchesRangesAndOwnerEvidenceCannotPromote() {
        let context = QuerySortFixture.context("alpha")
        let good = ContentQueryMatchEvidence(conditionID: context.clauses[0].id, alternativeIndex: 0,
                                            field: .title, range: NSRange(location: 0, length: 5))
        var branch = good; branch.alternativeIndex = 2
        var range = good; range.range = NSRange(location: Int.max, length: 9)
        var owner = good; owner.ownerObject = .init(type: .todo, id: UUID())
        let foreign = ContentQueryMatchEvidence(conditionID: .init(rawValue: -99), alternativeIndex: 0,
                                               field: .title, range: good.range)
        var field = good; field = .init(conditionID: good.conditionID, alternativeIndex: 0, field: .filename, range: good.range)
        for item in [branch, range, owner, foreign, field] {
            let rank = ContentQueryRelevance.rank(QuerySortFixture.todo(1, evidence: [item]), context: context)
            #expect(rank.tier == .otherFields)
            #expect(rank.reason == .invalidEvidence)
        }
    }
}
