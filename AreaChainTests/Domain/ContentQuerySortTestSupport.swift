import Foundation
@testable import AreaChain

enum QuerySortFixture {
    static func batch(_ query: String, titles: [(String, String)]) -> ContentQueryBatch {
        var batch = QueryBatchFixture.empty(query)
        batch.snapshots.todos = .complete(titles.enumerated().map { index, text in
            var value = TodoQueryFixture.todo(index + 1, title: text.0)
            value.notes = text.1
            return value
        })
        return batch
    }

    static func sort(_ batch: ContentQueryBatch, mode: ContentQuerySortMode = .relevance) -> ContentQuerySortedResponse {
        ContentQuerySorter.sort(ContentQueryBatchReader.read(batch), mode: mode)
    }

    static func context(_ source: String) -> ContentQuerySortContext { .init(batch: QueryBatchFixture.empty(source)) }

    static func todo(_ number: Int, title: String = "alpha", stamp: Date = TodoQueryFixture.created,
                     evidence: [ContentQueryMatchEvidence] = []) -> ContentQueryBatchMatch {
        .todo(.init(id: .init(type: .todo, id: TodoQueryFixture.todo(number).id), title: title, notes: "beta",
                    dayKey: "2026-01-01", createdAt: stamp, isDone: false, evidence: evidence))
    }

    static func time(_ match: ContentQueryBatchMatch, dates: ContentQueryDateContext? = nil) -> ContentQuerySortTime {
        .init(match: match, dates: dates ?? TodoQueryFixture.session().queryDates)
    }

    static func row(_ number: Int, time: ContentQuerySortTime, type: CommandObjectType = .todo,
                    day: String? = nil) -> ContentQueryRankedMatch {
        .init(id: .init(type: type, id: TodoQueryFixture.todo(number).id, dayKey: day),
              tier: nil, reason: .recentOnly, time: time)
    }
}
