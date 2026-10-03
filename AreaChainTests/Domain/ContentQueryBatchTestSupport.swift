import Foundation
@testable import AreaChain

enum QueryBatchFixture {
    static let common = "batch-common"
    static let id = TodoQueryFixture.work

    static func empty(_ source: String = "") -> ContentQueryBatch {
        var batch = ContentQueryBatch(requestID: TodoQueryFixture.requestID, session: TodoQueryFixture.session(source))
        batch.snapshots = .init(todos: .complete([]), subtasks: .complete([]), routines: .complete([]),
            diaries: .complete([]), images: .complete([]), tags: .complete([]), clipboard: .complete([]))
        batch.facts.metadata = .init(tagNames: [:], privateTagIDs: [])
        batch.facts.imageCoverage = ImageAssociationFixture.coverage
        batch.facts.trashCoverage = TrashFixture.input().coverage
        batch.facts.trashTagNamesCoverage = .completeIncludingDeleted
        return batch
    }

    static func mixed(_ source: String = common) -> ContentQueryBatch {
        var batch = empty(source)
        let stamp = TodoQueryFixture.created
        batch.snapshots.todos = .complete([.init(id: id, title: common, isDone: false,
            dayKey: QuerySessionFixture.today, createdAt: stamp)])
        batch.snapshots.subtasks = .complete([.init(id: id, todoId: id, title: common, isDone: false, createdAt: stamp)])
        batch.snapshots.routines = .complete([.init(id: id, title: common, sortOrder: 0,
            isEnabled: true, createdDayKey: "2026-09-01", createdAt: stamp)])
        batch.snapshots.diaries = .complete([.init(id: id, text: common, dayKey: QuerySessionFixture.today, createdAt: stamp)])
        batch.snapshots.tags = .complete([.init(id: id, name: common)])
        var image = ImageAssociationFixture.image(owner: .init(kind: .todo, id: id), id: id)
        image.filename = common + ".png"
        batch.snapshots.images = .complete([image])
        batch.snapshots.clipboard = .complete([ClipboardQueryFixture.record(1, common)])
        batch.facts.routine = .init(checks: [], checkCoverage: [.init(routineID: id,
            completeIntervals: [.init(lowerBound: "2026-09-01", upperBound: "2026-12-31")])],
            scheduleEvidence: [RoutineQueryFixture.evidence("2026-09-01", "2026-12-31", id: id)])
        return batch
    }

    static func replacingSession(_ batch: ContentQueryBatch, _ session: ContentQuerySession) -> ContentQueryBatch {
        .init(requestID: batch.requestID, session: session, snapshots: batch.snapshots, facts: batch.facts, options: batch.options)
    }

    static func occurrences(_ source: String = "date:today") -> ContentQueryBatch {
        let batch = mixed(source)
        return replacingSession(batch, TodoQueryFixture.add(.scope(.routineOccurrences), to: batch.session))
    }

    static func trash(_ source: String = "/trash") -> ContentQueryBatch {
        var batch = empty(source)
        batch.snapshots.todos = .complete([TrashFixture.todo()])
        batch.snapshots.subtasks = .complete([TrashFixture.child()])
        batch.snapshots.images = .complete([TrashFixture.image()])
        return batch
    }

    static func evidence(_ result: ContentQueryBatchMatch) -> [ContentQueryMatchEvidence] {
        switch result {
        case .todo(let value): value.evidence
        case .subtask(let value): value.evidence
        case .routine(let value): value.evidence
        case .diary(let value): value.metadataEvidence + {
            if case .publicText(_, let evidence) = value.presentation { return evidence }; return []
        }()
        case .image(let value): value.evidence
        case .tag(let value): value.evidence
        case .clipboard(let value): value.evidence
        case .trash(let value): value.evidence
        case .routineOccurrence(let value): value.evidence
        }
    }
}
