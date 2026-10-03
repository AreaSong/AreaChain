import Foundation
@testable import AreaChain

enum QueryPaginationFixture {
    static func flat(_ count: Int, query: String = "") -> ContentQueryBatch {
        QuerySortFixture.batch(query, titles: (0..<count).map { ("synthetic item \($0)", "") })
    }

    static func grouped(groups: Int = 2, hits: Int = 45, contexts: Int = 24,
                        independent: Int = 0) -> ContentQueryBatch {
        var batch = QueryBatchFixture.empty("/trash needle")
        var parents: [TodoSnapshot] = []
        var children: [SubtaskSnapshot] = []
        for index in 0..<groups {
            let parent = UUID()
            parents.append(TrashFixture.todo(parent))
            for member in 0..<(hits + contexts) {
                var child = TrashFixture.child(UUID(), parent: parent)
                child.title = member < hits ? "needle \(index) \(member)" : "synthetic context \(member)"
                children.append(child)
            }
        }
        for index in 0..<independent {
            var child = TrashFixture.child(UUID(), parent: parents[0].id, deleted: TrashFixture.date.addingTimeInterval(1))
            child.title = "needle independent \(index)"
            children.append(child)
        }
        batch.snapshots.todos = .complete(parents)
        batch.snapshots.subtasks = .complete(children)
        return batch
    }

    static func event(_ state: ContentQueryPaginationState, _ action: ContentQueryPaginationAction) -> ContentQueryPaginationEvent {
        .init(stamp: state.stamp, action: action)
    }

    @discardableResult
    static func browse(_ state: inout ContentQueryPaginationState, _ action: ContentQueryBrowseAction) -> ContentQueryBrowseEffect {
        state.applyBrowse(.init(version: state.snapshot.version, action: action))
    }

    static func sorted(_ batch: ContentQueryBatch, mode: ContentQuerySortMode) -> ContentQueryDisplaySnapshot {
        ContentQueryDisplayBuilder.build(ContentQueryPresenter.project(QuerySortFixture.sort(batch, mode: mode),
            budget: QueryPresentationFixture.budget, locale: QueryPresentationFixture.locale))
    }
}
